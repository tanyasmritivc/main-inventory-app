"""Transactional email delivery with server-side SMTP credentials and audit records."""

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from email.utils import make_msgid, parseaddr
from html import escape
import re
import weakref

from fastapi import HTTPException

from app.services.email_delivery import (
    send_transactional_email as deliver_transactional_email,
)
from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_delivery_locks: weakref.WeakValueDictionary[str, asyncio.Lock] = (
    weakref.WeakValueDictionary()
)


def _row(response) -> dict | None:
    """postgrest-py 0.19 returns None, not an empty response, when maybe_single finds no row."""
    data = getattr(response, "data", None)
    return data if isinstance(data, dict) else None


def normalize_email(value: str) -> str:
    address = parseaddr(value.strip())[1].lower()
    if not _EMAIL_RE.fullmatch(address) or len(address) > 254:
        raise HTTPException(status_code=400, detail="Invalid recipient email")
    return address


def render_team_invitation(*, share_name: str, share_code: str) -> tuple[str, str, str]:
    safe_name = escape(share_name)
    safe_code = escape(share_code)
    join_link = f"https://www.findez.ai/join?code={safe_code}"
    subject = f"You've been invited to view '{share_name}' on FindEZ"
    text = (
        f"You've been invited to view '{share_name}' on FindEZ.\n\n"
        f"Join code: {share_code}\nOpen: {join_link}"
    )
    html = f"""
    <div style="font-family:sans-serif;background:#000;color:#fff;padding:40px;max-width:500px;margin:auto;border-radius:16px">
      <h2 style="font-size:22px;margin-bottom:8px">You're invited to FindEZ</h2>
      <p style="color:rgba(255,255,255,.6);font-size:15px">Someone shared <strong style="color:#fff">'{safe_name}'</strong> with you.</p>
      <div style="margin:32px 0;background:rgba(255,255,255,.06);border-radius:12px;padding:20px;text-align:center">
        <p style="color:rgba(255,255,255,.5);font-size:12px;letter-spacing:2px">JOIN CODE</p>
        <p style="font-size:32px;font-weight:700;letter-spacing:8px;margin:0">{safe_code}</p>
      </div>
      <a href="{join_link}" style="display:block;background:#fff;color:#000;text-align:center;padding:14px;border-radius:99px;font-weight:600;text-decoration:none">Open FindEZ &amp; Join</a>
    </div>"""
    return subject, text, html


def render_custom_message(*, subject: str, body: str) -> tuple[str, str, str]:
    subject = subject.strip()
    body = body.strip()
    if not subject or "\r" in subject or "\n" in subject:
        raise HTTPException(status_code=400, detail="Subject must be a single non-empty line")
    if not body:
        raise HTTPException(status_code=400, detail="Body is required")
    safe_body = escape(body).replace("\n", "<br>\n")
    html = f'<div style="font-family:sans-serif;white-space:normal">{safe_body}</div>'
    return subject, body, html


async def _send_transactional_email_locked(
    *,
    user_id: str,
    idempotency_key: str,
    template: str,
    recipient: str,
    subject: str,
    text: str,
    html: str,
) -> dict:
    client = get_supabase_admin()
    recipient = normalize_email(recipient)
    existing = _row(
        client.table("email_deliveries")
        .select("status,message_id")
        .eq("user_id", user_id)
        .eq("idempotency_key", idempotency_key)
        .maybe_single()
        .execute()
    )
    retrying = bool(existing and existing["status"] == "failed")
    if existing and not retrying:
        return {
            "status": existing["status"],
            "message_id": existing.get("message_id"),
            "duplicate": True,
        }

    since = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    recent = (
        client.table("email_deliveries")
        .select("id")
        .eq("user_id", user_id)
        .gte("created_at", since)
        .execute()
    )
    if len(recent.data or []) >= 30:
        raise HTTPException(status_code=429, detail="Email rate limit exceeded")

    message_id = (existing or {}).get("message_id") or make_msgid(domain="findez.ai")
    if retrying:
        (
            client.table("email_deliveries")
            .update(
                {
                    "status": "pending",
                    "error_code": None,
                    "message_id": message_id,
                }
            )
            .eq("user_id", user_id)
            .eq("idempotency_key", idempotency_key)
            .execute()
        )
    else:
        try:
            (
                client.table("email_deliveries")
                .insert(
                    {
                        "user_id": user_id,
                        "idempotency_key": idempotency_key,
                        "template": template,
                        "recipient": recipient,
                        "status": "pending",
                        "message_id": message_id,
                    }
                )
                .execute()
            )
        except Exception:
            raced = _row(
                client.table("email_deliveries")
                .select("status,message_id")
                .eq("user_id", user_id)
                .eq("idempotency_key", idempotency_key)
                .maybe_single()
                .execute()
            )
            if raced:
                return {
                    "status": raced["status"],
                    "message_id": raced.get("message_id"),
                    "duplicate": True,
                }
            raise

    try:
        await asyncio.to_thread(
            deliver_transactional_email,
            to=recipient,
            subject=subject,
            text=text,
            html=html,
            message_id=message_id,
        )
    except Exception as exc:
        try:
            (
                client.table("email_deliveries")
                .update({"status": "failed", "error_code": type(exc).__name__})
                .eq("user_id", user_id)
                .eq("idempotency_key", idempotency_key)
                .execute()
            )
        except Exception:
            logger.exception(
                "transactional_email_status_update_failed user_id=%s status=failed",
                user_id,
            )
        logger.exception(
            "transactional_email_failed user_id=%s template=%s",
            user_id,
            template,
        )
        raise HTTPException(
            status_code=503,
            detail="Email delivery temporarily unavailable",
        )

    # The message has left the server. A failed audit update must not turn that into
    # a retryable error; the row stays pending, so a retry is reported as a duplicate.
    try:
        (
            client.table("email_deliveries")
            .update(
                {
                    "status": "sent",
                    "sent_at": datetime.now(timezone.utc).isoformat(),
                }
            )
            .eq("user_id", user_id)
            .eq("idempotency_key", idempotency_key)
            .execute()
        )
    except Exception:
        logger.exception(
            "transactional_email_status_update_failed user_id=%s status=sent "
            "message_id=%s",
            user_id,
            message_id,
        )
    logger.info(
        "transactional_email_sent user_id=%s template=%s "
        "recipient_domain=%s message_id=%s",
        user_id,
        template,
        recipient.rsplit("@", 1)[1],
        message_id,
    )
    return {"status": "sent", "message_id": message_id, "duplicate": False}


async def send_transactional_email(**kwargs) -> dict:
    """Serialize a delivery key in-process; durable uniqueness handles restarts."""
    lock_key = f"{kwargs['user_id']}:{kwargs['idempotency_key']}"
    lock = _delivery_locks.get(lock_key)
    if lock is None:
        lock = asyncio.Lock()
        _delivery_locks[lock_key] = lock
    async with lock:
        return await _send_transactional_email_locked(**kwargs)

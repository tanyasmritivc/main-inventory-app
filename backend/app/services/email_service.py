"""Transactional email delivery with server-side SMTP credentials and audit records."""

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from email.utils import make_msgid, parseaddr
from html import escape
import re
from urllib.parse import quote
import weakref

from fastapi import HTTPException

from app.core.config import get_settings
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


def space_invitation_url(share_code: str) -> str:
    """Universal Link for a Space invitation.

    On iOS with FindEZ installed this opens the app (see the web app's
    apple-app-site-association). Otherwise the web page offers the App Store.
    """
    base_url = get_settings().frontend_url.rstrip("/")
    return f"{base_url}/join/{quote(share_code.strip().upper(), safe='')}"


def render_team_invitation(*, share_name: str, share_code: str) -> tuple[str, str, str]:
    safe_name = escape(share_name)
    safe_code = escape(share_code)
    join_link = space_invitation_url(share_code)
    safe_link = escape(join_link, quote=True)
    subject = f"You've been invited to view '{share_name}' on FindEZ"
    text = (
        f"You've been invited to view '{share_name}' on FindEZ.\n\n"
        f"Join code: {share_code}\nOpen: {join_link}\n\n"
        "On iPhone, the link opens FindEZ. If you don't have the app yet, it takes "
        "you to the App Store; after installing, open this link again to join."
    )
    html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>FindEZ invitation</title></head>
<body style="margin:0;padding:0;width:100%;background:#f4f3ef;color:#24211d;font-family:Arial,Helvetica,sans-serif;-webkit-text-size-adjust:100%;">
<table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" bgcolor="#f4f3ef"><tr><td align="center" style="padding:32px 16px;">
<!--[if mso]><table role="presentation" width="560" border="0" cellspacing="0" cellpadding="0"><tr><td><![endif]-->
<table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width:560px;"><tr><td style="padding:0 4px 24px;">
<table role="presentation" border="0" cellspacing="0" cellpadding="0"><tr><td width="40"><img src="https://findez.ai/favicon.png" width="32" height="32" alt="" style="display:block;border:0;border-radius:7px;"></td><td style="font-size:23px;font-weight:700;letter-spacing:-1px;color:#24211d;">FindEZ</td></tr></table>
</td></tr><tr><td bgcolor="#ffffff" style="background:#ffffff;border:1px solid #e4e0d9;border-top:3px solid #bc4800;border-radius:12px;padding:30px 24px 8px;">
<h1 style="margin:0 0 18px;color:#24211d;font-size:28px;font-weight:700;letter-spacing:-0.6px;line-height:1.25;overflow-wrap:break-word;">You're invited to FindEZ</h1>
<p style="margin:0 0 22px;color:#55534f;font-size:16px;line-height:1.65;overflow-wrap:break-word;">Someone shared <strong>'{safe_name}'</strong> with you.</p><table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="margin:0 0 26px;"><tr><td bgcolor="#f5f4f1" style="padding:18px 20px;border:1px solid #e8e5df;border-radius:8px;"><p style="margin:0 0 10px;color:#66615a;font-size:12px;line-height:1.5;">JOIN CODE</p><strong style="font-family:Consolas,Menlo,monospace;font-size:22px;line-height:1.4;letter-spacing:2px;color:#24211d;word-break:break-all;">{safe_code}</strong></td></tr></table><table role="presentation" border="0" cellspacing="0" cellpadding="0" style="margin:6px 0 28px;"><tr><td bgcolor="#bc4800" style="border-radius:8px;text-align:center;"><a href="{safe_link}" style="display:inline-block;padding:15px 24px;border:1px solid #bc4800;border-radius:8px;background:#bc4800;color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:700;line-height:1.4;text-decoration:none;text-align:center;mso-padding-alt:0;">Open FindEZ &amp; Join</a></td></tr></table><p style="margin:0 0 22px;color:#55534f;font-size:14px;line-height:1.65;overflow-wrap:break-word;">On iPhone, this opens FindEZ. Don't have the app yet? The link takes you to the App Store. After installing, open this email and tap the button again to join.</p>
</td></tr></table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr></table></body></html>
"""
    return subject, text, html


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

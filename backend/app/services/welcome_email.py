"""One welcome per new, confirmed account. Activation requires owner approval."""

import logging
import smtplib
import ssl
from datetime import datetime, timezone
from email.message import EmailMessage
from email.utils import make_msgid
from pathlib import Path

from app.core.config import get_settings
from app.services.supabase_client import get_supabase_raw

logger = logging.getLogger(__name__)

# Set to the actual rollout instant only after the owner approves the test email.
# None disables both scheduling and sending. Older accounts are never backfilled.
WELCOME_LAUNCH_AT: datetime | None = datetime.fromisoformat('2026-11-12T04:42:44.512434+00:00')
WELCOME_KEY = "findez-welcome-v1"
TEMPLATE_DIRECTORY = Path(__file__).resolve().parents[3] / "emails"


def send_welcome_message(*, to: str, message_id: str, template_directory: Path = TEMPLATE_DIRECTORY) -> None:
    """Deliver the exact multipart template using the already configured SMTP relay."""
    settings = get_settings()
    if not settings.brevo_smtp_username or not settings.brevo_smtp_password:
        raise RuntimeError("Welcome SMTP is not configured")
    message = EmailMessage()
    message["From"] = f"{settings.smtp_from_name} <{settings.smtp_from_email}>"
    message["To"] = to
    message["Subject"] = "Welcome to FindEZ"
    message["Reply-To"] = "info@findez.ai"
    message["Message-ID"] = message_id
    text = (template_directory / "welcome.txt").read_text()
    html = (template_directory / "welcome.html").read_text()
    if "{{" in text or "{{" in html:
        raise ValueError("Welcome template has unfilled placeholders")
    message.set_content(text)
    message.add_alternative(html, subtype="html")
    with smtplib.SMTP(settings.brevo_smtp_host, settings.brevo_smtp_port, timeout=15) as smtp:
        smtp.starttls(context=ssl.create_default_context())
        smtp.login(settings.brevo_smtp_username, settings.brevo_smtp_password)
        refused = smtp.send_message(message)
        if refused:
            raise RuntimeError("Welcome recipient was refused")


def _timestamp(value) -> datetime | None:
    try:
        parsed = value if isinstance(value, datetime) else datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return parsed if parsed.tzinfo is not None else None
    except (TypeError, ValueError):
        return None


def send_welcome_once(user_id: str) -> None:
    """Background task, separate from authentication success and response handling.

    A unique delivery claim is inserted before SMTP. A failed or ambiguous SMTP
    attempt is never automatically retried, since SMTP has no idempotency API.
    This favors avoiding duplicates over retrying potentially accepted messages.
    """
    if WELCOME_LAUNCH_AT is None:
        return
    try:
        client = get_supabase_raw()
        # Auth is authoritative for the recipient and confirmation, not profile
        # contact_email, client metadata, or a recipient supplied in a request.
        response = client.auth.admin.get_user_by_id(user_id)
        user = response.user if response else None
        created = _timestamp(getattr(user, "created_at", None))
        confirmed = _timestamp(getattr(user, "email_confirmed_at", None))
        if (not user or str(user.id) != user_id or not created or not confirmed
                or created < WELCOME_LAUNCH_AT or not user.email):
            return
        existing = client.table("email_deliveries").select("id").eq("user_id", user_id).eq("idempotency_key", WELCOME_KEY).execute()
        if existing.data:
            return
        message_id = make_msgid(domain="findez.ai")
        try:
            claim = client.table("email_deliveries").insert({
                "user_id": user_id, "idempotency_key": WELCOME_KEY,
                "template": "welcome", "recipient": user.email,
                "status": "pending", "message_id": message_id,
            }).execute()
            if not claim.data:
                return
        except Exception as exc:
            # The DB unique constraint also prevents concurrent-worker sends.
            if getattr(exc, "code", None) != "23505":
                logger.warning("welcome_claim_failed")
            return
        try:
            send_welcome_message(to=user.email, message_id=message_id)
        except Exception:
            logger.warning("welcome_delivery_failed")
            client.table("email_deliveries").update({"status": "failed", "error_code": "delivery_failed"}).eq("user_id", user_id).eq("idempotency_key", WELCOME_KEY).execute()
            return
        # If this update fails, the pending claim still prevents a duplicate.
        client.table("email_deliveries").update({"status": "sent", "sent_at": datetime.now(timezone.utc).isoformat()}).eq("user_id", user_id).eq("idempotency_key", WELCOME_KEY).execute()
    except Exception:
        # No exception text, recipient, credentials or message body in logs.
        logger.warning("welcome_background_failed")


def schedule_welcome(background_tasks, user_id: str) -> None:
    if WELCOME_LAUNCH_AT is not None:
        background_tasks.add_task(send_welcome_once, user_id)

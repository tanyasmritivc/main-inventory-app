import os
import smtplib
import ssl
from email.message import EmailMessage

from app.core.config import get_settings


def send_transactional_email(
    *,
    to: str,
    subject: str,
    html: str,
    text: str,
) -> None:
    """Send app mail through the configured SMTP relay, with Resend as fallback."""
    settings = get_settings()
    sender = f"{settings.smtp_from_name} <{settings.smtp_from_email}>"
    if settings.brevo_smtp_username and settings.brevo_smtp_password:
        message = EmailMessage()
        message["From"] = sender
        message["To"] = to
        message["Subject"] = subject.replace("\r", " ").replace("\n", " ")
        message.set_content(text)
        message.add_alternative(html, subtype="html")
        with smtplib.SMTP(
            settings.brevo_smtp_host,
            settings.brevo_smtp_port,
            timeout=15,
        ) as smtp:
            smtp.starttls(context=ssl.create_default_context())
            smtp.login(settings.brevo_smtp_username, settings.brevo_smtp_password)
            smtp.send_message(message)
        return

    resend_key = os.environ.get("RESEND_API_KEY", "")
    if resend_key:
        import resend

        resend.api_key = resend_key
        resend.Emails.send({
            "from": sender,
            "to": [to],
            "subject": subject,
            "html": html,
            "text": text,
        })
        return
    raise RuntimeError("Transactional email is not configured")

from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.services import welcome_email as welcome

LAUNCH = datetime(2026, 11, 12, tzinfo=timezone.utc)


@pytest.fixture
def delivery(monkeypatch):
    client = MagicMock()
    query = client.table.return_value
    query.select.return_value = query
    query.eq.return_value = query
    query.insert.return_value = query
    query.update.return_value = query
    query.execute.side_effect = [SimpleNamespace(data=[]), SimpleNamespace(data=[{"id": "claim"}]), SimpleNamespace(data=[])]
    user = SimpleNamespace(id="new-user", email="test@example.test", created_at=LAUNCH, email_confirmed_at=LAUNCH)
    client.auth.admin.get_user_by_id.return_value = SimpleNamespace(user=user)
    send = MagicMock()
    monkeypatch.setattr(welcome, "WELCOME_LAUNCH_AT", LAUNCH)
    monkeypatch.setattr(welcome, "get_supabase_raw", lambda: client)
    monkeypatch.setattr(welcome, "send_welcome_message", send)
    return client, query, user, send


def test_disabled_does_not_queue_or_read_accounts(delivery, monkeypatch):
    client, _, _, send = delivery
    monkeypatch.setattr(welcome, "WELCOME_LAUNCH_AT", None)
    tasks = MagicMock()
    welcome.schedule_welcome(tasks, "new-user")
    welcome.send_welcome_once("new-user")
    tasks.add_task.assert_not_called()
    client.auth.admin.get_user_by_id.assert_not_called()
    send.assert_not_called()


@pytest.mark.parametrize("field,value", [
    ("created_at", "2026-11-11T23:59:59Z"),
    ("created_at", None),
    ("email_confirmed_at", None),
    ("email", ""),
    ("id", "other-user"),
])
def test_no_existing_unconfirmed_or_mismatched_accounts(delivery, field, value):
    client, _, user, send = delivery
    setattr(user, field, value)
    welcome.send_welcome_once("new-user")
    client.table.assert_not_called()
    send.assert_not_called()


def test_confirmed_new_account_claims_before_sending(delivery):
    _, query, _, send = delivery
    welcome.send_welcome_once("new-user")
    claim = query.insert.call_args.args[0]
    assert claim["status"] == "pending"
    assert claim["idempotency_key"] == welcome.WELCOME_KEY
    assert claim["recipient"] == "test@example.test"
    send.assert_called_once_with(to="test@example.test", message_id=claim["message_id"])
    assert query.update.call_args.args[0]["status"] == "sent"


@pytest.mark.parametrize("status", ["pending", "sent", "failed"])
def test_existing_claim_never_sends_again(delivery, status):
    _, query, _, send = delivery
    query.execute.side_effect = [SimpleNamespace(data=[{"id": "claim", "status": status}])]
    welcome.send_welcome_once("new-user")
    send.assert_not_called()
    query.insert.assert_not_called()


def test_concurrent_unique_claim_loser_does_not_send(delivery):
    _, query, _, send = delivery
    duplicate = RuntimeError("duplicate")
    duplicate.code = "23505"
    query.execute.side_effect = [SimpleNamespace(data=[]), duplicate]
    welcome.send_welcome_once("new-user")
    send.assert_not_called()


def test_smtp_failure_does_not_escape_or_log_sensitive_details(delivery, caplog):
    _, query, _, send = delivery
    send.side_effect = RuntimeError("test@example.test secret-password")
    welcome.send_welcome_once("new-user")
    assert query.update.call_args.args[0]["status"] == "failed"
    assert "welcome_delivery_failed" in caplog.text
    assert "test@example.test" not in caplog.text
    assert "secret-password" not in caplog.text


def test_sent_but_audit_failure_keeps_original_claim(delivery, caplog):
    _, query, _, send = delivery
    query.execute.side_effect = [SimpleNamespace(data=[]), SimpleNamespace(data=[{"id": "claim"}]), RuntimeError("private")]
    welcome.send_welcome_once("new-user")
    send.assert_called_once()
    assert query.update.call_count == 1
    assert "private" not in caplog.text


def test_smtp_message_is_one_recipient_and_both_exact_templates(monkeypatch):
    smtp = MagicMock()
    smtp.__enter__.return_value = smtp
    smtp.send_message.return_value = {}
    monkeypatch.setattr(welcome.smtplib, "SMTP", lambda *args, **kwargs: smtp)
    monkeypatch.setattr(welcome, "get_settings", lambda: SimpleNamespace(
        brevo_smtp_host="smtp.example.test", brevo_smtp_port=587,
        brevo_smtp_username="fixture", brevo_smtp_password="fixture",
        smtp_from_name="FindEZ", smtp_from_email="noreply@findez.ai",
    ))
    welcome.send_welcome_message(to="test@example.test", message_id="<fixture@findez.ai>")
    message = smtp.send_message.call_args.args[0]
    assert message["To"] == "test@example.test"
    assert message["Cc"] is None and message["Bcc"] is None
    assert message["Reply-To"] == "info@findez.ai"
    assert message["Subject"] == "Welcome to FindEZ"
    assert message.get_body(preferencelist=("html",)).get_content() == (welcome.TEMPLATE_DIRECTORY / "welcome.html").read_text()
    assert message.get_body(preferencelist=("plain",)).get_content() == (welcome.TEMPLATE_DIRECTORY / "welcome.txt").read_text()
    smtp.starttls.assert_called_once()

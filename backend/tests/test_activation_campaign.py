from types import SimpleNamespace
from unittest.mock import Mock
from uuid import uuid4

from fastapi import FastAPI
from fastapi.testclient import TestClient
import pytest

from app.api.routes import activation
from app.services import activation_campaign as campaign


def test_older_account_starts_with_intro_and_later_messages_rotate():
    assert campaign.copy_for(1)[0] == "Your FindEZ inventory is waiting."
    assert campaign.copy_for(2)[0] == "Know what you have. Find what you need."
    assert len({campaign.copy_for(step) for step in range(1, 7)}) == 6
    assert campaign.copy_for(7) == campaign.copy_for(3)


def test_disabled_worker_does_not_touch_database(monkeypatch):
    monkeypatch.delenv("FINDEZ_ACTIVATION_ENABLED", raising=False)
    client = Mock()
    monkeypatch.setattr(campaign, "get_supabase_raw", client)
    assert campaign.dispatch() == 0
    client.assert_not_called()


def test_missing_unsubscribe_url_suppresses_email(monkeypatch):
    monkeypatch.setattr(campaign, "get_settings", lambda: SimpleNamespace(brevo_smtp_username="u", brevo_smtp_password="p"))
    monkeypatch.setenv("FINDEZ_ACTIVATION_API_URL", "http://example.invalid")
    monkeypatch.delenv("FINDEZ_PERSONALIZATION_PUSH_ENABLED", raising=False)
    assert not any(campaign.available_channels().values())
    monkeypatch.setenv("FINDEZ_ACTIVATION_API_URL", "https://example.invalid/api")
    assert campaign.available_channels() == {"allow_email": True, "allow_push": False}


def test_email_contains_one_click_optout_and_correlation(monkeypatch):
    sender = Mock()
    monkeypatch.setattr(campaign.email_delivery, "send_transactional_email", sender)
    monkeypatch.setenv("FINDEZ_ACTIVATION_API_URL", "https://example.invalid/api")
    token, reminder = uuid4(), str(uuid4())
    assert campaign.submit({"id": reminder, "channel": "email", "email": "n@example.invalid",
                            "step": 1, "unsubscribe": token}) == "accepted"
    msg = sender.call_args.kwargs
    url = f"https://example.invalid/api/activation/unsubscribe/{token}"
    assert url in msg["text"] and url in msg["html"]
    assert msg["headers"]["List-Unsubscribe"] == f"<{url}>"
    assert msg["headers"]["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click"
    assert msg["headers"]["X-Mailin-custom"] == f"activation:{reminder}"


@pytest.mark.parametrize("details,expected", [(True, "first Space"), (False, "Open FindEZ")])
def test_opted_push_copy_respects_privacy(monkeypatch, details, expected):
    sender = Mock(return_value=("accepted", None))
    monkeypatch.setattr(campaign, "send_once", sender)
    row = {"id": str(uuid4()), "user_id": str(uuid4()), "channel": "push", "step": 1, "details": details}
    assert campaign.submit(row) == "accepted"
    assert expected in sender.call_args.args[-1]["body"]
    assert sender.call_args.args[1:3] == (row["id"], row["user_id"])


def test_ambiguous_submission_consumes_cycle(monkeypatch):
    client, submit = Mock(), Mock(side_effect=TimeoutError())
    client.rpc.return_value.execute.side_effect = [
        SimpleNamespace(data="id"), SimpleNamespace(data={"id": "id"}), SimpleNamespace(data=None)]
    monkeypatch.setattr(campaign, "enabled", lambda: True)
    monkeypatch.setattr(campaign, "available_channels", lambda: {"allow_email": True, "allow_push": False})
    monkeypatch.setattr(campaign, "get_supabase_raw", lambda: client)
    monkeypatch.setattr(campaign, "submit", submit)
    assert campaign.dispatch() == 0
    submit.assert_called_once()
    client.table.return_value.update.assert_called_once_with({"outcome": "unknown"})


def test_optout_and_webhook_routes(monkeypatch):
    app = FastAPI()
    app.include_router(activation.router)
    web = TestClient(app)
    db = Mock()
    monkeypatch.setattr(activation, "get_supabase_raw", lambda: db)
    monkeypatch.setenv("FINDEZ_ACTIVATION_BREVO_TOKEN", "test-secret")
    token = str(uuid4())
    path = "/activation/unsubscribe/" + token
    assert web.get(path).headers["cache-control"] == "no-store"
    db.table.assert_not_called()
    assert web.post(path, data={"List-Unsubscribe": "One-Click"}).status_code == 200
    db.table.return_value.update.assert_called_once_with({"email_enabled": False})
    db.table.return_value.update.return_value.eq.assert_called_once_with("unsubscribe_token", token)
    assert web.get("/activation/preferences").status_code in (401, 403)
    db.reset_mock()
    payload = {"event": "delivered", "X-Mailin-custom": "activation:" + token}
    assert web.post("/activation/brevo-events", json=payload).status_code == 403
    db.table.assert_not_called()
    assert web.post("/activation/brevo-events", json=payload, headers={"Authorization": "Bearer test-secret"}).is_success
    assert "delivered_at" in db.table.return_value.update.call_args.args[0]


def test_shared_workspace_preference_uses_signed_in_actor(monkeypatch):
    app = FastAPI()
    app.include_router(activation.router)
    owner, member = str(uuid4()), str(uuid4())
    app.dependency_overrides[activation.get_current_user] = lambda: activation.AuthenticatedUser(user_id=owner, actor_id=member)
    db = Mock()
    db.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"email_enabled": False}]
    monkeypatch.setattr(activation, "get_supabase_raw", lambda: db)
    response = TestClient(app).put("/activation/preferences", json={"email_enabled": False})
    assert response.json() == {"enrolled": True, "email_enabled": False}
    db.table.return_value.update.return_value.eq.assert_called_once_with("user_id", member)
    db.table.return_value.select.return_value.eq.assert_called_once_with("user_id", member)

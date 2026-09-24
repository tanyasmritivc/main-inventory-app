import asyncio

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.api.routes import email as email_route
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import email_service
from app.services.email_service import (
    normalize_email,
    render_custom_message,
    render_team_invitation,
)


def test_normalize_email():
    assert normalize_email(" Person@Example.COM ") == "person@example.com"


@pytest.mark.parametrize("value", ["", "missing-at.example", "a@b", "a b@example.com"])
def test_rejects_invalid_email(value):
    with pytest.raises(HTTPException) as exc:
        normalize_email(value)
    assert exc.value.status_code == 400


def test_invitation_escapes_untrusted_share_name():
    subject, text, html = render_team_invitation(
        share_name="<script>alert(1)</script>",
        share_code="ABC123",
    )
    assert "<script>" not in html
    assert "&lt;script&gt;" in html
    assert "ABC123" in text
    assert "invited" in subject


def test_custom_message_is_plain_text_and_html_escaped():
    subject, text, html = render_custom_message(
        subject="Status update", body="Hello <script>alert(1)</script>\nSecond line",
    )
    assert subject == "Status update"
    assert "<script>" not in html
    assert "&lt;script&gt;" in html
    assert "Second line" in text


def test_custom_message_rejects_header_injection():
    with pytest.raises(HTTPException):
        render_custom_message(subject="Hello\nBcc: attacker@example.com", body="Text")


class _Query:
    def __init__(self, data):
        self.data = data

    def select(self, *_):
        return self

    def eq(self, *_):
        return self

    def maybe_single(self):
        return self

    def execute(self):
        return type("Response", (), {"data": self.data})()


class _Supabase:
    def __init__(self, data):
        self.data = data

    def table(self, *_):
        return _Query(self.data)


class _AuditQuery:
    def __init__(self, client):
        self.client = client
        self.operation = None
        self.columns = None
        self.payload = None

    def select(self, columns):
        self.operation = "select"
        self.columns = columns
        return self

    def insert(self, payload):
        self.operation = "insert"
        self.payload = payload
        return self

    def update(self, payload):
        self.operation = "update"
        self.payload = payload
        return self

    def eq(self, *_):
        return self

    def gte(self, *_):
        return self

    def maybe_single(self):
        return self

    def execute(self):
        if self.operation == "insert":
            self.client.inserts.append(self.payload)
            data = self.payload
        elif self.operation == "update":
            self.client.updates.append(self.payload)
            data = self.payload
        elif self.columns == "id":
            data = []
        else:
            data = None
        return type("Response", (), {"data": data})()


class _AuditSupabase:
    def __init__(self):
        self.inserts = []
        self.updates = []

    def table(self, name):
        assert name == "email_deliveries"
        return _AuditQuery(self)


def test_audited_delivery_uses_shared_transport(monkeypatch):
    client = _AuditSupabase()
    delivered = {}

    def fake_delivery(**kwargs):
        delivered.update(kwargs)

    monkeypatch.setattr(email_service, "get_supabase_admin", lambda: client)
    monkeypatch.setattr(email_service, "deliver_transactional_email", fake_delivery)

    result = asyncio.run(
        email_service._send_transactional_email_locked(
            user_id="user-1",
            idempotency_key="request-12345678",
            template="custom",
            recipient="Person@Example.com",
            subject="Status",
            text="Done",
            html="<p>Done</p>",
        )
    )

    assert result["status"] == "sent"
    assert delivered["to"] == "person@example.com"
    assert delivered["message_id"] == result["message_id"]
    assert client.inserts[0]["status"] == "pending"
    assert client.updates[-1]["status"] == "sent"


def _client(monkeypatch, share=None):
    app = FastAPI()
    app.state.limiter = email_route.limiter
    app.include_router(email_route.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        user_id="00000000-0000-0000-0000-000000000001"
    )
    monkeypatch.setattr(email_route, "get_supabase_admin", lambda: _Supabase(share))

    async def fake_send(**kwargs):
        return {"status": "sent", "message_id": "<test@findez.ai>", "duplicate": False}

    monkeypatch.setattr(email_route, "send_transactional_email", fake_send)
    return TestClient(app)


def test_transactional_endpoint_accepts_valid_template(monkeypatch):
    client = _client(monkeypatch, {"share_name": "Robotics", "share_code": "ABC123"})
    response = client.post(
        "/email/send",
        headers={"Idempotency-Key": "request-12345678"},
        json={
            "template": "team_invitation",
            "recipient": "person@example.com",
            "variables": {"share_id": "share-1"},
        },
    )
    assert response.status_code == 202
    assert response.json()["status"] == "sent"


def test_transactional_endpoint_requires_idempotency_key(monkeypatch):
    client = _client(monkeypatch, {"share_name": "Robotics", "share_code": "ABC123"})
    response = client.post("/email/send", json={
        "template": "team_invitation", "recipient": "person@example.com",
        "variables": {"share_id": "share-1"},
    })
    assert response.status_code == 400


def test_transactional_endpoint_rejects_unapproved_variables(monkeypatch):
    client = _client(monkeypatch, {"share_name": "Robotics", "share_code": "ABC123"})
    response = client.post("/email/send", headers={"Idempotency-Key": "request-12345678"}, json={
        "template": "team_invitation", "recipient": "person@example.com",
        "variables": {"share_id": "share-1", "html": "<b>untrusted</b>"},
    })
    assert response.status_code == 400


def test_transactional_endpoint_enforces_share_ownership(monkeypatch):
    client = _client(monkeypatch, None)
    response = client.post("/email/send", headers={"Idempotency-Key": "request-12345678"}, json={
        "template": "team_invitation", "recipient": "person@example.com",
        "variables": {"share_id": "not-owned"},
    })
    assert response.status_code == 403


def test_transactional_endpoint_accepts_custom_subject_and_body(monkeypatch):
    client = _client(monkeypatch)
    response = client.post("/email/send", headers={"Idempotency-Key": "custom-request-1234"}, json={
        "template": "custom", "recipient": "person@example.com",
        "subject": "Status update", "body": "The requested operation completed.",
    })
    assert response.status_code == 202
    assert response.json()["status"] == "sent"


def test_custom_email_rejects_variables(monkeypatch):
    client = _client(monkeypatch)
    response = client.post("/email/send", headers={"Idempotency-Key": "custom-request-1234"}, json={
        "template": "custom", "recipient": "person@example.com",
        "subject": "Status", "body": "Done", "variables": {"html": "<b>unsafe</b>"},
    })
    assert response.status_code == 400

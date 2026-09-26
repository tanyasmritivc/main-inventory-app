import asyncio

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.api.routes import email as email_route
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import email_service
from app.services.email_service import normalize_email, render_team_invitation


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
        # postgrest-py 0.19 returns None rather than an empty response when
        # maybe_single() matches no row.
        if self.data is None:
            return None
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
        self.single = False

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
        self.single = True
        return self

    def execute(self):
        response = lambda data: type("Response", (), {"data": data})()
        if self.operation == "insert":
            self.client.inserts.append(self.payload)
            self.client.row = {**self.payload}
            return response([self.payload])
        if self.operation == "update":
            if self.payload.get("status") in self.client.fail_updates:
                raise RuntimeError("database unavailable")
            self.client.updates.append(self.payload)
            self.client.row = {**(self.client.row or {}), **self.payload}
            return response([self.payload])
        if self.columns == "id":
            return response([{"id": str(i)} for i in range(self.client.recent_count)])
        if self.single and self.client.row is None:
            return None
        return response(self.client.row)


class _AuditSupabase:
    def __init__(self, row=None, recent_count=0, fail_updates=()):
        self.row = row
        self.recent_count = recent_count
        self.fail_updates = set(fail_updates)
        self.inserts = []
        self.updates = []

    def table(self, name):
        assert name == "email_deliveries"
        return _AuditQuery(self)


def _audited_send(monkeypatch, client, delivery=None):
    delivered = []

    def fake_delivery(**kwargs):
        delivered.append(kwargs)
        if delivery:
            delivery(**kwargs)

    monkeypatch.setattr(email_service, "get_supabase_admin", lambda: client)
    monkeypatch.setattr(email_service, "deliver_transactional_email", fake_delivery)
    result = asyncio.run(
        email_service.send_transactional_email(
            user_id="user-1",
            idempotency_key="request-12345678",
            template="team_invitation",
            recipient="Person@Example.com",
            subject="Status",
            text="Done",
            html="<p>Done</p>",
        )
    )
    return result, delivered


def test_audited_delivery_uses_shared_transport(monkeypatch):
    client = _AuditSupabase()
    result, delivered = _audited_send(monkeypatch, client)

    assert result == {
        "status": "sent",
        "message_id": result["message_id"],
        "duplicate": False,
    }
    assert delivered[0]["to"] == "person@example.com"
    assert delivered[0]["message_id"] == result["message_id"]
    assert client.inserts[0]["status"] == "pending"
    assert client.inserts[0]["recipient"] == "person@example.com"
    assert client.updates[-1]["status"] == "sent"


@pytest.mark.parametrize("status", ["pending", "sent"])
def test_repeated_idempotency_key_does_not_resend(monkeypatch, status):
    client = _AuditSupabase(row={"status": status, "message_id": "<first@findez.ai>"})
    result, delivered = _audited_send(monkeypatch, client)

    assert result == {"status": status, "message_id": "<first@findez.ai>", "duplicate": True}
    assert delivered == []
    assert client.inserts == [] and client.updates == []


def test_failed_delivery_is_retried_with_original_message_id(monkeypatch):
    client = _AuditSupabase(row={"status": "failed", "message_id": "<first@findez.ai>"})
    result, delivered = _audited_send(monkeypatch, client)

    assert result["status"] == "sent" and result["duplicate"] is False
    assert delivered[0]["message_id"] == "<first@findez.ai>"
    assert client.inserts == []
    assert [u["status"] for u in client.updates] == ["pending", "sent"]
    assert client.updates[0]["error_code"] is None


def test_hourly_rate_limit_blocks_before_audit_or_delivery(monkeypatch):
    client = _AuditSupabase(recent_count=30)
    with pytest.raises(HTTPException) as exc:
        _audited_send(monkeypatch, client)

    assert exc.value.status_code == 429
    assert client.inserts == []


def test_transport_failure_is_recorded_without_leaking_details(monkeypatch):
    client = _AuditSupabase()

    def broken(**_):
        raise ConnectionRefusedError("smtp-relay.internal:587 password=secret")

    with pytest.raises(HTTPException) as exc:
        _audited_send(monkeypatch, client, delivery=broken)

    assert exc.value.status_code == 503
    assert "smtp" not in exc.value.detail.lower()
    assert client.updates[-1] == {"status": "failed", "error_code": "ConnectionRefusedError"}


def test_transport_failure_survives_failed_status_update(monkeypatch):
    client = _AuditSupabase(fail_updates={"failed"})

    def broken(**_):
        raise ConnectionRefusedError("down")

    with pytest.raises(HTTPException) as exc:
        _audited_send(monkeypatch, client, delivery=broken)

    assert exc.value.status_code == 503


def test_sent_status_update_failure_does_not_invite_a_duplicate_send(monkeypatch):
    client = _AuditSupabase(fail_updates={"sent"})
    result, delivered = _audited_send(monkeypatch, client)

    assert result["status"] == "sent"
    assert len(delivered) == 1
    assert client.row["status"] == "pending"

    retry, delivered_again = _audited_send(monkeypatch, client)
    assert retry["duplicate"] is True
    assert delivered_again == []


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


def test_email_service_has_no_caller_authored_renderer():
    assert not hasattr(email_service, "render_custom_message")


@pytest.mark.parametrize(
    "payload",
    [
        {
            "template": "custom",
            "recipient": "person@example.com",
            "subject": "Account notice",
            "body": "Verify your password at https://example.test",
        },
        {
            "template": "team_invitation",
            "recipient": "person@example.com",
            "variables": {"share_id": "share-1"},
            "subject": "Account notice",
        },
        {
            "template": "team_invitation",
            "recipient": "person@example.com",
            "variables": {"share_id": "share-1"},
            "body": "Verify your password",
        },
        {
            "template": "team_invitation",
            "recipient": "person@example.com",
            "variables": {"share_id": "share-1"},
            "html": "<a href='https://example.test'>Verify</a>",
        },
    ],
)
def test_endpoint_rejects_caller_authored_content(monkeypatch, payload):
    sent = []

    async def recording_send(**kwargs):
        sent.append(kwargs)
        return {"status": "sent", "message_id": "<test@findez.ai>", "duplicate": False}

    client = _client(monkeypatch, {"share_name": "Robotics", "share_code": "ABC123"})
    monkeypatch.setattr(email_route, "send_transactional_email", recording_send)
    response = client.post(
        "/email/send", headers={"Idempotency-Key": "request-12345678"}, json=payload,
    )

    assert response.status_code == 422
    assert sent == []


def test_invitation_endpoint_sends_only_the_findez_template(monkeypatch):
    sent = []

    async def recording_send(**kwargs):
        sent.append(kwargs)
        return {"status": "sent", "message_id": "<test@findez.ai>", "duplicate": False}

    client = _client(monkeypatch, {"share_name": "Robotics", "share_code": "ABC123"})
    monkeypatch.setattr(email_route, "send_transactional_email", recording_send)
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
    expected = render_team_invitation(share_name="Robotics", share_code="ABC123")
    assert (sent[0]["subject"], sent[0]["text"], sent[0]["html"]) == expected
    assert sent[0]["template"] == "team_invitation"


def _sharing_client(monkeypatch, share_rows):
    from app.api.routes import sharing as sharing_route

    class _ShareQuery(_Query):
        def execute(self):
            return type("Response", (), {"data": self.data})()

    app = FastAPI()
    app.include_router(sharing_route.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        user_id="00000000-0000-0000-0000-000000000001"
    )
    monkeypatch.setattr(
        sharing_route,
        "get_supabase_admin",
        lambda: type("Client", (), {"table": lambda self, *_: _ShareQuery(share_rows)})(),
    )
    sent = []

    async def fake_send(**kwargs):
        sent.append(kwargs)
        return {"status": "sent", "message_id": "<test@findez.ai>", "duplicate": False}

    monkeypatch.setattr(sharing_route, "send_transactional_email", fake_send)
    return TestClient(app), sent


def test_space_invite_uses_audited_transactional_email(monkeypatch):
    client, sent = _sharing_client(
        monkeypatch, [{"share_name": "Robotics", "share_code": "ABC123"}]
    )
    response = client.post("/sharing/share-1/invite", json={"email": "person@example.com"})

    assert response.status_code == 200
    assert response.json() == {"sent": True, "email": "person@example.com", "share_code": "ABC123"}
    assert sent[0]["template"] == "team_invitation"
    assert sent[0]["recipient"] == "person@example.com"
    assert sent[0]["idempotency_key"].startswith("legacy-invite:")
    assert "ABC123" in sent[0]["text"]


def test_space_invite_requires_share_ownership(monkeypatch):
    client, sent = _sharing_client(monkeypatch, [])
    response = client.post("/sharing/share-1/invite", json={"email": "person@example.com"})

    assert response.status_code == 403
    assert sent == []


def test_space_invitation_links_to_the_universal_link_path(monkeypatch):
    class _Settings:
        frontend_url = "https://www.findez.ai/"

    monkeypatch.setattr(email_service, "get_settings", lambda: _Settings())
    assert email_service.space_invitation_url(" abc123 ") == "https://www.findez.ai/join/ABC123"
    assert email_service.space_invitation_url("A/B?1") == "https://www.findez.ai/join/A%2FB%3F1"

    subject, text, html = render_team_invitation(share_name="Robotics", share_code="ABC123")
    assert "https://www.findez.ai/join/ABC123" in text
    assert 'href="https://www.findez.ai/join/ABC123"' in html
    assert "join?code=" not in text + html
    assert "App Store" in text and "App Store" in html


def test_space_invitation_link_follows_configured_frontend(monkeypatch):
    class _Settings:
        frontend_url = "https://findez.ai"

    monkeypatch.setattr(email_service, "get_settings", lambda: _Settings())
    _, text, html = render_team_invitation(share_name="Robotics", share_code="ABC123")
    assert "https://findez.ai/join/ABC123" in text
    assert 'href="https://findez.ai/join/ABC123"' in html

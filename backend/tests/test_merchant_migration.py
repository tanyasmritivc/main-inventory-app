from types import SimpleNamespace

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.api.routes import merchant_migration as routes
from app.core.auth import AuthenticatedUser, get_current_user

TEAM = "c2000000-0000-0000-0000-000000000001"
CONNECTION = "c3000000-0000-0000-0000-000000000001"
ACTOR = "c1000000-0000-0000-0000-000000000001"
PATH = f"/teams/{TEAM}/shopify/{CONNECTION}/migration"


@pytest.fixture
def client(monkeypatch):
    app = FastAPI()
    app.include_router(routes.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id=ACTOR)
    monkeypatch.setattr(routes, "membership", lambda *args: {"role": "viewer"})
    monkeypatch.setattr(routes, "enabled", lambda: SimpleNamespace(merchant_migration_enabled=True, physical_memory_enabled=True))
    monkeypatch.setattr(routes, "connection", lambda *args: {"connection_id": CONNECTION})
    return TestClient(app)


def test_progress_is_read_only_and_bound_to_authenticated_actor(client, monkeypatch):
    calls = []
    report = {"total_variants": 12, "confirmed_variants": 2, "can_confirm": False}
    monkeypatch.setattr(routes, "call", lambda *args, **params: calls.append((args, params)) or report)
    assert client.get(PATH).json() == report
    assert calls == [(("adoption_report",), {"team": TEAM, "connection": CONNECTION, "actor": ACTOR})]
    assert client.post(PATH, json={"actor": "other", "confirmed": True}).status_code == 405


@pytest.mark.parametrize("flag", ["merchant_migration_enabled", "physical_memory_enabled"])
def test_each_disabled_capability_blocks_the_guide(client, monkeypatch, flag):
    settings = SimpleNamespace(merchant_migration_enabled=True, physical_memory_enabled=True)
    setattr(settings, flag, False)
    monkeypatch.setattr(routes, "enabled", lambda: settings)
    monkeypatch.setattr(routes, "call", lambda *args, **params: pytest.fail("Disabled guide reached database"))
    assert client.get(PATH).status_code == 503


@pytest.mark.parametrize("gate,code", [("membership", 403), ("connection", 404)])
def test_revocation_or_foreign_connection_never_reaches_progress(client, monkeypatch, gate, code):
    def denied(*args):
        raise HTTPException(code, "Access changed")
    monkeypatch.setattr(routes, gate, denied)
    monkeypatch.setattr(routes, "call", lambda *args, **params: pytest.fail("Unauthorized guide reached database"))
    assert client.get(PATH).status_code == code

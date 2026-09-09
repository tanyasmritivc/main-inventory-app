import os
from pathlib import Path
from types import SimpleNamespace

os.environ.setdefault("SUPABASE_URL", "http://localhost:54321")
os.environ.setdefault("SUPABASE_ANON_KEY", "placeholder-anon")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "placeholder-service")
os.environ.setdefault("SUPABASE_JWKS_URL", "http://localhost:54321/auth/v1/.well-known/jwks.json")
os.environ.setdefault("OPENAI_API_KEY", "placeholder-openai")

from app.core.api_key_auth import (  # noqa: E402
    API_KEY_PATTERN,
    APIKeyPrincipal,
    generate_api_key,
    hash_api_key,
    validate_scopes,
    verify_api_key,
)


def test_generated_keys_have_exact_live_and_test_formats():
    live = generate_api_key("live")
    test = generate_api_key("test")
    assert len(live.removeprefix("findez_live_sk_")) == 32
    assert len(test.removeprefix("findez_test_sk_")) == 32
    assert API_KEY_PATTERN.fullmatch(live)
    assert API_KEY_PATTERN.fullmatch(test)
    assert live[:20] != live


def test_argon2_hash_never_contains_raw_key_and_verifies():
    raw = generate_api_key("test")
    hashed = hash_api_key(raw)
    assert raw not in hashed
    assert hashed.startswith("$argon2")
    assert verify_api_key(raw, hashed)
    assert not verify_api_key(raw + "x", hashed)


def test_workspace_and_global_scopes_cannot_be_mixed():
    assert validate_scopes(workspace_id="workspace", scopes=["items:read", "workspace:read"]) == {
        "items:read", "workspace:read"
    }
    assert validate_scopes(workspace_id=None, scopes=["org:read"]) == {"org:read"}
    for workspace_id, scopes in [
        ("workspace", ["org:read"]),
        (None, ["items:read"]),
        ("workspace", ["unknown"]),
    ]:
        try:
            validate_scopes(workspace_id=workspace_id, scopes=scopes)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid scope combination was accepted")


def test_global_scopes_imply_only_the_documented_operations():
    reader = APIKeyPrincipal("key", None, "org", frozenset({"org:read"}), "creator")
    writer = APIKeyPrincipal("key", None, "org", frozenset({"org:write"}), "creator")
    assert reader.allows("items:read")
    assert reader.allows("workspace:read")
    assert not reader.allows("items:write")
    assert writer.allows("items:write")
    assert writer.allows("import:write")
    assert not writer.allows("items:read")


def test_migration_uses_rls_and_does_not_create_a_spaces_table():
    migration = Path(__file__).parents[1] / "supabase/migrations/032_api_key_authentication.sql"
    sql = migration.read_text().lower()
    assert "create table if not exists public.api_keys" in sql
    assert "alter table public.api_keys enable row level security" in sql
    assert "request.jwt.claims" in sql
    assert "items_api_key_select" in sql
    assert "items_api_key_insert" in sql
    assert "items_api_key_update" in sql
    assert "create table public.spaces" not in sql
    assert "create table if not exists public.spaces" not in sql

    recursion_fix = (migration.parent / "033_fix_team_membership_rls_recursion.sql").read_text().lower()
    assert "security definer" in recursion_fix
    assert "findez_is_team_member" in recursion_fix
    assert "from public.team_memberships tm" in recursion_fix


def test_integration_routes_are_mounted():
    backend = Path(__file__).parents[1]
    router_source = (backend / "app/api/router.py").read_text()
    api_source = (backend / "app/api/routes/api_v1.py").read_text()
    assert "api_router.include_router(api_v1_router)" in router_source
    assert 'prefix="/api/v1"' in api_source
    for route in [
        '@router.post("/keys"',
        '@router.get("/keys")',
        '@router.delete("/keys/{key_id}")',
        '@router.get("/items")',
        '@router.post("/items"',
        '@router.patch("/items/{item_id}")',
        '@router.post("/items/bulk")',
        '@router.get("/spaces")',
        '@router.get("/workspaces/summary")',
    ]:
        assert route in api_source


def test_data_client_uses_anon_key_and_signed_rls_claims(monkeypatch):
    from jose import jwt
    from app.services import api_key_client

    captured = {}

    class FakePostgrest:
        def auth(self, token):
            captured["token"] = token

    class FakeClient:
        postgrest = FakePostgrest()

    settings = SimpleNamespace(
        supabase_url="https://database.example",
        supabase_anon_key="anon-only",
        supabase_service_role_key="must-not-be-used",
        supabase_jwt_secret="integration-secret-at-least-32-bytes",
        supabase_jwt_audience="authenticated",
    )

    def fake_create_client(url, key):
        captured["url"] = url
        captured["key"] = key
        return FakeClient()

    monkeypatch.setattr(api_key_client, "get_settings", lambda: settings)
    monkeypatch.setattr(api_key_client, "create_client", fake_create_client)
    principal = APIKeyPrincipal(
        "11111111-1111-1111-1111-111111111111",
        "22222222-2222-2222-2222-222222222222",
        "33333333-3333-3333-3333-333333333333",
        frozenset({"items:read"}),
        "44444444-4444-4444-4444-444444444444",
    )

    api_key_client.create_api_key_rls_client(principal)
    claims = jwt.decode(
        captured["token"],
        settings.supabase_jwt_secret,
        algorithms=["HS256"],
        audience="authenticated",
    )
    assert captured["key"] == "anon-only"
    assert captured["key"] != settings.supabase_service_role_key
    assert claims["api_workspace_id"] == principal.workspace_id
    assert claims["api_org_id"] == principal.org_id
    assert claims["api_scopes"] == ["items:read"]

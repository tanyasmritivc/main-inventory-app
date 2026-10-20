"""Large inventories must not exceed database proxy URL limits."""
from types import SimpleNamespace
from uuid import UUID
from unittest.mock import MagicMock
from urllib.parse import urlencode
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.api.routes import checkouts
from app.core.auth import AuthenticatedUser, get_current_user


def database(monkeypatch, response):
    db = MagicMock()
    q = db.table.return_value
    for method in ("select", "eq", "in_", "gte", "order", "range"):
        getattr(q, method).return_value = q
    q.execute.side_effect = response
    monkeypatch.setattr(checkouts, "get_supabase_admin", lambda: db)
    return q


def test_large_inventory_http_summary_uses_bounded_exact_item_filters(monkeypatch):
    ids = [str(UUID(int=i + 1)) for i in range(670)]
    monkeypatch.setattr(checkouts, "_visible_items", lambda _: dict.fromkeys(ids))
    queried = []
    def execute():
        column, batch = q.in_.call_args.args
        assert column == "item_id"
        uri = "/rest/v1/checkouts?" + urlencode({"select": "*,items(name,location,category)", "item_id": "in.(" + ",".join(batch) + ")", "is_active": "eq.true", "order": "checked_out_at.desc,checkout_id.asc"})
        assert len(uri) < 4000
        queried.extend(batch)
        return SimpleNamespace(data=[{"checkout_id": batch[0], "item_id": batch[0], "user_id": "owner", "checked_out_at": batch[0]}])
    q = database(monkeypatch, execute)
    app = FastAPI(); app.include_router(checkouts.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id="owner")
    with TestClient(app) as client: response = client.get("/checkouts/active")
    assert response.status_code == 200
    assert queried == ids
    assert len(response.json()["checkouts"]) == 14
    assert all(call.args == ("is_active", True) for call in q.eq.call_args_list)


def test_batches_keep_pagination_filters_and_global_order(monkeypatch):
    ids = [str(UUID(int=i + 1)) for i in range(51)]
    first = [{"checkout_id": str(i), "checked_out_at": "2026-10-01"} for i in range(500)]
    pages = iter([first, [{"checkout_id": "older", "checked_out_at": "2026-09-01"}], [{"checkout_id": "newer", "checked_out_at": "2026-10-19"}]])
    q = database(monkeypatch, lambda: SimpleNamespace(data=next(pages)))
    rows = checkouts._checkout_rows(ids + ids[:1], active=False, returned_after="2026-09-01")
    assert len(rows) == 502 and rows[0]["checkout_id"] == "newer" and rows[-1]["checkout_id"] == "older"
    assert [c.args for c in q.range.call_args_list] == [(0,499),(500,999),(0,499)]
    assert [c.args[1] for c in q.in_.call_args_list] == [ids[:50],ids[:50],ids[50:]]
    assert all(c.args == ("is_active",False) for c in q.eq.call_args_list)
    assert all(c.args == ("returned_at","2026-09-01") for c in q.gte.call_args_list)


def test_empty_visibility_does_not_query_checkout_table(monkeypatch):
    q = database(monkeypatch, lambda: pytest.fail("No records are visible"))
    assert checkouts._checkout_rows([]) == []
    q.execute.assert_not_called()

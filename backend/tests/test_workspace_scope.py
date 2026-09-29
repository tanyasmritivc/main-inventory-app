import asyncio
from types import SimpleNamespace
from unittest.mock import patch

import pytest

from app.core.auth import AuthenticatedUser, require_workspace_write
from app.services.ai_agent import _execute_tool_call
from app.services.item_relationships_repo import authorized_item
from app.services.items_repo import search_items_basic
from app.schemas.inventory import BarcodeLookupRequest
from app.api.routes.items import barcode_lookup_route


class _Query:
    def __init__(self, rows):
        self.rows = rows
        self.filters = {}

    def select(self, _fields):
        return self

    def eq(self, column, value):
        self.filters[column] = value
        return self

    def maybe_single(self):
        return self

    def execute(self):
        matches = [row for row in self.rows if all(
            row.get(column) == value for column, value in self.filters.items()
        )]
        return SimpleNamespace(data=matches[0] if matches else None)


class _Client:
    def __init__(self, tables):
        self.tables = tables

    def table(self, name):
        return _Query(self.tables.get(name, []))


def test_home_inventory_query_passes_selected_workspace():
    with patch("app.services.items_repo.list_items", return_value=[]) as listed:
        assert search_items_basic(user_id="person-a", q="", workspace_id="room-a") == []
    listed.assert_called_once_with(user_id="person-a", workspace_id="room-a")


def test_object_detail_never_crosses_selected_workspace_even_for_owner():
    client = _Client({"items": [{
        "item_id": "12121212-1212-1212-1212-121212121212",
        "user_id": "person-a",
        "workspace_id": "room-b",
    }]})
    with patch("app.services.item_relationships_repo.get_supabase_admin", return_value=client):
        with pytest.raises(LookupError):
            authorized_item(
                user_id="person-a",
                item_id="12121212-1212-1212-1212-121212121212",
                selected_workspace_id="room-a",
            )


def test_ask_reads_selected_workspace_and_viewers_cannot_write():
    with patch("app.services.ai_agent.search_items_basic", return_value=[]) as searched:
        assert _execute_tool_call(
            user_id="person-a", tool_name="inventory_search",
            args={"query": "tape"}, workspace_id="room-a",
            workspace_role="viewer",
        ) == []
    searched.assert_called_once_with(
        user_id="person-a", q="tape", workspace_id="room-a"
    )
    result = _execute_tool_call(
        user_id="person-a", tool_name="inventory_add_item",
        args={"name": "tape"}, workspace_id="room-a",
        workspace_role="viewer",
    )
    assert result["success"] is False


def test_workspace_viewer_is_denied_before_a_write():
    with pytest.raises(Exception) as error:
        require_workspace_write(AuthenticatedUser(
            user_id="person-a", workspace_id="room-a", workspace_role="viewer",
        ))
    assert error.value.status_code == 403


class _BarcodeQuery:
    def __init__(self, rows):
        self.rows = rows
        self.filters = {}
        self.allowed = {}

    def select(self, _fields):
        return self

    def eq(self, column, value):
        self.filters[column] = value
        return self

    def in_(self, column, values):
        self.allowed[column] = values
        return self

    def execute(self):
        matches = [row for row in self.rows if all(
            row.get(column) == value for column, value in self.filters.items()
        ) and all(
            row.get(column) in values for column, values in self.allowed.items()
        )]
        return SimpleNamespace(data=matches)


class _BarcodeClient:
    def __init__(self, rows):
        self.rows = rows

    def table(self, name):
        assert name == "items"
        return _BarcodeQuery(self.rows)


def test_barcode_lookup_finds_comember_row_only_in_selected_workspace(monkeypatch):
    row = {
        "item_id": "12121212-1212-1212-1212-121212121212",
        "user_id": "person-b",
        "workspace_id": "room-a",
        "barcode": "12345678",
        "name": "Test object",
        "quantity": 4,
        "location": "Test place",
        "category": "Other",
    }
    monkeypatch.setattr("app.api.routes.items.get_supabase_admin",
                        lambda: _BarcodeClient([row]))

    async def allowed(_user_id, _feature):
        return {"allowed": True}

    monkeypatch.setattr("app.api.routes.items.check_limit", allowed)
    monkeypatch.setattr("app.api.routes.items.lookup_in_catalog",
                        lambda _code: {"name": "Catalog identity"})

    shared = asyncio.run(barcode_lookup_route(
        BarcodeLookupRequest(barcode="12345678"),
        AuthenticatedUser(user_id="person-a", workspace_id="room-a"),
    ))
    separate = asyncio.run(barcode_lookup_route(
        BarcodeLookupRequest(barcode="12345678"),
        AuthenticatedUser(user_id="person-c", workspace_id="room-b"),
    ))
    assert shared.found_in_inventory is True
    assert shared.existing_item["item_id"] == row["item_id"]
    assert separate.found_in_inventory is False

    shared_qr = asyncio.run(barcode_lookup_route(
        BarcodeLookupRequest(barcode=row["item_id"]),
        AuthenticatedUser(user_id="person-a", workspace_id="room-a"),
    ))
    separate_qr = asyncio.run(barcode_lookup_route(
        BarcodeLookupRequest(barcode=row["item_id"]),
        AuthenticatedUser(user_id="person-c", workspace_id="room-b"),
    ))
    assert shared_qr.found_in_inventory is True
    assert separate_qr.found_in_inventory is False

"""HTTP regression: manual item metadata must survive request validation."""
from unittest.mock import patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes import items
from app.core.auth import AuthenticatedUser, get_current_user

META = {"brand": "QA Brand", "part_number": "001-QA", "subcategory": "Washers", "tags": ["release-test"]}
ITEM_ID = "30000000-0000-0000-0000-000000000001"

@pytest.fixture
def client():
    app = FastAPI()
    app.include_router(items.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id="owner")
    with TestClient(app) as client:
        yield client


def test_create_keeps_manual_fields_and_cannot_supply_ownership(client):
    def save(*, user_id, item):
        assert user_id == "owner"
        assert "user_id" not in item and "catalog_id" not in item
        assert all(item[key] == value for key, value in META.items())
        return {**item, "item_id": ITEM_ID}
    with patch.object(items, "check_item_limit", return_value={"allowed": True}), patch.object(items, "_resolve_owner_for_joined_space", return_value="owner"), patch.object(items, "_check_not_viewer_for_team_write"), patch.object(items, "add_item", side_effect=save):
        response = client.post("/add_item", json={"name": "QA washer", "category": "Hardware", "quantity": 7, "location": "Shelf", **META, "user_id": "other", "catalog_id": "forged"})
    assert response.status_code == 200
    assert all(response.json()["item"][key] == value for key, value in META.items())


def test_edit_keeps_metadata_and_quantity_only_preserves_omitted_fields(client):
    row = {"item_id": ITEM_ID, **META, "quantity": 7}
    def save(*, user_id, item_id, updates):
        assert user_id == "owner" and item_id == ITEM_ID
        row.update(updates)
        return row.copy()
    with patch.object(items, "update_item", side_effect=save) as update:
        response = client.patch("/update_item", json={"item_id": ITEM_ID, **META})
        assert response.status_code == 200
        assert update.call_args.kwargs["updates"] == META
        response = client.patch("/update_item", json={"item_id": ITEM_ID, "quantity": 9})
        assert update.call_args.kwargs["updates"] == {"quantity": 9}
        assert all(response.json()["item"][key] == value for key, value in META.items())
        response = client.patch("/update_item", json={"item_id": ITEM_ID, "brand": "", "part_number": "", "tags": []})
        assert response.json()["item"]["part_number"] == ""
        assert response.json()["item"]["tags"] == []

@pytest.mark.parametrize("field,value", [("brand", "x"*101), ("part_number", "x"*101), ("subcategory", "x"*101), ("tags", ["x"]*21), ("tags", ["x"*51])])
def test_metadata_is_bounded_before_any_write(client, field, value):
    with patch.object(items, "update_item") as update:
        response = client.patch("/update_item", json={"item_id": ITEM_ID, field: value})
    assert response.status_code == 422
    update.assert_not_called()

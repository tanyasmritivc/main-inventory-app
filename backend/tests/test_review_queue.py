from types import SimpleNamespace
from unittest.mock import MagicMock, call, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes.review import router
from app.core.auth import AuthenticatedUser, get_current_user
from app.services.review_queue import (
    enqueue_uncertain_items,
    resolve_review_item,
    update_review_item,
)


REVIEW_ID = "10000000-0000-0000-0000-000000000001"


def _review_record(**overrides) -> dict:
    record = {
        "review_id": REVIEW_ID,
        "user_id": "user-1",
        "source_key": "photo:private-digest:0",
        "source_kind": "photo_scan",
        "status": "pending",
        "name": "Bolt",
        "category": "Hardware",
        "quantity": 1,
        "scan_evidence": {"needs_review": True},
        "created_at": "2026-09-29T12:00:00Z",
        "updated_at": "2026-09-29T12:00:00Z",
    }
    record.update(overrides)
    return record


def _uncertain_item() -> dict:
    return {
        "name": "Unidentified item",
        "category": "Other",
        "quantity": 1,
        "confidence": 0.2,
        "image_url": "https://images.test/crop.jpg",
        "source_frame_url": "https://images.test/source.jpg",
        "scan_evidence": {
            "needs_review": True,
            "review_reasons": ["The item could not be identified reliably."],
        },
    }


def test_enqueue_uncertain_items_is_durable_and_idempotent():
    query = MagicMock()
    for method in ("select", "eq", "in_", "upsert"):
        getattr(query, method).return_value = query
    query.execute.side_effect = [
        SimpleNamespace(data=[]),
        SimpleNamespace(
            data=[
                {
                    "review_id": "10000000-0000-0000-0000-000000000001",
                    "source_key": "photo:digest:0",
                    "status": "pending",
                }
            ]
        ),
        SimpleNamespace(
            data=[
                {
                    "review_id": "10000000-0000-0000-0000-000000000001",
                    "source_key": "photo:digest:0",
                    "status": "pending",
                }
            ]
        ),
    ]
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.services.review_queue.get_supabase_admin", return_value=client
    ):
        items = enqueue_uncertain_items(
            user_id="user-1", source_digest="digest", items=[_uncertain_item()]
        )

    assert items[0]["review_id"] == "10000000-0000-0000-0000-000000000001"
    assert items[0]["review_status"] == "pending"
    payload = query.upsert.call_args.args[0][0]
    assert payload["user_id"] == "user-1"
    assert payload["image_url"] == "https://images.test/crop.jpg"
    assert payload["scan_evidence"]["needs_review"] is True
    query.upsert.assert_called_once_with(
        [payload], on_conflict="user_id,source_key", ignore_duplicates=True
    )


def test_confident_items_are_not_added_to_review_queue():
    item = _uncertain_item()
    item["scan_evidence"]["needs_review"] = False
    with patch("app.services.review_queue.get_supabase_admin") as client:
        result = enqueue_uncertain_items(
            user_id="user-1", source_digest="digest", items=[item]
        )
    assert result == [item]
    client.assert_not_called()


def test_review_update_always_scopes_owner_and_pending_status():
    query = MagicMock()
    for method in ("update", "eq"):
        getattr(query, method).return_value = query
    query.execute.return_value = SimpleNamespace(
        data=[{"review_id": "review-1", "user_id": "user-1", "name": "Bolt"}]
    )
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.services.review_queue.get_supabase_admin", return_value=client
    ):
        result = update_review_item(
            user_id="user-1",
            review_id="review-1",
            updates={"name": "Bolt", "status": "resolved"},
        )

    assert result["name"] == "Bolt"
    assert "status" not in query.update.call_args.args[0]
    assert query.eq.call_args_list == [
        call("review_id", "review-1"),
        call("user_id", "user-1"),
        call("status", "pending"),
    ]


def test_resolution_passes_identity_to_transactional_database_function():
    rpc = MagicMock()
    rpc.execute.return_value = SimpleNamespace(
        data={
            "item_id": "item-1",
            "user_id": "user-1",
            "name": "Bolt",
            "location": "Garage",
        }
    )
    client = MagicMock()
    client.rpc.return_value = rpc

    with patch(
        "app.services.review_queue.get_supabase_admin", return_value=client
    ), patch(
        "app.services.review_queue.get_or_create_space",
        return_value={"id": "space-1"},
    ), patch(
        "app.services.review_queue.verified_catalog_id_for_identity",
        return_value=None,
    ), patch("app.services.review_queue.invalidate_inventory_cache") as invalidate:
        result = resolve_review_item(
            user_id="user-1",
            review_id="review-1",
            item={
                "name": "Bolt",
                "category": "Hardware",
                "quantity": 2,
                "location": "garage",
            },
        )

    assert result["item_id"] == "item-1"
    arguments = client.rpc.call_args.args
    assert arguments[0] == "resolve_capture_review"
    assert arguments[1]["p_user_id"] == "user-1"
    assert arguments[1]["p_review_id"] == "review-1"
    assert arguments[1]["p_space_id"] == "space-1"
    assert arguments[1]["p_item"]["location"] == "Garage"
    invalidate.assert_called_once_with("user-1")


def _client() -> TestClient:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        user_id="user-1"
    )
    return TestClient(app)


def test_review_route_uses_authenticated_user_and_allows_confidence_edits():
    with patch(
        "app.api.routes.review.update_review_item",
        return_value=_review_record(confidence=0.4),
    ) as update:
        response = _client().patch(
            f"/review-items/{REVIEW_ID}",
            json={"name": "Bolt", "confidence": 0.4},
        )

    assert response.status_code == 200
    update.assert_called_once_with(
        user_id="user-1",
        review_id=REVIEW_ID,
        updates={"name": "Bolt", "confidence": 0.4},
    )


def test_review_route_rejects_unknown_fields_and_malformed_ids():
    with patch("app.api.routes.review.update_review_item") as update:
        unknown = _client().patch(
            f"/review-items/{REVIEW_ID}",
            json={"name": "Bolt", "status": "resolved"},
        )
        malformed = _client().patch(
            "/review-items/not-a-uuid", json={"name": "Bolt"}
        )

    assert unknown.status_code == 422
    assert malformed.status_code == 422
    update.assert_not_called()


def test_review_list_never_exposes_owner_or_deduplication_key():
    with patch(
        "app.api.routes.review.list_review_items",
        return_value=([_review_record()], 1),
    ):
        response = _client().get("/review-items")

    assert response.status_code == 200
    item = response.json()["items"][0]
    assert item["review_id"] == REVIEW_ID
    assert "user_id" not in item
    assert "source_key" not in item


def test_review_resolution_validates_required_location_before_service_call():
    response = _client().post(
        f"/review-items/{REVIEW_ID}/resolve",
        json={"name": "Bolt", "category": "Hardware", "quantity": 1},
    )
    assert response.status_code == 422

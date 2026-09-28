from app.schemas.documents import RecentActivityResponse


def test_recent_activity_preserves_fields_needed_for_filters():
    response = RecentActivityResponse.model_validate({
        "activities": [{
            "activity_id": "event-1",
            "summary": "Object corrected",
            "created_at": "2026-09-27T12:00:00Z",
            "user_id": "member-1",
            "event_type": "correction",
            "metadata": {"type": "correction", "item_id": "object-1"},
        }],
    })

    entry = response.model_dump()["activities"][0]
    assert entry["user_id"] == "member-1"
    assert entry["event_type"] == "correction"
    assert entry["metadata"]["item_id"] == "object-1"

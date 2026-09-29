from types import SimpleNamespace

from app.services import item_detail_repo, item_events_repo, item_relationships_repo


ITEM_ID = "11111111-1111-4111-8111-111111111111"
OTHER_ID = "22222222-2222-4222-8222-222222222222"
WORKSPACE_ID = "33333333-3333-4333-8333-333333333333"
SPACE_ID = "44444444-4444-4444-8444-444444444444"
ACTOR_ID = "55555555-5555-4555-8555-555555555555"


class Query:
    def __init__(self, data):
        self.data = data

    def __getattr__(self, name):
        return lambda *args, **kwargs: self

    def execute(self):
        return SimpleNamespace(data=self.data)


class Client:
    def __init__(self, tables):
        self.tables = tables

    def table(self, name):
        return Query(self.tables[name])


def test_item_with_only_workspace_and_space_keeps_complete_breadcrumb(monkeypatch):
    monkeypatch.setattr(
        item_detail_repo,
        "authorized_item",
        lambda **kwargs: {
            "item_id": ITEM_ID,
            "workspace_id": WORKSPACE_ID,
            "space_id": SPACE_ID,
            "location": "Workshop",
            "bin_id": None,
            "container": None,
        },
    )
    monkeypatch.setattr(
        item_detail_repo,
        "get_supabase_admin",
        lambda: Client({"teams": [{"name": "Shared workshop"}], "spaces": [{"name": "Workshop"}]}),
    )
    item = item_detail_repo.get_item_detail(user_id=ACTOR_ID, item_id=ITEM_ID)
    path = [
        item.get("workspace_name"), item.get("space_name"),
        item.get("bin_name"), item.get("container"),
    ]
    assert [part for part in path if part] == ["Shared workshop", "Workshop"]


def test_history_includes_count_cause_time_and_actor(monkeypatch):
    event = {
        "item_id": ITEM_ID,
        "user_id": ACTOR_ID,
        "event_type": "restock",
        "quantity_before": 4,
        "quantity_after": 7,
        "cause": "barcode",
        "created_at": "2026-09-27T12:00:00Z",
    }
    client = Client({
        "items": {"item_id": ITEM_ID, "user_id": ACTOR_ID, "workspace_id": None},
        "item_events": [event],
        "profiles": [{"id": ACTOR_ID, "display_name": "Alex"}],
    })
    monkeypatch.setattr(item_events_repo, "get_supabase_admin", lambda: client)
    history = item_events_repo.get_item_history(
        requesting_user_id=ACTOR_ID, item_id=ITEM_ID,
    )
    assert history == [{**event, "actor_display_name": "Alex"}]


def test_relationship_list_marks_both_directions(monkeypatch):
    rows = [
        {"id": "a", "from_item": ITEM_ID, "to_item": OTHER_ID, "kind": "fits"},
        {"id": "b", "from_item": OTHER_ID, "to_item": ITEM_ID, "kind": "replaces"},
    ]
    client = Client({
        "item_relationships": rows,
        "items": [{"item_id": OTHER_ID, "name": "Other object"}],
    })
    monkeypatch.setattr(
        item_relationships_repo, "authorized_item",
        lambda **kwargs: {"item_id": ITEM_ID},
    )
    monkeypatch.setattr(item_relationships_repo, "get_supabase_admin", lambda: client)
    result = item_relationships_repo.list_relationships(user_id=ACTOR_ID, item_id=ITEM_ID)
    assert [row["direction"] for row in result] == ["outbound", "inbound"]
    assert all(row["other_item"]["name"] == "Other object" for row in result)

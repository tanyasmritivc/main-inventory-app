"""Space mutations must not leave cached inventory locations or deleted rows.

Exercise the real repository/cache with a deep-copying, user-scoped database
stub. No production database or external service is used.
"""

from copy import deepcopy
from types import SimpleNamespace

import pytest

from app.services import items_repo, spaces_repo


class Database:
    def __init__(self):
        self.rows = {
            "spaces": [
                {"id": "workshop-a", "user_id": "cache-owner-a", "name": "Test Workshop"},
                {"id": "empty-a", "user_id": "cache-owner-a", "name": "Empty Test"},
                {"id": "workshop-b", "user_id": "cache-owner-b", "name": "Other Workshop"},
            ],
            "items": [
                {"item_id": f"sample-{index}", "user_id": "cache-owner-a",
                 "space_id": "workshop-a", "location": "Test Workshop",
                 "category": "Hardware" if index < 3 else "Electronics"}
                for index in range(5)
            ] + [{"item_id": "foreign", "user_id": "cache-owner-b",
                  "space_id": "workshop-b", "location": "Other Workshop"}],
        }
        self.item_reads = 0
        self.fail_item_update = False
        self.fail_space_delete = False

    def table(self, name):
        return Query(self, name)


class Query:
    def __init__(self, database, table):
        self.database = database
        self.table_name = table
        self.filters = []
        self.operation = "select"
        self.updates = {}

    def select(self, _columns):
        return self

    def order(self, _column, **_kwargs):
        return self

    def eq(self, column, value):
        self.filters.append((column, value))
        return self

    def update(self, updates):
        self.operation = "update"
        self.updates = updates
        return self

    def delete(self):
        self.operation = "delete"
        return self

    def execute(self):
        rows = self.database.rows[self.table_name]
        matched = [row for row in rows if all(row.get(key) == value for key, value in self.filters)]
        if self.operation == "select" and self.table_name == "items":
            self.database.item_reads += 1
        if self.operation == "update":
            if self.table_name == "items" and self.database.fail_item_update:
                raise RuntimeError("stubbed update failure")
            for row in matched:
                row.update(self.updates)
        elif self.operation == "delete":
            if self.database.fail_space_delete:
                raise RuntimeError("stubbed delete failure")
            self.database.rows[self.table_name] = [row for row in rows if row not in matched]
            if self.table_name == "spaces":
                deleted_ids = {row["id"] for row in matched}
                self.database.rows["items"] = [
                    row for row in self.database.rows["items"] if row["space_id"] not in deleted_ids
                ]
        return SimpleNamespace(data=deepcopy(matched))


@pytest.fixture
def database(monkeypatch):
    database = Database()
    monkeypatch.setattr(items_repo, "get_supabase_admin", lambda: database)
    monkeypatch.setattr(spaces_repo, "get_supabase_admin", lambda: database)
    monkeypatch.setattr(spaces_repo.time, "sleep", lambda _seconds: None)
    for user in ("cache-owner-a", "cache-owner-b"):
        items_repo.invalidate_inventory_cache(user)
    yield database
    for user in ("cache-owner-a", "cache-owner-b"):
        items_repo.invalidate_inventory_cache(user)


def test_rename_refreshes_all_categories_without_evicting_other_users(database):
    before = items_repo.list_items(user_id="cache-owner-a")
    unrelated = items_repo.list_items(user_id="cache-owner-b")
    assert len(before) == 5
    assert {item["category"] for item in before} == {"Hardware", "Electronics"}
    assert items_repo.list_items(user_id="cache-owner-a") == before
    assert database.item_reads == 2

    renamed = spaces_repo.rename_space(
        user_id="cache-owner-a", space_id="workshop-a", new_name="Main Workshop"
    )
    after = items_repo.search_items_basic(user_id="cache-owner-a", q="")
    assert renamed["name"] == "Main Workshop"
    assert len(after) == 5
    assert {item["location"] for item in after} == {"Main Workshop"}
    assert {item["category"] for item in after} == {"Hardware", "Electronics"}
    assert database.item_reads == 3
    assert items_repo.list_items(user_id="cache-owner-b") == unrelated
    assert database.item_reads == 3
    assert database.rows["spaces"][1]["name"] == "Empty Test"


def test_delete_cascade_clears_cached_items(database):
    assert len(items_repo.list_items(user_id="cache-owner-a")) == 5
    assert spaces_repo.delete_space(user_id="cache-owner-a", space_id="workshop-a")
    assert items_repo.search_items_basic(user_id="cache-owner-a", q="") == []
    assert len(items_repo.list_items(user_id="cache-owner-b")) == 1
    assert any(space["id"] == "empty-a" for space in database.rows["spaces"])


def test_foreign_space_rename_and_delete_do_not_modify_its_owner(database):
    foreign_before = deepcopy(database.rows)
    assert spaces_repo.rename_space(
        user_id="cache-owner-a", space_id="workshop-b", new_name="Unauthorized"
    ) == {}
    assert not spaces_repo.delete_space(user_id="cache-owner-a", space_id="workshop-b")
    assert database.rows == foreign_before


def test_failed_location_sync_raises_and_evicts_affected_snapshot(database):
    items_repo.list_items(user_id="cache-owner-a")
    database.fail_item_update = True
    with pytest.raises(RuntimeError, match="stubbed update failure"):
        spaces_repo.rename_space(
            user_id="cache-owner-a", space_id="workshop-a", new_name="Main Workshop"
        )
    assert items_repo._get_cached_inventory("cache-owner-a") is None


def test_failed_delete_raises_without_false_success_or_cached_snapshot(database):
    items_repo.list_items(user_id="cache-owner-a")
    database.fail_space_delete = True
    with pytest.raises(RuntimeError, match="stubbed delete failure"):
        spaces_repo.delete_space(user_id="cache-owner-a", space_id="workshop-a")
    assert len(database.rows["items"]) == 6
    assert items_repo._get_cached_inventory("cache-owner-a") is None


def test_blank_rename_has_no_database_side_effect(database):
    before = deepcopy(database.rows)
    with pytest.raises(ValueError, match="New name is required"):
        spaces_repo.rename_space(user_id="cache-owner-a", space_id="workshop-a", new_name="   ")
    assert database.rows == before

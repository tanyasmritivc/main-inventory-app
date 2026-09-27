from uuid import UUID

from app.services.supabase_client import get_supabase_admin


KINDS = {"used_with", "fits", "needed_by", "replaces"}


def _uuid(value: str) -> str:
    try:
        return str(UUID(value))
    except (TypeError, ValueError) as exc:
        raise ValueError("Choose a valid object.") from exc


def authorized_item(*, user_id: str, item_id: str, write: bool = False) -> dict:
    client = get_supabase_admin()
    item = (
        client.table("items").select("*")
        .eq("item_id", _uuid(item_id)).maybe_single().execute().data
    )
    if not item:
        raise LookupError("Object not found")
    if item["user_id"] == user_id:
        return item
    workspace_id = item.get("workspace_id")
    if workspace_id:
        members = (
            client.table("team_memberships").select("role")
            .eq("team_id", workspace_id).eq("user_id", user_id)
            .limit(1).execute().data or []
        )
        if members and (not write or members[0]["role"] != "viewer"):
            return item
    raise LookupError("Object not found")


def list_relationships(*, user_id: str, item_id: str) -> list[dict]:
    item = authorized_item(user_id=user_id, item_id=item_id)
    client = get_supabase_admin()
    rows = (
        client.table("item_relationships").select("*")
        .or_(f"from_item.eq.{item['item_id']},to_item.eq.{item['item_id']}")
        .order("created_at", desc=True).execute().data or []
    )
    other_ids = [
        row["to_item"] if row["from_item"] == item["item_id"] else row["from_item"]
        for row in rows if row.get("to_item")
    ]
    other_items = (
        client.table("items").select("item_id,name,quantity,location,space_id,bin_id,container")
        .in_("item_id", other_ids).execute().data or []
        if other_ids else []
    )
    kits_ids = [row["project_kit_id"] for row in rows if row.get("project_kit_id")]
    kits = (
        client.table("project_kits").select("id,name,location")
        .in_("id", kits_ids).execute().data or []
        if kits_ids else []
    )
    item_by_id = {row["item_id"]: row for row in other_items}
    kit_by_id = {row["id"]: row for row in kits}
    return [
        {
            **row,
            "direction": "outbound" if row["from_item"] == item["item_id"] else "inbound",
            "other_item": item_by_id.get(
                row["to_item"] if row["from_item"] == item["item_id"] else row["from_item"]
            ) if row.get("to_item") else None,
            "project_kit": kit_by_id.get(row.get("project_kit_id")),
        }
        for row in rows
    ]


def create_relationship(
    *, user_id: str, item_id: str, kind: str,
    to_item: str | None = None, project_kit_id: str | None = None,
) -> dict:
    if kind not in KINDS:
        raise ValueError("Choose a valid relationship.")
    if (kind == "needed_by") != bool(project_kit_id):
        raise ValueError("Choose a project for this relationship.")
    if kind != "needed_by" and not to_item:
        raise ValueError("Choose another object.")
    item = authorized_item(user_id=user_id, item_id=item_id, write=True)
    client = get_supabase_admin()
    target = None
    if to_item:
        target = authorized_item(user_id=user_id, item_id=to_item)
        if target["item_id"] == item["item_id"]:
            raise ValueError("An object cannot connect to itself.")
        if target.get("workspace_id") != item.get("workspace_id"):
            raise ValueError("Both objects must be in the same workspace.")
        if not item.get("workspace_id") and target["user_id"] != item["user_id"]:
            raise ValueError("Both objects must be in the same workspace.")
    if project_kit_id:
        kit = (
            client.table("project_kits").select("id,owner_user_id,location")
            .eq("id", _uuid(project_kit_id)).maybe_single().execute().data
        )
        if not kit or kit["owner_user_id"] != item["user_id"]:
            raise LookupError("Project not found")
    query = client.table("item_relationships").select("*").eq("from_item", item["item_id"])
    if project_kit_id:
        query = query.eq("project_kit_id", project_kit_id)
    else:
        query = query.eq("to_item", target["item_id"]).eq("kind", kind)
    existing = query.limit(1).execute().data or []
    if existing:
        return existing[0]
    payload = {
        "workspace_id": item.get("workspace_id"),
        "from_item": item["item_id"],
        "to_item": target["item_id"] if target else None,
        "project_kit_id": project_kit_id,
        "kind": kind,
        "created_by": user_id,
    }
    inserted = client.table("item_relationships").insert(payload).execute().data or []
    if not inserted:
        raise RuntimeError("The relationship could not be saved.")
    return inserted[0]


def delete_relationship(*, user_id: str, item_id: str, relationship_id: str) -> None:
    item = authorized_item(user_id=user_id, item_id=item_id, write=True)
    client = get_supabase_admin()
    row = (
        client.table("item_relationships").select("id,from_item,to_item")
        .eq("id", _uuid(relationship_id)).maybe_single().execute().data
    )
    if not row or item["item_id"] not in {row["from_item"], row.get("to_item")}:
        raise LookupError("Relationship not found")
    authorized_item(user_id=user_id, item_id=row["from_item"], write=True)
    client.table("item_relationships").delete().eq("id", relationship_id).execute()


def seed_capture_relationships(*, user_id: str, items: list[dict]) -> None:
    from app.services.catalog_service import get_compatible_catalog_parts

    catalog_items = {
        str(item["catalog_id"]): item
        for item in items if item.get("catalog_id") and item.get("item_id")
    }
    for catalog_id, item in catalog_items.items():
        compatible = get_compatible_catalog_parts(catalog_id)
        matched_catalog_ids = {
            str(part["catalog_id"]) for part in compatible.get("matches", [])
        }
        for target_id in sorted(matched_catalog_ids & catalog_items.keys()):
            if item["item_id"] < catalog_items[target_id]["item_id"]:
                create_relationship(
                    user_id=user_id,
                    item_id=item["item_id"],
                    to_item=catalog_items[target_id]["item_id"],
                    kind="used_with",
                )


def seed_project_kit_relationships(
    *, actor_user_id: str, owner_user_id: str,
    project_kit_id: str, location: str, rows: list[dict],
) -> None:
    from app.services.items_repo import list_items

    client = get_supabase_admin()
    inventory = [
        item for item in list_items(user_id=owner_user_id)
        if (item.get("location") or "").strip().lower() == location.strip().lower()
    ]
    needed = {
        ((row.get("part_number") or "").strip().lower(),
         (row.get("name") or "").strip().lower())
        for row in rows
    }
    for item in inventory:
        part = (item.get("part_number") or "").strip().lower()
        name = (item.get("name") or "").strip().lower()
        if not any((expected_part and expected_part == part)
                   or (not expected_part and expected_name == name)
                   for expected_part, expected_name in needed):
            continue
        existing = (
            client.table("item_relationships").select("id")
            .eq("from_item", item["item_id"])
            .eq("project_kit_id", project_kit_id).limit(1).execute().data or []
        )
        if not existing:
            client.table("item_relationships").insert({
                "workspace_id": item.get("workspace_id"),
                "from_item": item["item_id"],
                "project_kit_id": project_kit_id,
                "kind": "needed_by",
                "created_by": actor_user_id,
            }).execute()

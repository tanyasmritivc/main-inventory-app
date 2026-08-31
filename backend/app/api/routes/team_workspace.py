import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.schemas.inventory import AddItemRequest, UpdateItemRequest
from app.services.items_repo import bulk_create_items, delete_item, update_item
from app.services.spaces_repo import get_or_create_space
from app.services.supabase_client import get_supabase_admin
from app.services.push_notifications import enqueue_team_activity

router = APIRouter(prefix="/teams/{team_id}", tags=["team-workspace"])
logger = logging.getLogger(__name__)


class CreateTeamSpace(BaseModel):
    name: str = Field(min_length=1, max_length=200)


class AttachTeamSpace(BaseModel):
    space_id: str = Field(max_length=36)


def _membership(team_id: str, user_id: str) -> dict:
    rows = get_supabase_admin().table("team_memberships").select(
        "member_id,role"
    ).eq("team_id", team_id).eq("user_id", user_id).limit(1).execute().data or []
    if not rows:
        raise HTTPException(403, "You are not a member of this team.")
    return rows[0]


def _editor(team_id: str, user_id: str) -> dict:
    membership = _membership(team_id, user_id)
    if membership["role"] == "viewer":
        raise HTTPException(403, "You have view-only access to this team.")
    return membership


def _manager(team_id: str, user_id: str) -> dict:
    membership = _membership(team_id, user_id)
    if membership["role"] not in ("owner", "mentor"):
        raise HTTPException(403, "Only the team owner or a manager can do that.")
    return membership


def _team(team_id: str) -> dict:
    rows = get_supabase_admin().table("teams").select(
        "team_id,name,owner_user_id,program,join_code"
    ).eq("team_id", team_id).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, "This team no longer exists.")
    return rows[0]


def _space_access(team_id: str, space_id: str, user_id: str, write: bool = False) -> tuple[dict, dict]:
    membership = _editor(team_id, user_id) if write else _membership(team_id, user_id)
    links = get_supabase_admin().table("team_spaces").select("team_space_id").eq(
        "team_id", team_id
    ).eq("space_id", space_id).limit(1).execute().data or []
    if not links:
        raise HTTPException(404, "This Space is not part of the team.")
    spaces = get_supabase_admin().table("spaces").select("id,user_id,name,created_at").eq(
        "id", space_id
    ).limit(1).execute().data or []
    if not spaces:
        raise HTTPException(404, "This Space no longer exists.")
    return spaces[0], membership


def _record(team_id: str, actor_id: str, action: str, summary: str, metadata: dict | None = None) -> None:
    get_supabase_admin().table("team_activity").insert({
        "team_id": team_id,
        "actor_id": actor_id,
        "action": action,
        "summary": summary,
        "metadata": metadata or {},
    }).execute()
    enqueue_team_activity(team_id, actor_id, summary, action)


@router.get("/workspace")
def get_workspace(team_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    membership = _membership(team_id, user.user_id)
    team = _team(team_id)
    return {"team": team, "role": membership["role"]}


@router.get("/spaces")
def list_team_spaces(team_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    membership = _membership(team_id, user.user_id)
    links = get_supabase_admin().table("team_spaces").select(
        "team_space_id,space_id,linked_by,created_at"
    ).eq("team_id", team_id).order("created_at").execute().data or []
    if not links:
        return {"spaces": [], "role": membership["role"]}
    space_ids = [row["space_id"] for row in links]
    spaces = get_supabase_admin().table("spaces").select(
        "id,user_id,name,created_at"
    ).in_("id", space_ids).execute().data or []
    items = get_supabase_admin().table("items").select("space_id").in_(
        "space_id", space_ids
    ).execute().data or []
    counts: dict[str, int] = {}
    for item in items:
        sid = item.get("space_id")
        if sid:
            counts[sid] = counts.get(sid, 0) + 1
    by_id = {row["id"]: row for row in spaces}
    result = []
    for link in links:
        space = by_id.get(link["space_id"])
        if space:
            result.append({
                **space,
                "team_space_id": link["team_space_id"],
                "linked_by": link["linked_by"],
                "item_count": counts.get(space["id"], 0),
                "owned_by_me": space["user_id"] == user.user_id,
            })
    return {"spaces": result, "role": membership["role"]}


@router.post("/spaces")
def create_team_space(
    team_id: str,
    body: CreateTeamSpace,
    user: AuthenticatedUser = Depends(get_current_user),
):
    _manager(team_id, user.user_id)
    team = _team(team_id)
    name = body.name.strip()
    if not name:
        raise HTTPException(422, "Enter a Space name.")
    space = get_or_create_space(user_id=team["owner_user_id"], name=name)
    existing = get_supabase_admin().table("team_spaces").select("team_id").eq(
        "space_id", space["id"]
    ).limit(1).execute().data or []
    if existing and existing[0]["team_id"] != team_id:
        raise HTTPException(409, "This Space already belongs to another team.")
    if not existing:
        get_supabase_admin().table("team_spaces").insert({
            "team_id": team_id, "space_id": space["id"], "linked_by": user.user_id
        }).execute()
        _record(team_id, user.user_id, "space_created", f"Created Team Space {name}", {"space_id": space["id"]})
    return {"space": space}


@router.post("/spaces/attach")
def attach_team_space(
    team_id: str,
    body: AttachTeamSpace,
    user: AuthenticatedUser = Depends(get_current_user),
):
    _editor(team_id, user.user_id)
    spaces = get_supabase_admin().table("spaces").select("id,user_id,name").eq(
        "id", body.space_id
    ).eq("user_id", user.user_id).limit(1).execute().data or []
    if not spaces:
        raise HTTPException(404, "Choose a Space that you own.")
    existing = get_supabase_admin().table("team_spaces").select("team_id").eq(
        "space_id", body.space_id
    ).limit(1).execute().data or []
    if existing:
        if existing[0]["team_id"] == team_id:
            return {"space": spaces[0]}
        raise HTTPException(409, "This Space already belongs to another team.")
    get_supabase_admin().table("team_spaces").insert({
        "team_id": team_id, "space_id": body.space_id, "linked_by": user.user_id
    }).execute()
    _record(team_id, user.user_id, "space_added", f"Added {spaces[0]['name']} to the team", {"space_id": body.space_id})
    return {"space": spaces[0]}


@router.delete("/spaces/{space_id}")
def detach_team_space(
    team_id: str,
    space_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    membership = _editor(team_id, user.user_id)
    space, _ = _space_access(team_id, space_id, user.user_id)
    if membership["role"] not in ("owner", "mentor") and space["user_id"] != user.user_id:
        raise HTTPException(403, "Only a manager or the Space owner can remove it.")
    deleted = get_supabase_admin().table("team_spaces").delete().eq(
        "team_id", team_id
    ).eq("space_id", space_id).execute().data or []
    if deleted:
        _record(team_id, user.user_id, "space_removed", f"Removed {space['name']} from the team", {"space_id": space_id})
    return {"removed": True, "space_deleted": False}


@router.get("/spaces/{space_id}/items")
def list_team_space_items(
    team_id: str,
    space_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    space, membership = _space_access(team_id, space_id, user.user_id)
    items = get_supabase_admin().table("items").select("*").eq(
        "user_id", space["user_id"]
    ).eq("space_id", space_id).order("created_at", desc=True).execute().data or []
    return {"space": space, "items": items, "role": membership["role"]}


@router.post("/spaces/{space_id}/items")
def add_team_space_item(
    team_id: str,
    space_id: str,
    body: AddItemRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    space, _ = _space_access(team_id, space_id, user.user_id, write=True)
    payload = body.model_dump()
    payload["location"] = space["name"]
    payload["space_id"] = space_id
    inserted, failures = bulk_create_items(user_id=space["user_id"], items=[payload])
    if failures or not inserted:
        raise HTTPException(500, "The item could not be added.")
    item = inserted[0]
    _record(team_id, user.user_id, "item_added", f"Added {item['name']} to {space['name']}", {"space_id": space_id, "item_id": item["item_id"]})
    return {"item": item}


@router.patch("/spaces/{space_id}/items/{item_id}")
def update_team_space_item(
    team_id: str,
    space_id: str,
    item_id: str,
    body: UpdateItemRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    space, _ = _space_access(team_id, space_id, user.user_id, write=True)
    if body.item_id != item_id:
        raise HTTPException(422, "The item identifier does not match.")
    exists = get_supabase_admin().table("items").select("item_id,name").eq(
        "item_id", item_id
    ).eq("user_id", space["user_id"]).eq("space_id", space_id).limit(1).execute().data or []
    if not exists:
        raise HTTPException(404, "This item is not in the Team Space.")
    updates = body.model_dump(exclude_none=True, exclude={"item_id", "location"})
    item = update_item(user_id=space["user_id"], item_id=item_id, updates=updates)
    if not item:
        raise HTTPException(500, "The item could not be updated.")
    _record(team_id, user.user_id, "item_updated", f"Updated {item['name']} in {space['name']}", {"space_id": space_id, "item_id": item_id})
    return {"item": item}


@router.delete("/spaces/{space_id}/items/{item_id}")
def delete_team_space_item(
    team_id: str,
    space_id: str,
    item_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    space, _ = _space_access(team_id, space_id, user.user_id, write=True)
    rows = get_supabase_admin().table("items").select("item_id,name").eq(
        "item_id", item_id
    ).eq("user_id", space["user_id"]).eq("space_id", space_id).limit(1).execute().data or []
    if not rows:
        return {"deleted": True}
    if not delete_item(user_id=space["user_id"], item_id=item_id):
        raise HTTPException(500, "The item could not be deleted.")
    _record(team_id, user.user_id, "item_deleted", f"Deleted {rows[0]['name']} from {space['name']}", {"space_id": space_id, "item_id": item_id})
    return {"deleted": True}


@router.get("/activity")
def list_team_activity(team_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    _membership(team_id, user.user_id)
    activity = get_supabase_admin().table("team_activity").select("*").eq(
        "team_id", team_id
    ).order("created_at", desc=True).limit(100).execute().data or []
    return {"activity": activity}

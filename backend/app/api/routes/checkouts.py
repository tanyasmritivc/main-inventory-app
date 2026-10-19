
import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


class CheckoutItemRequest(BaseModel):
    item_id: str = Field(max_length=36)
    checked_out_by: str = Field(default="", max_length=200)
    quantity: int | None = Field(default=None, ge=1, le=10000)
    checkout_quantity: int | None = Field(default=None, ge=1, le=10000)
    due_back_at: str | None = Field(default=None, max_length=50)
    notes: str | None = Field(default=None, max_length=2000)


class ReturnItemRequest(BaseModel):
    checkout_id: str = Field(max_length=36)


@router.post("/checkouts/ping")
async def checkout_ping():
    return {"ok": True}


def _owned_items(user_id: str) -> list[dict]:
    client = get_supabase_admin()
    rows = []
    while True:
        page = client.table("items").select("item_id,user_id,inventory_id,space_id,location").eq(
            "user_id", user_id
        ).order("item_id").range(len(rows), len(rows) + 499).execute().data or []
        rows.extend(page)
        if len(page) < 500:
            return rows


def _visible_items(user_id: str, *, write: bool = False) -> dict[str, dict]:
    from app.services.inventory_scope import current_inventory
    from app.services import sharing_service
    scope = current_inventory.get()
    if write and scope and not scope.can_edit:
        raise HTTPException(403, "You have view-only access to this inventory.")
    items = {row["item_id"]: row for row in _owned_items(user_id)}
    for membership in sharing_service.get_joined_shares(user_id=user_id):
        share = membership.get("team_shares") or {}
        if isinstance(share, list):
            share = share[0] if share else {}
        share_id = share.get("share_id") or membership.get("share_id")
        if not share_id or not sharing_service.invitation_is_current(share):
            continue
        try:
            _, can_edit = sharing_service.get_share_access(requesting_user_id=user_id, share_id=share_id)
            if write and not can_edit:
                continue
            for row in sharing_service.get_share_inventory(requesting_user_id=user_id, share_id=share_id):
                items[row["item_id"]] = row
        except ValueError:
            # A removed/revoked membership is no longer an authorization grant.
            continue
    return items


def _checkout_rows(item_ids, *, active=None, returned_after=None):
    client = get_supabase_admin()
    ids = list(dict.fromkeys(item_ids))
    rows = []
    for offset in range(0, len(ids), 200):
        page_offset = 0
        while True:
            query = client.table("checkouts").select("*, items(name, location, category)").in_("item_id", ids[offset:offset + 200])
            if active is not None:
                query = query.eq("is_active", active)
            if returned_after:
                query = query.gte("returned_at", returned_after)
            page = query.order("checked_out_at", desc=True).order("checkout_id").range(page_offset, page_offset + 499).execute().data or []
            rows.extend(page)
            if len(page) < 500:
                break
            page_offset += 500
    return sorted(rows, key=lambda row: row.get("checked_out_at") or "", reverse=True)


@router.post("/checkouts/checkout")
async def checkout_item(body: CheckoutItemRequest, user: AuthenticatedUser = Depends(get_current_user)):
    item = _visible_items(user.user_id, write=True).get(body.item_id)
    if item is None:
        raise HTTPException(404, "Item not found or you cannot check it out.")
    result = get_supabase_admin().table("checkouts").insert({
        "user_id": user.user_id, "item_id": body.item_id,
        "checked_out_by": body.checked_out_by,
        "quantity": body.quantity or body.checkout_quantity or 1,
        "space_name": item.get("location", ""), "due_back_at": body.due_back_at,
        "notes": body.notes, "is_active": True, "returned_at": None,
    }).execute()
    if not result.data:
        raise HTTPException(503, "Checkout could not be confirmed. Refresh before retrying.")
    return result.data[0]


@router.post("/checkouts/return")
async def return_item(body: ReturnItemRequest, user: AuthenticatedUser = Depends(get_current_user)):
    from datetime import datetime, timezone
    from app.services.inventory_scope import current_inventory
    client = get_supabase_admin()
    rows = client.table("checkouts").select("checkout_id,user_id,item_id,inventory_id").eq("checkout_id", body.checkout_id).execute().data or []
    if not rows:
        raise HTTPException(404, "Checkout not found")
    checkout = rows[0]
    scope = current_inventory.get()
    can_return = scope.can_edit if scope else user.user_id == checkout.get("user_id")
    if not can_return:
        can_return = checkout.get("item_id") in _visible_items(user.user_id, write=True)
    if not can_return:
        raise HTTPException(403, "Not authorized to return this checkout")
    result = client.table("checkouts").update({
        "returned_at": datetime.now(timezone.utc).isoformat(), "is_active": False,
    }).eq("checkout_id", body.checkout_id).execute()
    if not result.data:
        raise HTTPException(409, "The checkout changed. Refresh before retrying.")
    return {"returned": True}


@router.get("/checkouts/active")
async def get_active_checkouts(user: AuthenticatedUser = Depends(get_current_user)):
    rows = _checkout_rows(_visible_items(user.user_id), active=True)
    return {"checkouts": [{**row, **({"from_teammate": True} if row.get("user_id") != user.user_id else {})} for row in rows]}


@router.get("/checkouts/space")
async def get_space_checkouts(share_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    from datetime import datetime, timezone, timedelta
    from app.services import sharing_service
    try:
        items = sharing_service.get_share_inventory(requesting_user_id=user.user_id, share_id=share_id)
    except ValueError:
        raise HTTPException(403, "This shared Space is no longer available.") from None
    item_ids = [item["item_id"] for item in items]
    return {
        "active": _checkout_rows(item_ids, active=True),
        "returned": _checkout_rows(item_ids, active=False,
            returned_after=(datetime.now(timezone.utc) - timedelta(days=30)).isoformat()),
    }


@router.get("/checkouts/item/{item_id}")
async def get_item_checkouts(item_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    if item_id not in _visible_items(user.user_id):
        raise HTTPException(404, "Item not found")
    return {"checkouts": _checkout_rows([item_id])[:10]}

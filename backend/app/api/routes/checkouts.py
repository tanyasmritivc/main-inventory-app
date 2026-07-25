from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


@router.post("/checkouts/ping")
async def checkout_ping():
    return {"ok": True}


@router.post("/checkouts/checkout")
async def checkout_item(
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    body = await request.json()

    item_id = body.get("item_id")
    checked_out_by = body.get("checked_out_by", "")
    quantity = int(body.get("quantity") or body.get("checkout_quantity") or 1)
    due_back_at = body.get("due_back_at")
    notes = body.get("notes")

    if not item_id:
        raise HTTPException(status_code=422, detail="item_id required")

    # Step 1: try own items first
    own = client.table("items").select("item_id, location").eq(
        "item_id", item_id
    ).eq("user_id", user.user_id).execute()
    item_data = own.data[0] if own.data else None

    # Step 2: if not found, check joined spaces — item may belong to the space owner
    if not item_data:
        memberships = client.table("team_members").select("share_id").eq(
            "member_user_id", user.user_id
        ).execute()
        share_ids = [m["share_id"] for m in (memberships.data or [])]

        if share_ids:
            shares = client.table("team_shares").select("owner_user_id").in_(
                "share_id", share_ids
            ).execute()
            owner_ids = [s["owner_user_id"] for s in (shares.data or [])]

            if owner_ids:
                shared = client.table("items").select("item_id, location").eq(
                    "item_id", item_id
                ).in_("user_id", owner_ids).execute()
                item_data = shared.data[0] if shared.data else None

    if not item_data:
        raise HTTPException(status_code=404, detail="Item not found")

    checkout = client.table("checkouts").insert({
        "user_id": user.user_id,
        "item_id": item_id,
        "checked_out_by": checked_out_by,
        "quantity": quantity,
        "space_name": item_data.get("location", ""),
        "due_back_at": due_back_at,
        "notes": notes,
        "is_active": True,
        "returned_at": None,
    }).execute()

    return checkout.data[0] if checkout.data else {"ok": True}


@router.post("/checkouts/return")
async def return_item(
    body: dict,
    user: AuthenticatedUser = Depends(get_current_user),
):
    from datetime import datetime, timezone
    client = get_supabase_admin()
    checkout_id = body.get("checkout_id")
    if not checkout_id:
        raise HTTPException(400, "checkout_id required")

    # Fetch the checkout row first (no user_id filter — we check auth below)
    checkout_row = client.table("checkouts").select(
        "checkout_id, user_id, space_name"
    ).eq("checkout_id", checkout_id).execute()

    if not checkout_row.data:
        raise HTTPException(404, "Checkout not found")

    checkout = checkout_row.data[0]

    # Allow: the user who created the checkout, OR any owner/member of the space
    can_return = user.user_id == checkout.get("user_id")

    if not can_return:
        space_name = (checkout.get("space_name") or "").strip()
        if space_name:
            share_rows = client.table("team_shares").select(
                "share_id, owner_user_id"
            ).eq("share_name", space_name).execute()
            for s in (share_rows.data or []):
                if user.user_id == s["owner_user_id"]:
                    can_return = True
                    break
                member_check = client.table("team_members").select(
                    "member_id"
                ).eq("share_id", s["share_id"]).eq(
                    "member_user_id", user.user_id
                ).execute()
                if member_check.data:
                    can_return = True
                    break

    if not can_return:
        raise HTTPException(403, "Not authorized to return this checkout")

    client.table("checkouts").update({
        "returned_at": datetime.now(timezone.utc).isoformat(),
        "is_active": False,
    }).eq("checkout_id", checkout_id).execute()

    return {"returned": True}


@router.get("/checkouts/active")
async def get_active_checkouts(
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()

    # Get spaces the user owns
    owned_spaces = set()
    my_items = client.table("items").select("location").eq("user_id", user.user_id).execute()
    for item in (my_items.data or []):
        loc = (item.get("location") or "Unsorted").strip()
        if loc:
            owned_spaces.add(loc)

    # Get spaces the user has joined (via team_members)
    shared_spaces = set()
    joined = client.table("team_members").select(
        "team_shares(owner_user_id, share_name)"
    ).eq("member_user_id", user.user_id).execute()

    shared_owner_ids = set()
    for m in (joined.data or []):
        ts = m.get("team_shares") or {}
        owner_id = ts.get("owner_user_id")
        space_name = ts.get("share_name", "").strip()
        if owner_id:
            shared_owner_ids.add(owner_id)
        if space_name:
            shared_spaces.add(space_name.lower())

    # Also get spaces I share with others (I'm the owner)
    my_shares = client.table("team_shares").select(
        "share_name, share_id"
    ).eq("owner_user_id", user.user_id).eq("is_active", True).execute()

    shared_space_names_i_own = set()
    for s in (my_shares.data or []):
        sn = (s.get("share_name") or "").strip().lower()
        if sn:
            shared_space_names_i_own.add(sn)

    # Fetch my own checkouts
    my_checkouts = client.table("checkouts").select(
        "*, items(name, location, category)"
    ).eq("user_id", user.user_id).eq("is_active", True).order(
        "checked_out_at", desc=True
    ).execute()

    result = list(my_checkouts.data or [])

    # Fetch checkouts from teammates — only for shared spaces
    if shared_owner_ids:
        teammate_checkouts = client.table("checkouts").select(
            "*, items(name, location, category)"
        ).in_("user_id", list(shared_owner_ids)).eq("is_active", True).order(
            "checked_out_at", desc=True
        ).execute()

        for checkout in (teammate_checkouts.data or []):
            # Only include if the item is from a shared space
            item_data = checkout.get("items") or {}
            item_location = (item_data.get("location") or "").strip().lower()
            checkout_space = (checkout.get("space_name") or item_location).lower()

            if checkout_space in shared_spaces or item_location in shared_spaces:
                checkout["from_teammate"] = True
                result.append(checkout)

    # Also fetch checkouts from my team members for spaces I own and share
    if shared_space_names_i_own:
        my_share_ids = [s["share_id"] for s in (my_shares.data or [])]
        if my_share_ids:
            member_ids_result = client.table("team_members").select(
                "member_user_id"
            ).in_("share_id", my_share_ids).execute()

            member_ids = [m["member_user_id"] for m in (member_ids_result.data or [])]

            if member_ids:
                member_checkouts = client.table("checkouts").select(
                    "*, items(name, location, category)"
                ).in_("user_id", member_ids).eq("is_active", True).order(
                    "checked_out_at", desc=True
                ).execute()

                for checkout in (member_checkouts.data or []):
                    item_data = checkout.get("items") or {}
                    item_location = (item_data.get("location") or "").strip().lower()
                    checkout_space = (checkout.get("space_name") or item_location).lower()

                    if checkout_space in shared_space_names_i_own or item_location in shared_space_names_i_own:
                        checkout["from_teammate"] = True
                        if checkout not in result:
                            result.append(checkout)

    return {"checkouts": result}


@router.get("/checkouts/space")
async def get_space_checkouts(
    share_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Return active + recently returned checkouts strictly scoped to one shared space."""
    from datetime import datetime, timezone, timedelta

    client = get_supabase_admin()

    if not share_id:
        raise HTTPException(400, "share_id required")

    # Verify the share exists and the requesting user is owner or member
    share_rows = client.table("team_shares").select(
        "share_id, share_name, owner_user_id"
    ).eq("share_id", share_id).execute()

    if not share_rows.data:
        raise HTTPException(404, "Space not found")

    share = share_rows.data[0]
    share_name = share["share_name"]

    is_owner = user.user_id == share["owner_user_id"]
    is_member = False
    if not is_owner:
        m = client.table("team_members").select("member_id").eq(
            "share_id", share_id
        ).eq("member_user_id", user.user_id).execute()
        is_member = bool(m.data)

    if not is_owner and not is_member:
        raise HTTPException(403, "Not authorized")

    thirty_days_ago = (
        datetime.now(timezone.utc) - timedelta(days=30)
    ).isoformat()

    # Active checkouts for this space only
    active_result = client.table("checkouts").select(
        "*, items(name, location, category)"
    ).eq("space_name", share_name).eq("is_active", True).order(
        "checked_out_at", desc=True
    ).execute()

    # Checkouts returned within the last 30 days for this space
    returned_result = client.table("checkouts").select(
        "*, items(name, location, category)"
    ).eq("space_name", share_name).eq("is_active", False).gte(
        "returned_at", thirty_days_ago
    ).order("returned_at", desc=True).execute()

    return {
        "active": active_result.data or [],
        "returned": returned_result.data or [],
    }


@router.get("/checkouts/item/{item_id}")
async def get_item_checkouts(
    item_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()

    visible_user_ids = {user.user_id}

    joined = client.table("team_members").select(
        "team_shares(owner_user_id)"
    ).eq("member_user_id", user.user_id).execute()

    for m in (joined.data or []):
        ts = m.get("team_shares") or {}
        owner_id = ts.get("owner_user_id")
        if owner_id:
            visible_user_ids.add(owner_id)

    owned = client.table("team_shares").select(
        "team_members(member_user_id)"
    ).eq("owner_user_id", user.user_id).eq("is_active", True).execute()

    for s in (owned.data or []):
        for m in (s.get("team_members") or []):
            member_id = m.get("member_user_id")
            if member_id:
                visible_user_ids.add(member_id)

    result = client.table("checkouts").select("*").eq(
        "item_id", item_id
    ).in_("user_id", list(visible_user_ids)).order(
        "checked_out_at", desc=True
    ).limit(10).execute()

    return {"checkouts": result.data or []}

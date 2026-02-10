from __future__ import annotations

import os

import stripe
from fastapi import APIRouter, Depends, Request
from fastapi import status
from fastapi.responses import JSONResponse

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import bad_request
from app.services.supabase_client import get_supabase_admin


router = APIRouter(prefix="/billing", tags=["billing"])


def _stripe() -> None:
    key = (os.getenv("STRIPE_SECRET_KEY") or "").strip()
    if not key:
        raise bad_request("Missing STRIPE_SECRET_KEY")
    stripe.api_key = key


@router.post("/create-checkout-session")
async def create_checkout_session(request: Request, payload: dict | None = None, user: AuthenticatedUser = Depends(get_current_user)):
    _stripe()

    body = payload or {}
    interval = (body.get("interval") or "monthly").strip().lower()
    if interval not in {"monthly", "yearly"}:
        raise bad_request("Invalid interval")

    price_id = (os.getenv("STRIPE_PRICE_MONTHLY") if interval == "monthly" else os.getenv("STRIPE_PRICE_YEARLY"))
    price_id = (price_id or "").strip()
    if not price_id:
        raise bad_request("Missing Stripe price id")

    origin = request.headers.get("origin") or ""
    origin = origin.strip().rstrip("/")
    if not origin:
        raise bad_request("Missing Origin header")

    success_url = f"{origin}/settings?checkout=success"
    cancel_url = f"{origin}/settings?checkout=cancel"

    session = stripe.checkout.Session.create(
        mode="subscription",
        client_reference_id=user.user_id,
        line_items=[{"price": price_id, "quantity": 1}],
        success_url=success_url,
        cancel_url=cancel_url,
    )

    return {"url": session.url}


@router.post("/stripe-webhook")
async def stripe_webhook(request: Request):
    webhook_secret = (os.getenv("STRIPE_WEBHOOK_SECRET") or "").strip()
    if not webhook_secret:
        return JSONResponse(status_code=status.HTTP_400_BAD_REQUEST, content={"ok": False})

    sig_header = request.headers.get("stripe-signature")
    if not sig_header:
        return JSONResponse(status_code=status.HTTP_400_BAD_REQUEST, content={"ok": False})

    payload = await request.body()

    try:
        event = stripe.Webhook.construct_event(payload=payload, sig_header=sig_header, secret=webhook_secret)
    except Exception:
        return JSONResponse(status_code=status.HTTP_400_BAD_REQUEST, content={"ok": False})

    if event.get("type") != "checkout.session.completed":
        return {"ok": True}

    session = (event.get("data") or {}).get("object") or {}
    user_id = (session.get("client_reference_id") or "").strip() or None

    if user_id:
        try:
            supabase = get_supabase_admin()
            supabase.table("profiles").update({"is_pro": True}).eq("id", user_id).execute()
        except Exception:
            pass

    return {"ok": True}

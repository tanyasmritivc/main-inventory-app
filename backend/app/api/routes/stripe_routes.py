import logging
import os
from datetime import datetime, timezone
from typing import Literal

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin, supabase_execute_with_retry

router = APIRouter()

logger = logging.getLogger(__name__)


class StripeCheckoutRequest(BaseModel):
    plan: Literal["monthly", "yearly"] = "monthly"


def get_stripe():
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY", "")
    return stripe


# POST /stripe/create-checkout-session
# Creates a Stripe Checkout session for monthly or yearly plan
@router.post("/stripe/create-checkout-session")
async def create_checkout_session(
    body: StripeCheckoutRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    get_stripe()
    plan = body.plan
    price_id = (
        os.environ.get("STRIPE_PRICE_MONTHLY")
        if plan == "monthly"
        else os.environ.get("STRIPE_PRICE_YEARLY")
    )
    if not price_id:
        raise HTTPException(400, "Price not configured")

    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            mode="subscription",
            line_items=[{"price": price_id, "quantity": 1}],
            success_url="https://www.findez.ai/upgrade-success?session_id={CHECKOUT_SESSION_ID}",
            cancel_url="https://www.findez.ai/upgrade",
            client_reference_id=user.user_id,
            customer_email=user.email if hasattr(user, "email") else None,
            metadata={"user_id": user.user_id, "plan": plan},
        )
        return {"url": session.url, "session_id": session.id}
    except Exception:
        logger.exception("Stripe checkout session creation failed")
        raise HTTPException(500, "Checkout unavailable. Please try again.")


# POST /stripe/webhook
# Handles Stripe webhook events
@router.post("/stripe/webhook")
async def stripe_webhook(request: Request):
    get_stripe()
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET", "")

    try:
        event = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
    except stripe.error.SignatureVerificationError:
        raise HTTPException(400, "Invalid signature")

    client = get_supabase_admin()

    def _plan_from_price(price_id: str) -> str | None:
        settings = get_settings()
        mapping: dict[str, str] = {}
        for env_key, plan_name in [
            (settings.stripe_price_pro_monthly, "pro_monthly"),
            (settings.stripe_price_monthly, "pro_monthly"),
            (settings.stripe_price_pro_annual, "pro_annual"),
            (settings.stripe_price_yearly, "pro_annual"),
            (settings.stripe_price_team_season, "team_season"),
        ]:
            if env_key:
                mapping[env_key] = plan_name
        return mapping.get(price_id)

    def _renews_at(sub: dict) -> str | None:
        period_end = sub.get("current_period_end")
        if period_end:
            return datetime.fromtimestamp(period_end, tz=timezone.utc).isoformat()
        return None

    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        user_id = session.get("client_reference_id") or session.get("metadata", {}).get("user_id")
        subscription_id = session.get("subscription")
        plan = (session.get("metadata") or {}).get("plan")
        if user_id:
            client.table("profiles").upsert({
                "id": user_id,
                "is_pro": True,
                "tier": "pro",
                "stripe_subscription_id": subscription_id,
                "stripe_customer_id": session.get("customer"),
                "subscription_plan": plan,
            }).execute()

    elif event["type"] in ("customer.subscription.updated", "customer.subscription.created"):
        sub = event["data"]["object"]
        customer_id = sub.get("customer")
        status = sub.get("status")
        is_pro = status in ("active", "trialing")
        # Resolve plan from first price in subscription
        plan: str | None = None
        try:
            items = (sub.get("items") or {}).get("data") or []
            if items:
                price_id = (items[0].get("price") or {}).get("id")
                if price_id:
                    plan = _plan_from_price(price_id)
        except Exception:
            pass
        result = client.table("profiles").select("id").eq("stripe_customer_id", customer_id).execute()
        if result.data:
            user_id = result.data[0]["id"]
            client.table("profiles").update({
                "is_pro": is_pro,
                "tier": "pro" if is_pro else "free",
                "stripe_subscription_id": sub.get("id"),
                "subscription_plan": plan if is_pro else None,
                "subscription_renews_at": _renews_at(sub) if is_pro else None,
            }).eq("id", user_id).execute()

    elif event["type"] == "customer.subscription.deleted":
        sub = event["data"]["object"]
        customer_id = sub.get("customer")
        result = client.table("profiles").select("id").eq("stripe_customer_id", customer_id).execute()
        if result.data:
            user_id = result.data[0]["id"]
            client.table("profiles").update({
                "is_pro": False,
                "tier": "free",
                "stripe_subscription_id": None,
                "subscription_plan": None,
                "subscription_renews_at": None,
            }).eq("id", user_id).execute()

    return {"received": True}


# GET /stripe/subscription-status
# Returns whether the current user is Pro
@router.get("/stripe/subscription-status")
async def get_subscription_status(user: AuthenticatedUser = Depends(get_current_user)):
    try:
        client = get_supabase_admin()
        result = supabase_execute_with_retry(
            lambda: client.table("profiles").select("is_pro, stripe_subscription_id").eq("id", user.user_id).execute()
        )
        if not result.data:
            return {"is_pro": False}
        return {
            "is_pro": result.data[0].get("is_pro", False),
            "subscription_id": result.data[0].get("stripe_subscription_id"),
        }
    except Exception as e:
        logger.warning("Subscription-status error (returning safe default)", exc_info=True)
        return {
            "status": "free",
            "plan": "free",
            "is_pro": False,
            "error": "temporarily_unavailable",
        }


# POST /stripe/cancel-subscription
# Cancels the user's subscription at period end
@router.post("/stripe/cancel-subscription")
async def cancel_subscription(user: AuthenticatedUser = Depends(get_current_user)):
    get_stripe()
    client = get_supabase_admin()
    result = client.table("profiles").select("stripe_subscription_id").eq("id", user.user_id).execute()
    if not result.data or not result.data[0].get("stripe_subscription_id"):
        raise HTTPException(400, "No active subscription")
    sub_id = result.data[0]["stripe_subscription_id"]
    stripe.Subscription.modify(sub_id, cancel_at_period_end=True)
    return {"cancelled": True}

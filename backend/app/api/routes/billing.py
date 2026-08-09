
import logging
from datetime import datetime, timedelta, timezone
from typing import Literal

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix="/billing", tags=["billing"])

logger = logging.getLogger(__name__)


# ── Helpers ────────────────────────────────────────────────────────────────────

def _init_stripe() -> None:
    settings = get_settings()
    key = (settings.stripe_secret_key or "").strip()
    if not key:
        raise HTTPException(status_code=503, detail="Billing not configured")
    stripe.api_key = key


def _price_id_for_plan(plan: str) -> str:
    settings = get_settings()
    mapping = {
        "pro_monthly": settings.stripe_price_pro_monthly or settings.stripe_price_monthly,
        "pro_annual": settings.stripe_price_pro_annual or settings.stripe_price_yearly,
        "team_season": settings.stripe_price_team_season,
    }
    price_id = (mapping.get(plan) or "").strip()
    if not price_id:
        raise HTTPException(status_code=503, detail=f"Price for plan '{plan}' not configured")
    return price_id


def _plan_from_price_id(price_id: str) -> str | None:
    settings = get_settings()
    mapping: dict[str, str] = {}
    if settings.stripe_price_pro_monthly:
        mapping[settings.stripe_price_pro_monthly] = "pro_monthly"
    if settings.stripe_price_monthly:
        mapping[settings.stripe_price_monthly] = "pro_monthly"
    if settings.stripe_price_pro_annual:
        mapping[settings.stripe_price_pro_annual] = "pro_annual"
    if settings.stripe_price_yearly:
        mapping[settings.stripe_price_yearly] = "pro_annual"
    if settings.stripe_price_team_season:
        mapping[settings.stripe_price_team_season] = "team_season"
    return mapping.get(price_id)


def _get_or_create_stripe_customer(user_id: str) -> str:
    """Look up stripe_customer_id from profiles; create Stripe customer if missing."""
    client = get_supabase_admin()
    result = client.table("profiles").select("stripe_customer_id").eq("id", user_id).execute()
    if result.data and result.data[0].get("stripe_customer_id"):
        return result.data[0]["stripe_customer_id"]

    # Fetch email from Supabase auth admin
    email: str | None = None
    try:
        auth_resp = client.auth.admin.get_user_by_id(user_id)
        if auth_resp and auth_resp.user:
            email = auth_resp.user.email
    except Exception:
        logger.warning("Could not fetch email for user_id=%s from Supabase auth", user_id)

    customer = stripe.Customer.create(
        email=email,
        metadata={"user_id": user_id},
    )
    try:
        client.table("profiles").update({"stripe_customer_id": customer.id}).eq("id", user_id).execute()
    except Exception:
        logger.error("Failed to save stripe_customer_id for user_id=%s", user_id)
    return customer.id


def _set_pro_from_subscription(
    user_id: str,
    sub: "stripe.Subscription",
    plan: str | None,
) -> None:
    """Write tier/subscription columns to profiles after a subscription event."""
    client = get_supabase_admin()
    status = sub.get("status", "")
    is_active = status in ("active", "trialing")

    renews_at: str | None = None
    period_end = sub.get("current_period_end")
    if period_end:
        renews_at = datetime.fromtimestamp(period_end, tz=timezone.utc).isoformat()

    if is_active:
        client.table("profiles").update({
            "is_pro": True,
            "tier": "pro",
            "stripe_customer_id": sub.get("customer"),
            "stripe_subscription_id": sub.get("id"),
            "subscription_plan": plan,
            "subscription_renews_at": renews_at,
        }).eq("id", user_id).execute()
    else:
        client.table("profiles").update({
            "is_pro": False,
            "tier": "free",
            "stripe_subscription_id": None,
            "subscription_plan": None,
            "subscription_renews_at": None,
        }).eq("id", user_id).execute()


def _set_team_active(team_id: str) -> None:
    """Mark a team_shares record as having an active season plan."""
    client = get_supabase_admin()
    expires_at = (datetime.now(timezone.utc) + timedelta(days=366)).isoformat()
    client.table("team_shares").update({
        "plan": "active",
        "plan_expires_at": expires_at,
    }).eq("share_id", team_id).execute()


def _user_for_customer(customer_id: str) -> str | None:
    """Resolve a Stripe customer_id to a profiles.id."""
    client = get_supabase_admin()
    result = client.table("profiles").select("id").eq("stripe_customer_id", customer_id).execute()
    if result.data:
        return result.data[0]["id"]
    return None


# ── Request models ─────────────────────────────────────────────────────────────

class CheckoutRequest(BaseModel):
    plan: Literal["pro_monthly", "pro_annual", "team_season"]
    team_id: str | None = None


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.post("/checkout")
def create_billing_checkout(
    payload: CheckoutRequest,
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Create a Stripe Checkout Session.

    plan: pro_monthly | pro_annual | team_season
    team_id: required for team_season; caller must be that team's admin.

    Returns {"url": "https://checkout.stripe.com/..."}.
    """
    _init_stripe()

    if payload.plan == "team_season":
        if not payload.team_id:
            raise HTTPException(status_code=400, detail="team_id required for team_season")
        client = get_supabase_admin()
        team = client.table("team_shares").select("owner_user_id").eq("share_id", payload.team_id).execute()
        if not team.data:
            raise HTTPException(status_code=404, detail="Team not found")
        if team.data[0].get("owner_user_id") != user.user_id:
            raise HTTPException(status_code=403, detail="Only the team admin can purchase a team plan")

    price_id = _price_id_for_plan(payload.plan)
    customer_id = _get_or_create_stripe_customer(user.user_id)

    settings = get_settings()
    origin = (request.headers.get("origin") or "").strip().rstrip("/") or settings.frontend_url
    success_url = f"{origin}/settings?checkout=success"
    cancel_url = f"{origin}/settings?checkout=cancel"

    metadata: dict[str, str] = {
        "user_id": user.user_id,
        "plan": payload.plan,
    }
    if payload.team_id:
        metadata["team_id"] = payload.team_id

    try:
        session = stripe.checkout.Session.create(
            mode="subscription",
            customer=customer_id,
            client_reference_id=user.user_id,
            line_items=[{"price": price_id, "quantity": 1}],
            allow_promotion_codes=True,
            success_url=success_url,
            cancel_url=cancel_url,
            metadata=metadata,
        )
    except Exception:
        logger.exception("Stripe checkout session creation failed for user_id=%s", user.user_id)
        raise HTTPException(status_code=503, detail="Checkout unavailable. Please try again.")

    return {"url": session.url}


@router.post("/webhook")
async def billing_webhook(request: Request):
    """
    Stripe webhook — no JWT auth, raw-body signature verification.

    Handles:
      checkout.session.completed
      customer.subscription.updated
      customer.subscription.created
      customer.subscription.deleted
    """
    settings = get_settings()
    webhook_secret = (settings.stripe_webhook_secret or "").strip()
    if not webhook_secret:
        logger.error("STRIPE_WEBHOOK_SECRET not configured — webhook rejected")
        return JSONResponse(status_code=400, content={"ok": False})

    sig_header = request.headers.get("stripe-signature")
    if not sig_header:
        return JSONResponse(status_code=400, content={"ok": False})

    raw_body = await request.body()
    _init_stripe()

    try:
        event = stripe.Webhook.construct_event(
            payload=raw_body,
            sig_header=sig_header,
            secret=webhook_secret,
        )
    except stripe.error.SignatureVerificationError:
        logger.warning("Stripe webhook: invalid signature")
        return JSONResponse(status_code=400, content={"ok": False})
    except Exception:
        logger.exception("Stripe webhook: event construction failed")
        return JSONResponse(status_code=400, content={"ok": False})

    event_type = event.get("type", "")
    obj = (event.get("data") or {}).get("object") or {}

    try:
        if event_type == "checkout.session.completed":
            _handle_checkout_completed(obj)

        elif event_type in ("customer.subscription.updated", "customer.subscription.created"):
            _handle_subscription_updated(obj)

        elif event_type == "customer.subscription.deleted":
            _handle_subscription_deleted(obj)

    except Exception:
        logger.exception("Stripe webhook: handler failed for event_type=%s", event_type)
        # Return 200 so Stripe doesn't retry — handler errors are logged, not retried
        return {"ok": True, "warning": "handler_error"}

    return {"ok": True}


def _handle_checkout_completed(session: dict) -> None:
    user_id = (session.get("client_reference_id") or "").strip() or None
    if not user_id:
        user_id = (session.get("metadata") or {}).get("user_id")
    if not user_id:
        logger.warning("checkout.session.completed: no user_id in session")
        return

    plan = (session.get("metadata") or {}).get("plan")
    team_id = (session.get("metadata") or {}).get("team_id")

    if plan == "team_season" and team_id:
        _set_team_active(team_id)
        logger.info("Team season activated: team_id=%s buyer=%s", team_id, user_id)
        return

    subscription_id = session.get("subscription")
    if subscription_id:
        try:
            sub = stripe.Subscription.retrieve(subscription_id)
            _set_pro_from_subscription(user_id=user_id, sub=sub, plan=plan)
        except Exception:
            logger.exception("Could not retrieve subscription %s for checkout", subscription_id)
            # Fallback: set is_pro without renews_at
            client = get_supabase_admin()
            client.table("profiles").update({
                "is_pro": True,
                "tier": "pro",
                "stripe_customer_id": session.get("customer"),
                "stripe_subscription_id": subscription_id,
                "subscription_plan": plan,
            }).eq("id", user_id).execute()
    else:
        # No subscription object yet — minimal update
        client = get_supabase_admin()
        client.table("profiles").update({
            "is_pro": True,
            "tier": "pro",
            "stripe_customer_id": session.get("customer"),
            "subscription_plan": plan,
        }).eq("id", user_id).execute()

    logger.info("Pro activated: user_id=%s plan=%s", user_id, plan)


def _handle_subscription_updated(sub: dict) -> None:
    customer_id = sub.get("customer")
    if not customer_id:
        return
    user_id = _user_for_customer(customer_id)
    if not user_id:
        logger.warning("subscription event: no profile found for customer=%s", customer_id)
        return

    # Determine plan from first price_id in the subscription
    plan: str | None = None
    try:
        items = (sub.get("items") or {}).get("data") or []
        if items:
            price_id = (items[0].get("price") or {}).get("id")
            if price_id:
                plan = _plan_from_price_id(price_id)
    except Exception:
        pass

    _set_pro_from_subscription(user_id=user_id, sub=sub, plan=plan)
    logger.info("Subscription updated: user_id=%s plan=%s status=%s", user_id, plan, sub.get("status"))


def _handle_subscription_deleted(sub: dict) -> None:
    customer_id = sub.get("customer")
    if not customer_id:
        return
    user_id = _user_for_customer(customer_id)
    if not user_id:
        return
    client = get_supabase_admin()
    client.table("profiles").update({
        "is_pro": False,
        "tier": "free",
        "stripe_subscription_id": None,
        "subscription_plan": None,
        "subscription_renews_at": None,
    }).eq("id", user_id).execute()
    logger.info("Pro removed (subscription deleted): user_id=%s", user_id)


@router.post("/portal")
def create_billing_portal(
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Create a Stripe Billing Portal session so the user can manage their subscription.
    Returns {"url": "https://billing.stripe.com/..."}.
    """
    _init_stripe()

    client = get_supabase_admin()
    result = client.table("profiles").select("stripe_customer_id").eq("id", user.user_id).execute()
    if not result.data or not result.data[0].get("stripe_customer_id"):
        raise HTTPException(status_code=400, detail="No billing account found. Subscribe first.")

    customer_id = result.data[0]["stripe_customer_id"]

    settings = get_settings()
    origin = (request.headers.get("origin") or "").strip().rstrip("/") or settings.frontend_url
    return_url = f"{origin}/settings"

    try:
        session = stripe.billing_portal.Session.create(
            customer=customer_id,
            return_url=return_url,
        )
    except Exception:
        logger.exception("Stripe portal session creation failed for user_id=%s", user.user_id)
        raise HTTPException(status_code=503, detail="Billing portal unavailable. Please try again.")

    return {"url": session.url}

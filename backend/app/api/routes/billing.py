"""
Stripe billing for FindEZ team season plans.

All purchases are one-time payments (mode='payment'), not subscriptions.
Individual paid plans (pro) are handled by Apple IAP — no web checkout for those.

Routes:
  POST /billing/checkout  — create Checkout Session for a team season purchase
  POST /billing/webhook   — Stripe webhook (raw body, no JWT)
  POST /billing/portal    — Stripe Customer Portal (payment history only)
"""

import logging
from datetime import datetime, timezone
from typing import Literal

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.services import teams_repo
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix="/billing", tags=["billing"])
logger = logging.getLogger(__name__)


# ── Helpers ────────────────────────────────────────────────────────────────────

def _init_stripe() -> None:
    key = (get_settings().stripe_secret_key or "").strip()
    if not key:
        raise HTTPException(status_code=503, detail="Billing not configured")
    stripe.api_key = key


def _season_expires_at() -> str:
    """Next Aug 31 23:59:59 UTC — end of the robotics season."""
    now = datetime.now(timezone.utc)
    year = now.year
    aug31 = datetime(year, 8, 31, 23, 59, 59, tzinfo=timezone.utc)
    if now > aug31:
        aug31 = datetime(year + 1, 8, 31, 23, 59, 59, tzinfo=timezone.utc)
    return aug31.isoformat()


def _price_id_for_plan(plan: str) -> str:
    settings = get_settings()
    mapping = {
        "ftc_season": settings.stripe_price_team_ftc,
        "frc_season": settings.stripe_price_team_frc,
        "district":   settings.stripe_price_district,
    }
    price_id = (mapping.get(plan) or "").strip()
    if not price_id:
        raise HTTPException(
            status_code=503,
            detail=f"Price for plan '{plan}' not configured (set STRIPE_PRICE_TEAM_FTC/FRC/DISTRICT)",
        )
    return price_id


def _get_or_create_stripe_customer(user_id: str) -> str:
    """Look up stripe_customer_id from profiles; create Stripe customer if missing."""
    client = get_supabase_admin()
    result = client.table("profiles").select("stripe_customer_id").eq("id", user_id).execute()
    if result.data and result.data[0].get("stripe_customer_id"):
        return result.data[0]["stripe_customer_id"]

    email: str | None = None
    try:
        auth_resp = client.auth.admin.get_user_by_id(user_id)
        if auth_resp and auth_resp.user:
            email = auth_resp.user.email
    except Exception:
        logger.warning("Could not fetch email for user_id=%s from Supabase auth", user_id)

    customer = stripe.Customer.create(email=email, metadata={"user_id": user_id})
    try:
        client.table("profiles").update({"stripe_customer_id": customer.id}).eq("id", user_id).execute()
    except Exception:
        logger.error("Failed to save stripe_customer_id for user_id=%s", user_id)
    return customer.id


# ── Request models ─────────────────────────────────────────────────────────────

class CheckoutRequest(BaseModel):
    plan: Literal["ftc_season", "frc_season", "district"]
    program: Literal["ftc", "frc", "vex", "fll"]
    team_name: str


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.post("/checkout")
def create_billing_checkout(
    payload: CheckoutRequest,
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Create a Stripe Checkout Session for a team season purchase (one-time payment).
    Works whether or not the buyer already has a team — the webhook creates it.
    Returns {"url": "https://checkout.stripe.com/..."}.
    """
    if get_settings().pilot_mode:
        return {"pilot": True, "message": "Payments are not enabled during the free pilot."}

    _init_stripe()

    team_name = (payload.team_name or "").strip()
    if not team_name:
        raise HTTPException(status_code=400, detail="team_name is required")

    price_id = _price_id_for_plan(payload.plan)
    customer_id = _get_or_create_stripe_customer(user.user_id)

    settings = get_settings()
    base = settings.frontend_url.rstrip("/")
    success_url = f"{base}/billing/success"
    cancel_url = f"{base}/billing/cancel"

    metadata: dict[str, str] = {
        "user_id": user.user_id,
        "plan": payload.plan,
        "program": payload.program,
        "team_name": team_name,
    }

    try:
        session = stripe.checkout.Session.create(
            mode="payment",
            customer=customer_id,
            client_reference_id=user.user_id,
            line_items=[{"price": price_id, "quantity": 1}],
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
      checkout.session.completed → creates team, sets plan + expiry, logs join_code
      customer.subscription.*   → tolerant no-ops (old events only)
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
        elif event_type in (
            "customer.subscription.updated",
            "customer.subscription.created",
            "customer.subscription.deleted",
        ):
            # Tolerant no-op: these were from the old subscription model.
            # Log and acknowledge so Stripe stops retrying.
            logger.info("Stripe webhook: ignoring legacy subscription event type=%s", event_type)
    except Exception:
        logger.exception("Stripe webhook: handler failed for event_type=%s", event_type)
        # Return 200 so Stripe doesn't retry — logged above.
        return {"ok": True, "warning": "handler_error"}

    return {"ok": True}


def _handle_checkout_completed(session: dict) -> None:
    """
    On a completed team season checkout:
    1. Extract user_id, plan, program, team_name from metadata.
    2. Create the team (buyer becomes owner with a join_code).
    3. Set plan + plan_expires_at = next Aug 31 on the team row.
    4. Log the join_code — no email provider exists yet; join_code is
       also returned by GET /teams so the buyer sees it immediately.
    """
    meta = session.get("metadata") or {}
    user_id = (
        (session.get("client_reference_id") or "").strip()
        or meta.get("user_id", "").strip()
    )
    if not user_id:
        logger.warning("checkout.session.completed: no user_id in session; skipping")
        return

    plan = meta.get("plan", "")
    program = meta.get("program", "")
    team_name = meta.get("team_name", "FindEZ Team")

    if not plan:
        logger.warning("checkout.session.completed: no plan in metadata user_id=%s", user_id)
        return

    try:
        team = teams_repo.create_team(
            user_id=user_id,
            name=team_name,
            program=program or "ftc",
        )
        team_id = team["team_id"]
        join_code = team.get("join_code", "")

        expires_at = _season_expires_at()
        supabase = get_supabase_admin()
        supabase.table("teams").update({
            "plan": plan,
            "plan_expires_at": expires_at,
        }).eq("team_id", team_id).execute()

        # Record Stripe customer on the buyer's profile
        customer_id = session.get("customer")
        if customer_id:
            try:
                supabase.table("profiles").update(
                    {"stripe_customer_id": customer_id}
                ).eq("id", user_id).execute()
            except Exception:
                logger.warning("Could not save stripe_customer_id for user_id=%s", user_id)

        # No email provider: join_code is accessible via GET /teams.
        logger.info(
            "Team created from checkout: team_id=%s join_code=%s plan=%s expires=%s user_id=%s",
            team_id, join_code, plan, expires_at, user_id,
        )
    except Exception:
        logger.exception(
            "checkout.session.completed: team creation failed user_id=%s plan=%s",
            user_id, plan,
        )
        raise  # re-raise so the webhook handler logs the warning and returns 200


@router.post("/portal")
def create_billing_portal(
    request: Request,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Stripe Customer Portal — shows payment history for one-time purchases.
    Note: portal functionality is limited for non-subscription customers;
    use it to let buyers download receipts.
    Returns {"url": "https://billing.stripe.com/..."}.
    """
    if get_settings().pilot_mode:
        return {"pilot": True, "message": "Payments are not enabled during the free pilot."}

    _init_stripe()

    client = get_supabase_admin()
    result = client.table("profiles").select("stripe_customer_id").eq("id", user.user_id).execute()
    if not result.data or not result.data[0].get("stripe_customer_id"):
        raise HTTPException(status_code=400, detail="No billing account found.")

    customer_id = result.data[0]["stripe_customer_id"]

    settings = get_settings()
    return_url = f"{settings.frontend_url.rstrip('/')}/settings"

    try:
        session = stripe.billing_portal.Session.create(
            customer=customer_id,
            return_url=return_url,
        )
    except Exception:
        logger.exception("Stripe portal session creation failed for user_id=%s", user.user_id)
        raise HTTPException(status_code=503, detail="Billing portal unavailable. Please try again.")

    return {"url": session.url}

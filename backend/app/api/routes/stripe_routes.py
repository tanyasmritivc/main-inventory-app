import stripe
import os
from fastapi import APIRouter, Request, HTTPException, Depends
from fastapi.responses import JSONResponse
from app.core.auth import get_current_user, AuthenticatedUser
from app.services.supabase_client import get_supabase_admin

router = APIRouter()


def get_stripe():
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY", "")
    return stripe


# POST /stripe/create-checkout-session
# Creates a Stripe Checkout session for monthly or yearly plan
@router.post("/stripe/create-checkout-session")
async def create_checkout_session(
    body: dict,
    user: AuthenticatedUser = Depends(get_current_user),
):
    get_stripe()
    plan = body.get("plan", "monthly")  # "monthly" or "yearly"
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
    except Exception as e:
        raise HTTPException(500, str(e))


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

    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        user_id = session.get("client_reference_id") or session.get("metadata", {}).get("user_id")
        subscription_id = session.get("subscription")
        if user_id:
            client.table("profiles").upsert({
                "id": user_id,
                "is_pro": True,
                "stripe_subscription_id": subscription_id,
                "stripe_customer_id": session.get("customer"),
            }).execute()

    elif event["type"] in ("customer.subscription.updated", "customer.subscription.created"):
        sub = event["data"]["object"]
        customer_id = sub.get("customer")
        status = sub.get("status")
        is_pro = status in ("active", "trialing")
        result = client.table("profiles").select("id").eq("stripe_customer_id", customer_id).execute()
        if result.data:
            user_id = result.data[0]["id"]
            client.table("profiles").update({
                "is_pro": is_pro,
                "stripe_subscription_id": sub.get("id"),
            }).eq("id", user_id).execute()

    elif event["type"] == "customer.subscription.deleted":
        sub = event["data"]["object"]
        customer_id = sub.get("customer")
        result = client.table("profiles").select("id").eq("stripe_customer_id", customer_id).execute()
        if result.data:
            user_id = result.data[0]["id"]
            client.table("profiles").update({
                "is_pro": False,
                "stripe_subscription_id": None,
            }).eq("id", user_id).execute()

    return {"received": True}


# GET /stripe/subscription-status
# Returns whether the current user is Pro
@router.get("/stripe/subscription-status")
async def get_subscription_status(user: AuthenticatedUser = Depends(get_current_user)):
    client = get_supabase_admin()
    result = client.table("profiles").select("is_pro, stripe_subscription_id").eq("id", user.user_id).execute()
    if not result.data:
        return {"is_pro": False}
    return {"is_pro": result.data[0].get("is_pro", False), "subscription_id": result.data[0].get("stripe_subscription_id")}


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

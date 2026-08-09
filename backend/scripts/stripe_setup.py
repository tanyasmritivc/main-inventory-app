#!/usr/bin/env python3
"""
Idempotent Stripe product/price/coupon setup for FindEZ.

Run once (or any time — safe to re-run):
    STRIPE_SECRET_KEY=sk_... python scripts/stripe_setup.py

Prints the price IDs to copy into .env.
"""
import os
import sys

# Allow running from repo root or backend/
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import stripe


def _init_stripe() -> None:
    key = os.environ.get("STRIPE_SECRET_KEY", "").strip()
    if not key:
        sys.exit("Error: STRIPE_SECRET_KEY is not set.")
    stripe.api_key = key


def _find_product(findez_key: str) -> stripe.Product | None:
    for product in stripe.Product.list(limit=100).auto_paging_iter():
        if product.metadata.get("findez_key") == findez_key:
            return product
    return None


def _find_price(product_id: str, findez_key: str) -> stripe.Price | None:
    for price in stripe.Price.list(product=product_id, limit=100).auto_paging_iter():
        if price.metadata.get("findez_key") == findez_key:
            return price
    return None


def _get_or_create_product(findez_key: str, name: str, description: str) -> stripe.Product:
    existing = _find_product(findez_key)
    if existing:
        print(f"  existing product: {existing.id}  ({name})")
        return existing
    product = stripe.Product.create(
        name=name,
        description=description,
        metadata={"findez_key": findez_key},
    )
    print(f"  created  product: {product.id}  ({name})")
    return product


def _get_or_create_price(
    product_id: str,
    findez_key: str,
    unit_amount: int,
    currency: str,
    interval: str,
    nickname: str,
) -> stripe.Price:
    existing = _find_price(product_id, findez_key)
    if existing:
        print(f"  existing price:   {existing.id}  ({nickname})")
        return existing
    price = stripe.Price.create(
        product=product_id,
        unit_amount=unit_amount,
        currency=currency,
        recurring={"interval": interval},
        nickname=nickname,
        metadata={"findez_key": findez_key},
    )
    print(f"  created  price:   {price.id}  ({nickname})")
    return price


def _get_or_create_coupon() -> stripe.Coupon:
    coupon_id = "FOUNDING49"
    try:
        coupon = stripe.Coupon.retrieve(coupon_id)
        print(f"  existing coupon:  {coupon.id}")
        return coupon
    except stripe.error.InvalidRequestError:
        coupon = stripe.Coupon.create(
            id=coupon_id,
            amount_off=5000,   # $50 in cents
            currency="usd",
            duration="once",
            name="Founding Team Discount",
        )
        print(f"  created  coupon:  {coupon.id}")
        return coupon


def main() -> None:
    _init_stripe()

    print("FindEZ Pro:")
    pro_product = _get_or_create_product(
        "findez_pro",
        "FindEZ Pro",
        "Unlimited items, spaces, and AI features",
    )
    pro_monthly = _get_or_create_price(
        pro_product.id, "pro_monthly",
        unit_amount=699, currency="usd", interval="month",
        nickname="Pro Monthly",
    )
    pro_annual = _get_or_create_price(
        pro_product.id, "pro_annual",
        unit_amount=5900, currency="usd", interval="year",
        nickname="Pro Annual",
    )

    print("\nFindEZ Team Season:")
    team_product = _get_or_create_product(
        "findez_team_season",
        "FindEZ Team Season",
        "Team inventory management — billed annually",
    )
    team_season = _get_or_create_price(
        team_product.id, "team_season",
        unit_amount=9900, currency="usd", interval="year",
        nickname="Team Season",
    )

    print("\nCoupons:")
    _get_or_create_coupon()

    print("\n# ── Copy these into .env ──────────────────────────────────────────────")
    print(f"STRIPE_PRICE_PRO_MONTHLY={pro_monthly.id}")
    print(f"STRIPE_PRICE_PRO_ANNUAL={pro_annual.id}")
    print(f"STRIPE_PRICE_TEAM_SEASON={team_season.id}")


if __name__ == "__main__":
    main()

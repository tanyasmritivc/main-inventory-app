#!/usr/bin/env python3
"""
Idempotent Stripe product/price setup for FindEZ team season plans.

All prices are one-time payments (no subscriptions).

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


def _find_product(findez_key: str) -> "stripe.Product | None":
    for product in stripe.Product.list(limit=100).auto_paging_iter():
        meta = product.metadata
        if meta is not None and getattr(meta, "findez_key", None) == findez_key:
            return product
    return None


def _find_price(product_id: str, findez_key: str) -> "stripe.Price | None":
    for price in stripe.Price.list(product=product_id, limit=100).auto_paging_iter():
        meta = price.metadata
        if meta is not None and getattr(meta, "findez_key", None) == findez_key:
            return price
    return None


def _get_or_create_product(findez_key: str, name: str, description: str) -> "stripe.Product":
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


def _get_or_create_one_time_price(
    product_id: str,
    findez_key: str,
    unit_amount: int,
    nickname: str,
) -> "stripe.Price":
    """Create a one-time (non-recurring) price."""
    existing = _find_price(product_id, findez_key)
    if existing:
        print(f"  existing price:   {existing.id}  ({nickname})")
        return existing
    price = stripe.Price.create(
        product=product_id,
        unit_amount=unit_amount,
        currency="usd",
        nickname=nickname,
        metadata={"findez_key": findez_key},
        # No 'recurring' key → one-time payment
    )
    print(f"  created  price:   {price.id}  ({nickname})")
    return price


def main() -> None:
    _init_stripe()

    print("FindEZ Team — FTC/VEX/FLL ($99 one-time):")
    ftc_product = _get_or_create_product(
        "findez_team_ftc",
        "FindEZ Team — FTC/VEX/FLL",
        "FindEZ team season plan for FTC, VEX, and FLL programs",
    )
    ftc_price = _get_or_create_one_time_price(
        ftc_product.id, "team_ftc_season",
        unit_amount=9900,
        nickname="Team FTC/VEX/FLL Season",
    )

    print("\nFindEZ Team — FRC ($199 one-time):")
    frc_product = _get_or_create_product(
        "findez_team_frc",
        "FindEZ Team — FRC",
        "FindEZ team season plan for FRC programs",
    )
    frc_price = _get_or_create_one_time_price(
        frc_product.id, "team_frc_season",
        unit_amount=19900,
        nickname="Team FRC Season",
    )

    print("\nFindEZ School Bundle — 10 teams ($499 one-time):")
    district_product = _get_or_create_product(
        "findez_district",
        "FindEZ School Bundle (10 teams)",
        "FindEZ district/school bundle — covers up to 10 teams for one season",
    )
    district_price = _get_or_create_one_time_price(
        district_product.id, "district_season",
        unit_amount=49900,
        nickname="School Bundle Season",
    )

    print("\n# ── Copy these into .env ──────────────────────────────────────────────")
    print(f"STRIPE_PRICE_TEAM_FTC={ftc_price.id}")
    print(f"STRIPE_PRICE_TEAM_FRC={frc_price.id}")
    print(f"STRIPE_PRICE_DISTRICT={district_price.id}")


if __name__ == "__main__":
    main()

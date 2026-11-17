"""Explicit supplier quotes. No scraped prices or inferred substitutes."""
from datetime import datetime, timezone, timedelta
from decimal import Decimal, ROUND_CEILING
from typing import Annotated, Literal
from pydantic import Field, HttpUrl, field_validator, model_validator
from .snapshot import Model

Quantity = Annotated[int, Field(strict=True, ge=1, le=1_000_000)]
Money = Annotated[Decimal, Field(ge=0, le=100_000_000, max_digits=15, decimal_places=6, allow_inf_nan=False)]


class Tier(Model):
    minimum_quantity: Quantity
    unit_price: Money


class Quote(Model):
    vendor: str = Field(min_length=1, max_length=150)
    product_url: HttpUrl
    source_note: str = Field(min_length=1, max_length=1000)
    currency: str = Field(pattern=r'^[A-Z]{3}$')
    unit_price: Money
    pack_size: Quantity = 1
    minimum_quantity: Quantity = 1
    tiers: list[Tier] = Field(default_factory=list, max_length=20)
    quoted_at: datetime
    valid_until: datetime
    availability: Literal['in_stock', 'unknown', 'out_of_stock'] = 'unknown'
    exact_part_confirmed: Literal[True]

    @field_validator('exact_part_confirmed', mode='before')
    @classmethod
    def explicit_confirmation(cls, value):
        if value is not True:
            raise ValueError('Confirm the exact part before recording a quote.')
        return value

    @field_validator('vendor', 'source_note')
    @classmethod
    def nonempty(cls, value):
        if not value.strip():
            raise ValueError('Provide a vendor and quote source.')
        return value.strip()

    @field_validator('product_url')
    @classmethod
    def https_only(cls, value):
        if value.scheme != 'https' or value.username or value.password:
            raise ValueError('Use a public HTTPS product link without credentials.')
        return value

    @model_validator(mode='after')
    def coherent(self):
        now = datetime.now(timezone.utc)
        if self.quoted_at.tzinfo is None or self.valid_until.tzinfo is None:
            raise ValueError('Quote times must include a timezone.')
        if self.quoted_at > now + timedelta(minutes=5) or self.valid_until <= self.quoted_at:
            raise ValueError('Check the quote and expiry dates.')
        thresholds = [tier.minimum_quantity for tier in self.tiers]
        if len(thresholds) != len(set(thresholds)):
            raise ValueError('Price breaks must have different quantities.')
        return self


def estimate(quote: Quote, required: int, now=None):
    """Minimum spend including beneficial bulk breaks; no currency conversion.

    Tier prices apply to all units at/above the threshold. Evaluate rounded
    candidates, since buying a larger pack can cost less than the bare shortage.
    Values remain decimal strings through JSON to avoid binary-money rounding.
    """
    if type(required) is not int or not 1 <= required <= 1_000_000:
        raise ValueError('Choose a positive quantity up to 1,000,000.')
    tiers = sorted(quote.tiers, key=lambda t: t.minimum_quantity)
    candidates = []
    for threshold in [required] + [t.minimum_quantity for t in tiers]:
        quantity = max(required, quote.minimum_quantity, threshold)
        quantity = int((Decimal(quantity) / quote.pack_size).to_integral_value(rounding=ROUND_CEILING)) * quote.pack_size
        price = quote.unit_price
        for tier in tiers:
            if quantity >= tier.minimum_quantity:
                price = tier.unit_price
        candidates.append((price * quantity, quantity, price))
    total, quantity, price = min(candidates)
    now = now or datetime.now(timezone.utc)
    return {'currency': quote.currency, 'required_quantity': required,
        'order_quantity': quantity, 'surplus_quantity': quantity - required,
        'unit_price': str(price), 'subtotal': str(total),
        'expired': quote.valid_until <= now,
        'purchasable': quote.valid_until > now and quote.availability != 'out_of_stock',
        'excludes': ['shipping', 'tax'], 'source': 'user_supplied_quote'}

from typing import Literal

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, StrictInt

Provider = Literal['shopify', 'amazon_seller', 'amazon_consumer']


class SourceRecord(BaseModel):
    """Stable handoff to FIND; quantities must not be added to physical inventory."""
    model_config = ConfigDict(extra='forbid')
    kind: Literal['catalog_variant', 'merchant_stock', 'sale_line', 'purchase_line']
    external_id: str = Field(min_length=1, max_length=500)
    title: str = Field(max_length=1000)
    product_id: str | None = Field(default=None, max_length=500)
    sku: str | None = Field(default=None, max_length=500)
    barcode: str | None = Field(default=None, max_length=200)
    asin: str | None = Field(default=None, pattern=r'^[A-Z0-9]{10}$')
    order_id: str | None = Field(default=None, max_length=200)
    quantity: StrictInt | None = Field(default=None, ge=0, le=100000000)
    available_quantity: StrictInt | None = Field(default=None, ge=-100000000, le=100000000)
    fulfilled_quantity: StrictInt | None = Field(default=None, ge=0, le=100000000)
    current_quantity: StrictInt | None = Field(default=None, ge=0, le=100000000)
    source_status: str = Field(default='unknown', max_length=100)
    source_updated_at: AwareDatetime | None = None
    ordered_at: AwareDatetime | None = None
    evidence: Literal['provider_api', 'user_file'] = 'provider_api'
    physically_verified: Literal[False] = False


class ProviderError(Exception):
    """Safe messages only. Never retain an upstream body or credential here."""
    def __init__(self, message='Provider request failed. Retry the sync.', status=502):
        super().__init__(message)
        self.status = status

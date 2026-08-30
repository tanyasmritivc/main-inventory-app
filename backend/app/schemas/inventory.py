
from typing import Annotated

from pydantic import BaseModel, Field


class AddItemRequest(BaseModel):
    name: str = Field(max_length=200)
    category: str = Field(max_length=100)
    quantity: int = Field(ge=0, le=100000)
    location: str = Field(max_length=200)
    image_url: str | None = Field(default=None, max_length=2000)
    barcode: str | None = Field(default=None, max_length=100)
    purchase_source: str | None = Field(default=None, max_length=200)
    notes: str | None = Field(default=None, max_length=2000)


class AddItemResponse(BaseModel):
    item: dict


class SearchItemsRequest(BaseModel):
    query: str = Field(max_length=500)


class SearchItemsResponse(BaseModel):
    items: list[dict]
    parsed: dict


class DeleteItemResponse(BaseModel):
    deleted: bool


class ExtractFromImageResponse(BaseModel):
    extracted: dict
    image_url: str


class ProcessBarcodeRequest(BaseModel):
    barcode: str = Field(max_length=100)


class ProcessBarcodeResponse(BaseModel):
    result: dict


class BarcodeLookupRequest(BaseModel):
    barcode: str = Field(max_length=100)


class BarcodeLookupResponse(BaseModel):
    barcode: str | None = None
    name: str | None = None
    brand: str | None = None
    model: str | None = None
    category: str | None = None
    image_url: str | None = None
    found_in_inventory: bool = False
    existing_item: dict | None = None


class UpdateItemRequest(BaseModel):
    item_id: str = Field(max_length=36)
    name: str | None = Field(default=None, max_length=200)
    category: str | None = Field(default=None, max_length=100)
    quantity: int | None = Field(default=None, ge=0, le=100000)
    location: str | None = Field(default=None, max_length=200)
    image_url: str | None = Field(default=None, max_length=2000)
    barcode: str | None = Field(default=None, max_length=100)
    purchase_source: str | None = Field(default=None, max_length=200)
    notes: str | None = Field(default=None, max_length=2000)


class UpdateItemResponse(BaseModel):
    item: dict


class VerifiedCatalogMatch(BaseModel):
    catalog_id: str
    verified: bool = True
    source: str = Field(default="manufacturer", max_length=50)
    product_url: str | None = Field(default=None, max_length=1000)
    source_url: str | None = Field(default=None, max_length=1000)
    specifications: dict = Field(default_factory=dict)
    compatibility: dict = Field(default_factory=dict)


class VerifiedCatalogPart(BaseModel):
    catalog_id: str
    canonical_name: str
    brand: str
    category: str
    subcategory: str | None = None
    part_number: str
    description: str | None = None
    product_url: str | None = None
    source_url: str | None = None
    specifications: dict = Field(default_factory=dict)
    compatibility: dict = Field(default_factory=dict)
    verification_status: str


class CompatibleCatalogPart(BaseModel):
    catalog_id: str
    canonical_name: str
    brand: str
    part_number: str
    product_url: str | None = None
    shared_interfaces: list[str] = Field(default_factory=list)


class CatalogCompatibilityResponse(BaseModel):
    interfaces: list[str] = Field(default_factory=list)
    matches: list[CompatibleCatalogPart] = Field(default_factory=list)


class ExtractedInventoryItem(BaseModel):
    name: str = Field(max_length=200)
    category: str = Field(max_length=100)
    subcategory: str | None = Field(default=None, max_length=100)
    quantity: int = Field(default=1, ge=0, le=100000)
    brand: str | None = Field(default=None, max_length=100)
    part_number: str | None = Field(default=None, max_length=100)
    barcode: str | None = Field(default=None, max_length=100)
    tags: list[Annotated[str, Field(max_length=50)]] | None = Field(default=None, max_length=20)
    confidence: float | None = Field(default=None, ge=0, le=1)
    notes: str | None = Field(default=None, max_length=2000)
    location: str | None = Field(default=None, max_length=200)
    catalog_match: VerifiedCatalogMatch | None = None


class MultiExtractSummary(BaseModel):
    total_detected: int
    categories: dict


class MultiExtractFromImageResponse(BaseModel):
    items: list[ExtractedInventoryItem]
    summary: MultiExtractSummary


class BulkCreateRequest(BaseModel):
    items: list[ExtractedInventoryItem] = Field(max_length=200)


class BulkCreateResponse(BaseModel):
    inserted: list[dict]
    failures: list[dict]

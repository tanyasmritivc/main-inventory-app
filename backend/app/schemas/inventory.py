from __future__ import annotations

from pydantic import BaseModel, Field


class AddItemRequest(BaseModel):
    name: str
    category: str
    quantity: int = Field(ge=0)
    location: str
    image_url: str | None = None
    barcode: str | None = None
    purchase_source: str | None = None
    notes: str | None = None


class AddItemResponse(BaseModel):
    item: dict


class SearchItemsRequest(BaseModel):
    query: str


class SearchItemsResponse(BaseModel):
    items: list[dict]
    parsed: dict


class DeleteItemResponse(BaseModel):
    deleted: bool


class ExtractFromImageResponse(BaseModel):
    extracted: dict
    image_url: str


class ProcessBarcodeRequest(BaseModel):
    barcode: str


class ProcessBarcodeResponse(BaseModel):
    result: dict


class UpdateItemRequest(BaseModel):
    item_id: str
    name: str | None = None
    category: str | None = None
    quantity: int | None = Field(default=None, ge=0)
    location: str | None = None
    image_url: str | None = None
    barcode: str | None = None
    purchase_source: str | None = None
    notes: str | None = None


class UpdateItemResponse(BaseModel):
    item: dict


class ExtractedInventoryItem(BaseModel):
    name: str
    category: str
    subcategory: str | None = None
    quantity: int = Field(default=1, ge=0)
    brand: str | None = None
    part_number: str | None = None
    barcode: str | None = None
    tags: list[str] | None = None
    confidence: float | None = Field(default=None, ge=0, le=1)
    notes: str | None = None
    location: str | None = None


class MultiExtractSummary(BaseModel):
    total_detected: int
    categories: dict


class MultiExtractFromImageResponse(BaseModel):
    items: list[ExtractedInventoryItem]
    summary: MultiExtractSummary


class BulkCreateRequest(BaseModel):
    items: list[ExtractedInventoryItem]


class BulkCreateResponse(BaseModel):
    inserted: list[dict]
    failures: list[dict]

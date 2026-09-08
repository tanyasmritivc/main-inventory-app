from datetime import datetime, timezone
from uuid import UUID

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator

WORKSPACE_SCOPES = {"items:read", "items:write", "import:write", "workspace:read"}
GLOBAL_SCOPES = {"org:read", "org:write"}


class InputModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class KeyCreate(InputModel):
    name: str = Field(min_length=1, max_length=120)
    workspace_id: UUID | None = None
    scopes: list[str] = Field(min_length=1, max_length=4)
    expires_at: AwareDatetime | None = None

    @model_validator(mode="after")
    def valid_key(self):
        allowed = WORKSPACE_SCOPES if self.workspace_id else GLOBAL_SCOPES
        if len(set(self.scopes)) != len(self.scopes) or not set(self.scopes) <= allowed:
            raise ValueError("Invalid scopes for this key type")
        if self.expires_at and self.expires_at <= datetime.now(timezone.utc):
            raise ValueError("Expiry must be in the future")
        return self


class ItemCreate(InputModel):
    workspace_id: UUID | None = None
    name: str = Field(min_length=1, max_length=250)
    category: str = Field(min_length=1, max_length=200)
    quantity: int = Field(ge=0, le=2147483647, strict=True)
    location: str = Field(min_length=1, max_length=250)
    notes: str | None = Field(default=None, max_length=10000)
    barcode: str | None = Field(default=None, max_length=250)
    source_system: str | None = Field(default=None, min_length=1, max_length=120)
    external_id: str | None = Field(default=None, min_length=1, max_length=250)

    @model_validator(mode="after")
    def identity_pair(self):
        if (self.source_system is None) != (self.external_id is None):
            raise ValueError("source_system and external_id must be provided together")
        return self


class ItemPatch(InputModel):
    name: str | None = Field(default=None, min_length=1, max_length=250)
    category: str | None = Field(default=None, min_length=1, max_length=200)
    quantity: int | None = Field(default=None, ge=0, le=2147483647, strict=True)
    location: str | None = Field(default=None, min_length=1, max_length=250)
    notes: str | None = Field(default=None, max_length=10000)
    barcode: str | None = Field(default=None, max_length=250)

    @model_validator(mode="after")
    def nonempty_update(self):
        if not self.model_fields_set:
            raise ValueError("No changes supplied")
        for field in self.model_fields_set & {"name", "category", "quantity", "location"}:
            if getattr(self, field) is None:
                raise ValueError("Required item fields cannot be null")
        return self


class BulkItem(ItemCreate):
    source_system: str = Field(min_length=1, max_length=120)
    external_id: str = Field(min_length=1, max_length=250)


class BulkRequest(InputModel):
    items: list[BulkItem] = Field(min_length=1, max_length=500)

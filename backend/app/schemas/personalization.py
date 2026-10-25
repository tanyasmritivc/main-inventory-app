"""Small, closed contracts. No client can submit a completed inventory event."""
from enum import Enum
from typing import Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator, AwareDatetime


class EventType(str, Enum):
    search = 'inventory.search_performed'
    search_succeeded = 'inventory.search_succeeded'
    search_failed = 'inventory.search_failed'
    viewed = 'inventory.item_viewed'
    created = 'inventory.item_created'
    updated = 'inventory.item_updated'
    moved = 'inventory.item_moved'
    quantity = 'inventory.quantity_changed'
    consumed = 'inventory.item_consumed'
    deleted = 'inventory.item_deleted'
    alias = 'inventory.alias_confirmed'
    review_required = 'scan.review_required'
    review_completed = 'scan.review_completed'
    sent = 'notification.sent'
    delivered = 'notification.delivered'
    opened = 'notification.opened'
    dismissed = 'notification.dismissed'
    completed = 'notification.action_completed'


class EventPayload(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)
    count: int | None = Field(default=None, ge=0, le=1000000)
    delta: int | None = Field(default=None, ge=-1000000, le=1000000)
    query_hash: str | None = Field(default=None, pattern=r'^[a-f0-9]{64}$')


class ActivityEvent(BaseModel):
    model_config = ConfigDict(extra='forbid')
    id: UUID
    user_id: UUID
    event_type: EventType
    occurred_at: AwareDatetime
    source: Literal['database', 'search', 'explicit', 'apns', 'device']
    inventory_id: UUID | None = None
    entity_type: Literal['item', 'review', 'notification'] | None = None
    entity_id: UUID | None = None
    payload: EventPayload = Field(default_factory=EventPayload)

    @model_validator(mode='after')
    def entity_pair(self):
        if (self.entity_type is None) != (self.entity_id is None):
            raise ValueError('Entity type and ID must be provided together')
        if self.entity_type in ('item', 'review') and self.inventory_id is None:
            raise ValueError('Inventory is required for an inventory entity')
        return self


class ProfileChange(BaseModel):
    model_config = ConfigDict(extra='forbid')
    operation_id: UUID
    expected_revision: int = Field(ge=0)
    enabled: bool
    categories: list[Literal['low_stock', 'scan_review']] = Field(default_factory=list, max_length=2)
    timezone: str = Field(default='UTC', max_length=64)
    quiet_start: int = Field(default=21*60, ge=0, le=1439)
    quiet_end: int = Field(default=9*60, ge=0, le=1439)
    daily_cap: int = Field(default=1, ge=0, le=2)
    weekly_cap: int = Field(default=3, ge=0, le=5)

    @field_validator('timezone')
    @classmethod
    def valid_zone(cls, value):
        try: ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError): raise ValueError('Use an IANA timezone') from None
        return value

    @field_validator('categories')
    @classmethod
    def unique_categories(cls, value):
        return sorted(set(value))


class AliasChange(BaseModel):
    model_config = ConfigDict(extra='forbid')
    operation_id: UUID
    expected_revision: int = Field(ge=0)
    inventory_id: UUID
    alias: str = Field(min_length=1, max_length=60, pattern=r'^[^\W_][\w ]*$')
    item_id: UUID | None = None  # null deletes; correction uses the same normalized key

    @field_validator('alias')
    @classmethod
    def normalize_alias(cls, value):
        if any(not (c.isalnum() or c == ' ') for c in value):
            raise ValueError('Use letters, numbers and spaces')
        return ' '.join(value.casefold().split())


class ResetChange(BaseModel):
    model_config = ConfigDict(extra='forbid')
    operation_id: UUID
    expected_revision: int = Field(ge=0)


class NotificationFeedback(BaseModel):
    model_config = ConfigDict(extra='forbid')
    outcome: Literal['delivered', 'opened', 'dismissed']

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel

EventType = Literal['usage', 'note', 'failure', 'success', 'restock', 'photo']


class ItemEventCreate(BaseModel):
    item_id: str
    event_type: EventType
    content: str | None = None
    quantity_delta: int | None = None
    image_url: str | None = None


class ItemEventResponse(BaseModel):
    event_id: str
    item_id: str
    user_id: str
    event_type: str
    content: str | None = None
    quantity_delta: int | None = None
    image_url: str | None = None
    created_at: datetime

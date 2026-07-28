
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

EventType = Literal['usage', 'note', 'failure', 'success', 'restock', 'photo']


class ItemEventCreate(BaseModel):
    item_id: str = Field(max_length=36)
    event_type: EventType
    content: str | None = Field(default=None, max_length=2000)
    quantity_delta: int | None = None
    image_url: str | None = Field(default=None, max_length=2000)


class ItemEventResponse(BaseModel):
    event_id: str
    item_id: str
    user_id: str
    event_type: str
    content: str | None = None
    quantity_delta: int | None = None
    image_url: str | None = None
    created_at: datetime

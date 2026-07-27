from __future__ import annotations

from pydantic import BaseModel


class AICommandRequest(BaseModel):
    message: str
    conversation_history: list[dict] = []
    conversation_id: str | None = None


class AICommandResponse(BaseModel):
    tool: str | None
    result: dict | list | None
    assistant_message: str

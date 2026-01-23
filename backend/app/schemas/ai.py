from __future__ import annotations

from pydantic import BaseModel


class AICommandRequest(BaseModel):
    message: str


class AICommandResponse(BaseModel):
    tool: str | None
    result: dict | list | None
    assistant_message: str

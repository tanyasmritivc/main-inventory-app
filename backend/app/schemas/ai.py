
from pydantic import BaseModel, Field


class AICommandRequest(BaseModel):
    message: str = Field(max_length=4000)
    conversation_history: list[dict] = Field(default=[], max_length=50)
    conversation_id: str | None = Field(default=None, max_length=100)


class AICommandResponse(BaseModel):
    tool: str | None
    result: dict | list | None
    assistant_message: str

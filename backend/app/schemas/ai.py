
from pydantic import BaseModel, Field, field_validator


class AICommandRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    conversation_history: list[dict] = Field(default=[], max_length=50)
    conversation_id: str | None = Field(default=None, max_length=100)
    supports_item_actions: bool = False

    @field_validator('message', mode='before')
    @classmethod
    def trim_message(cls, value):
        return value.strip() if isinstance(value, str) else value


class AICommandResponse(BaseModel):
    tool: str | None
    result: dict | list | None
    assistant_message: str
    answer_context: dict | None = None

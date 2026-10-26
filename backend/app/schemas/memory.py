"""Explicit memory commands. No arbitrary profile facts or model instructions."""
import re
from typing import Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, model_validator


class MemoryChange(BaseModel):
    model_config = ConfigDict(extra='forbid')
    operation_id: UUID
    expected_revision: int = Field(ge=0)
    action: Literal['settings', 'set', 'delete', 'clear']
    key: Literal['answer_length', 'answer_format'] | None = None
    value: str | None = None
    enabled: bool | None = None
    inventory_id: UUID | None = None
    alias: str | None = Field(default=None, max_length=60)
    space_id: UUID | None = None

    @model_validator(mode='after')
    def explicit_fields(self):
        if self.action == 'settings':
            if self.enabled is None or any(v is not None for v in (self.key, self.value, self.inventory_id, self.alias, self.space_id)):
                raise ValueError('Choose whether memory is enabled')
        elif self.action == 'clear':
            if any(v is not None for v in (self.key, self.value, self.enabled, self.inventory_id, self.alias, self.space_id)):
                raise ValueError('Forget all memory takes no preference values')
        else:
            if self.enabled is not None:
                raise ValueError('Use settings to enable memory')
            if self.inventory_id:
                if self.key or self.value or not self.alias or not re.fullmatch(r'[^\W_][^\W_ ]*(?: [^\W_]+)*', self.alias.strip(), re.UNICODE):
                    raise ValueError('Use a short alias with letters, numbers and spaces')
                self.alias = ' '.join(self.alias.lower().split())
                if (self.action == 'set') != (self.space_id is not None):
                    raise ValueError('Select a saved location for the alias')
            else:
                if self.alias is not None or self.space_id is not None or self.key is None:
                    raise ValueError('Select an answer preference')
                choices = {'answer_length': ('brief', 'standard', 'detailed'), 'answer_format': ('paragraphs', 'bullets')}
                if self.action == 'set' and self.value not in choices[self.key]:
                    raise ValueError('Choose a supported preference value')
                if self.action == 'delete' and self.value is not None:
                    raise ValueError('Delete takes no value')
        return self

"""Bounded World metadata. No inventory identity or quantity is writable here."""
import json
from typing import Annotated, Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from app.services.world_rules import PIECES


class Model(BaseModel):
    model_config = ConfigDict(extra='forbid', allow_inf_nan=False)


class Position(Model):
    x: float = Field(ge=-5, le=5)
    z: float = Field(ge=-5, le=5)
    r: float = Field(default=0, ge=0, lt=360)
    y: float = Field(default=0, ge=0, le=5)


class Piece(Position):
    id: UUID
    t: str

    @field_validator('t')
    @classmethod
    def known_piece(cls, value):
        if value not in PIECES:
            raise ValueError('Choose a known Build piece.')
        return value


class Layout(Model):
    v: Literal[2] = 2
    floor: int = Field(default=0, ge=0, le=15, strict=True)
    pieces: list[Piece] = Field(default_factory=list, max_length=300)
    places: dict[Annotated[str, Field(pattern=r'^(item|bin|area):[0-9a-fA-F-]{36}$')], Position] = Field(default_factory=dict, max_length=1000)

    @model_validator(mode='after')
    def bounded(self):
        if len({p.id for p in self.pieces}) != len(self.pieces):
            raise ValueError('Build piece IDs must be unique.')
        if len(self.model_dump_json().encode()) >= 200_000:
            raise ValueError('The layout must be smaller than 200 KB.')
        for key in self.places:
            UUID(key.split(':', 1)[1])
        return self


class SaveLayout(Model):
    layout: Layout
    revision: int = Field(ge=0, strict=True)


class GameValue(Model):
    game: Literal['find', 'count', 'where']
    right: int = Field(default=0, ge=0, le=5, strict=True)
    seconds: float | None = Field(default=None, ge=2, le=3600)


class Event(Model):
    kind: Literal['scan', 'add', 'spot', 'game', 'build', 'tour']
    ref: UUID
    value: GameValue | None = None

    @model_validator(mode='after')
    def value_matches_kind(self):
        if (self.kind == 'game') != (self.value is not None):
            raise ValueError('Only game events require a game result.')
        return self


class Area(Model):
    id: UUID
    name: str = Field(min_length=1, max_length=100)
    kind: Literal['shelf', 'drawer', 'cabinet', 'container', 'other']
    parent_id: UUID | None = None

    @field_validator('name')
    @classmethod
    def name_not_blank(cls, value):
        if not value.strip():
            raise ValueError('Name is required.')
        return value.strip()


class Placement(Model):
    area_id: UUID | None = None
    expected_area_id: UUID | None = None
    bin_id: UUID | None = None
    expected_bin_id: UUID | None = None


class ShareCreate(Model):
    space_id: UUID
    request_id: UUID


class SharePatch(Model):
    show_counts: bool | None = Field(default=None, strict=True)
    show_locations: bool | None = Field(default=None, strict=True)
    show_photos: bool | None = Field(default=None, strict=True)
    revoke: bool = Field(default=False, strict=True)


class DailyScore(Model):
    scope_id: UUID
    seconds: float = Field(ge=2, le=3600)

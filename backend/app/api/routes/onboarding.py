"""Account-owned onboarding answers, separate from inventory and Team data."""
from datetime import datetime, timezone
import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(tags=["profile"])
logger = logging.getLogger(__name__)

UseCase = Literal['household', 'business', 'laboratory', 'education', 'robotics', 'manufacturing', 'warehouse', 'other']
InventoryType = Literal['tools', 'equipment', 'parts', 'supplies', 'products', 'household_items', 'other']
Goal = Literal['find_items', 'identify_items', 'track_stock', 'organize_spaces', 'share_inventory']


class OnboardingAnswers(BaseModel):
    model_config = ConfigDict(extra='forbid')
    schema_version: Literal[1] = 1
    use_case: UseCase
    use_case_other: str | None = Field(default=None, max_length=80)
    inventory_types: list[InventoryType] = Field(min_length=1, max_length=7)
    inventory_other: str | None = Field(default=None, max_length=80)
    primary_goal: Goal
    collaboration: Literal['solo', 'others']

    @field_validator('use_case_other', 'inventory_other')
    @classmethod
    def clean_label(cls, value):
        if value is None:
            return None
        value = value.strip()
        if not value or any(ord(c) < 32 or ord(c) == 127 for c in value):
            raise ValueError('Enter a short, single-line answer')
        return value

    @field_validator('inventory_types')
    @classmethod
    def distinct_types(cls, value):
        if len(value) != len(set(value)):
            raise ValueError('Choose each inventory type once')
        return sorted(value)

    @model_validator(mode='after')
    def other_labels(self):
        if (self.use_case == 'other') != (self.use_case_other is not None):
            raise ValueError('An Other use needs its own label')
        if ('other' in self.inventory_types) != (self.inventory_other is not None):
            raise ValueError('An Other inventory type needs its own label')
        return self


_FIELDS = list(OnboardingAnswers.model_fields)
_COLUMNS = ','.join(['user_id', *_FIELDS, 'updated_at'])


def _read_answers(row):
    return OnboardingAnswers.model_validate({k: row.get(k) for k in _FIELDS}).model_dump(mode='json')


@router.get('/profile/onboarding')
def get_onboarding(user: AuthenticatedUser = Depends(get_current_user)):
    try:
        result = get_supabase_admin().table('onboarding_responses').select(_COLUMNS).eq('user_id', user.user_id).limit(1).execute()
        if not result.data:
            return {'answers': None}
        row = result.data[0]
        if row.get('user_id') != user.user_id:
            raise ValueError('Unexpected response owner')
        return {'answers': _read_answers(row)}
    except Exception:
        logger.exception('Onboarding answer read failed')
        raise HTTPException(503, 'Could not load your setup answers. Please try again.') from None


@router.put('/profile/onboarding')
def save_onboarding(body: OnboardingAnswers, user: AuthenticatedUser = Depends(get_current_user)):
    expected = body.model_dump(mode='json')
    payload = {**expected, 'user_id': user.user_id, 'source': 'ios', 'updated_at': datetime.now(timezone.utc).isoformat()}
    try:
        result = get_supabase_admin().table('onboarding_responses').upsert(payload, on_conflict='user_id').execute()
        row = result.data[0] if result.data else None
        if row is None or row.get('user_id') != user.user_id or _read_answers(row) != expected:
            raise ValueError('The answer write was not confirmed')
        return {'saved': True, 'answers': expected}
    except Exception:
        logger.exception('Onboarding answer save failed')
        raise HTTPException(503, 'Could not save your setup answers. Please try again.') from None

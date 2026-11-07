from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services import announcements

router = APIRouter(prefix='/announcements', tags=['announcements'])


class ClaimRequest(BaseModel):
    session_id: UUID
    platform: Literal['ios', 'android']
    client_revision: int = Field(ge=1, le=10000)
    legacy_seen: bool = False


class ReceiptRequest(BaseModel):
    event: Literal['shown', 'dismissed', 'acknowledged', 'clicked']


@router.get('/access')
def access(user: AuthenticatedUser = Depends(get_current_user)):
    return announcements.access_snapshot(user.user_id)


@router.post('/claim')
def claim(request: ClaimRequest, user: AuthenticatedUser = Depends(get_current_user)):
    return announcements.claim(user.user_id, request)


@router.post('/{campaign_id}/receipt')
def receipt(campaign_id: str, request: ReceiptRequest, user: AuthenticatedUser = Depends(get_current_user)):
    if not announcements.receipt(user.user_id, campaign_id, request.event):
        raise HTTPException(404, 'Announcement not found.')
    return {'saved': True}

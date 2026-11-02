from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field, model_validator

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.access_invitations import code_hash, decorate, invitation_rpc

router = APIRouter(prefix='/access-invitations', tags=['invitations'])


class InvitationLookup(BaseModel):
    code: str | None = Field(default=None, pattern=r'^[A-Za-z2-9]{12}$')
    invitation_id: UUID | None = None

    @model_validator(mode='after')
    def one_identifier(self):
        if bool(self.code) == bool(self.invitation_id):
            raise ValueError('Use either the invitation link or code.')
        return self


class InvitationDecision(BaseModel):
    action: Literal['accept', 'decline', 'cancel']


@router.get('')
def sent_invitations(scope: Literal['organization', 'workspace', 'inventory'], resource_id: UUID,
                     response: Response, user: AuthenticatedUser = Depends(get_current_user)):
    response.headers['Cache-Control'] = 'no-store'
    rows = invitation_rpc(user.user_id, 'sent', {'scope': scope, 'resource_id': str(resource_id)})
    return {'invitations': [decorate(row) for row in rows]}


@router.post('/preview')
def preview(body: InvitationLookup, response: Response, user: AuthenticatedUser = Depends(get_current_user)):
    response.headers['Cache-Control'] = 'no-store'
    lookup = {'code_hash': code_hash(body.code)} if body.code else {'invitation_id': str(body.invitation_id)}
    return {'invitation': decorate(invitation_rpc(user.user_id, 'preview', lookup))}


@router.post('/{invitation_id}/decision')
def decide(invitation_id: UUID, body: InvitationDecision, response: Response,
           user: AuthenticatedUser = Depends(get_current_user)):
    response.headers['Cache-Control'] = 'no-store'
    row = invitation_rpc(user.user_id, body.action, {'invitation_id': str(invitation_id)})
    if row.get('status') not in ('accepted', 'declined', 'cancelled'):
        raise HTTPException(503, 'Your decision could not be confirmed. Refresh before retrying.')
    return {'invitation': decorate(row)}

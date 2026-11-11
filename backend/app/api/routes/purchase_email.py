"""Private Gmail OAuth and purchase evidence. No inbox mutation endpoints."""
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.commerce import repository as repo, purchase_email as mail, gmail

router = APIRouter()


class ConnectRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    inventory_id: UUID


class CompleteRequest(ConnectRequest):
    connection_id: UUID
    code: str = Field(min_length=1, max_length=4096)
    state: str = Field(min_length=1, max_length=200)


@router.post('/gmail/connect')
@limiter.limit('5/minute')
def connect(request: Request, body: ConnectRequest, user: AuthenticatedUser = Depends(get_current_user)):
    return gmail.start(user.user_id, body.inventory_id)


@router.post('/gmail/complete')
@limiter.limit('10/minute')
def complete(request: Request, body: CompleteRequest, user: AuthenticatedUser = Depends(get_current_user)):
    return gmail.complete(user.user_id, body.inventory_id, body.connection_id, body.code, body.state)


@router.delete('/gmail')
def disconnect(inventory_id: UUID, purge: bool = False, user: AuthenticatedUser = Depends(get_current_user)):
    return gmail.disconnect(user.user_id, inventory_id, purge)


@router.get('/gmail')
def inbox(inventory_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    repo.authorize(inventory_id, user.user_id)
    connections = repo.connections(inventory_id, user.user_id)
    connection = next((c for c in reversed(connections) if c['provider'] == 'amazon_consumer' and c['status'] == 'connected'), None)
    empty = {'account': None, 'messages': [], 'purchases': [], 'has_more': False, 'stock_effect': 'none'}
    if not connection:
        return empty
    accounts = repo.execute(repo.get_supabase_raw().table('commerce_gmail_accounts')
        .select('status,email,last_sync_at,last_error').eq('connection_id', connection['id']).limit(1)) or []
    if not accounts:
        return empty
    messages = repo.execute(repo.get_supabase_raw().table('commerce_purchase_emails')
        .select('id,status,result,received_at').eq('connection_id', connection['id'])
        .order('received_at', desc=True).limit(1001)) or []
    visible = messages[:1000]
    return {'account': accounts[0], 'messages': visible, 'purchases': mail.purchase_summary(visible),
            'has_more': len(messages) > 1000, 'stock_effect': 'none'}

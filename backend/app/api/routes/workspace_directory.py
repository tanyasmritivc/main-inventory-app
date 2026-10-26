"""Workspace discovery never grants inventory content access."""
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from pydantic import BaseModel, Field
from postgrest.exceptions import APIError

from app.core.auth import AuthenticatedUser, get_current_user
from app.api.routes.inventory_workspaces import _workspace
from app.services.supabase_client import get_supabase_raw

router = APIRouter(tags=['workspace-directory'])


def directory_rpc(actor, action, data):
    try:
        saved = get_supabase_raw().rpc('findez_workspace_directory', {
            'p_actor': actor, 'p_action': action, 'p_data': data,
        }).execute().data
    except APIError as exc:
        errors = {'42501': (403, 'You do not have permission. Access requests require a confirmed email.'),
                  'P0002': (404, 'This inventory or request is unavailable.'),
                  '23514': (409, 'Access or workspace membership changed, or this request expired. Refresh and try again.'),
                  '23505': (409, 'A request is already pending.'),
                  '23503': (409, 'This workspace or inventory is no longer available.')}
        if exc.code in errors:
            status, message = errors[exc.code]
            raise HTTPException(status, message) from None
        raise
    if saved is None:
        raise HTTPException(503, 'The result could not be confirmed. Refresh before retrying.')
    return saved


class DirectorySettings(BaseModel):
    directory_visibility: Literal['workspace', 'hidden']
    description: str = Field(default='', max_length=500)


class RequestDecision(BaseModel):
    action: Literal['approve', 'decline', 'cancel']


@router.get('/inventory-workspaces/{workspace_id}/directory')
def inventory_directory(workspace_id: str, response: Response, q: str = Query('', max_length=100),
                        offset: int = Query(0, ge=0), user: AuthenticatedUser = Depends(get_current_user)):
    workspace = _workspace(workspace_id, user.user_id)
    response.headers['Cache-Control'] = 'no-store'
    result = directory_rpc(user.user_id, 'list', {'workspace_id': workspace_id, 'query': q.strip(), 'offset': offset})
    return {'workspace': workspace, **result}


@router.get('/inventory-directory/{inventory_id}')
def directory_entry(inventory_id: UUID, response: Response, user: AuthenticatedUser = Depends(get_current_user)):
    response.headers['Cache-Control'] = 'no-store'
    result = directory_rpc(user.user_id, 'entry', {'inventory_id': str(inventory_id)})
    return {**result, 'workspace': _workspace(result['inventory']['workspace_id'], user.user_id)}


@router.patch('/inventory-directory/{inventory_id}')
def update_directory(inventory_id: UUID, body: DirectorySettings, user: AuthenticatedUser = Depends(get_current_user)):
    return {'inventory': directory_rpc(user.user_id, 'settings', {'inventory_id': str(inventory_id), **body.model_dump()})}


@router.post('/inventory-directory/{inventory_id}/request')
def request_access(inventory_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return {'request': directory_rpc(user.user_id, 'request', {'inventory_id': str(inventory_id)})}


@router.get('/inventory-workspaces/{workspace_id}/access-requests')
def pending_requests(workspace_id: UUID, response: Response, user: AuthenticatedUser = Depends(get_current_user)):
    response.headers['Cache-Control'] = 'no-store'
    return {'requests': directory_rpc(user.user_id, 'requests', {'workspace_id': str(workspace_id)})}


@router.post('/inventory-access-requests/{request_id}/decision')
def decide_request(request_id: UUID, body: RequestDecision, user: AuthenticatedUser = Depends(get_current_user)):
    return {'request': directory_rpc(user.user_id, body.action, {'request_id': str(request_id)})}

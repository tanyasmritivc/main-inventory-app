"""Human-only decisions. This router never accepts API-key authentication."""
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response
from postgrest.exceptions import APIError
from pydantic import Field

from app.api.routes.api_v1 import APIModel
from app.api.routes.agent_management import database_error
from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_raw

router = APIRouter(prefix='/agent-approvals', tags=['agent-approvals'])


@router.get('/{approval_id}')
def preview(approval_id: UUID, response: Response, user: AuthenticatedUser = Depends(get_current_user)):
    response.headers['Cache-Control'] = 'no-store'
    rows = get_supabase_raw().table('api_agent_delete_approvals').select(
        'id,key_id,kind,resource_id,preview,status,created_at,expires_at,receipt').eq(
            'id', str(approval_id)).eq('actor_id', user.user_id).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, 'This request is unavailable. Sign in as the person who created the API key.')
    result = rows[0]
    result['preview'].pop('fingerprint', None)
    keys = get_supabase_raw().table('api_keys').select('name,revoked_at').eq('id', result['key_id']).execute().data or []
    result['key_name'] = keys[0]['name'] if keys else 'Unavailable key'
    result['key_revoked'] = bool(not keys or keys[0].get('revoked_at'))
    return result


class ApprovalDecision(APIModel):
    decision: Literal['confirm', 'cancel']
    name: str = Field(default='', max_length=200)


@router.post('/{approval_id}/decision')
def decide(approval_id: UUID, body: ApprovalDecision, response: Response, background_tasks: BackgroundTasks,
           user: AuthenticatedUser = Depends(get_current_user)):
    response.headers['Cache-Control'] = 'no-store'
    try:
        result = get_supabase_raw().rpc('findez_agent_confirm_delete', {
            'p_actor': user.user_id, 'p_approval': str(approval_id), 'p_decision': body.decision, 'p_name': body.name,
        }).execute().data
    except APIError as exc:
        if exc.code in ('23514', '40001'):
            raise HTTPException(409, 'This preview expired or its contents changed. Ask the agent to prepare a new preview.') from None
        raise database_error(exc) from None
    if not isinstance(result, dict) or result.get('status') not in ('confirmed', 'cancelled'):
        raise HTTPException(503, 'Your decision could not be confirmed. Refresh before retrying.')
    receipt = result.get('receipt') or {}
    if result['status'] == 'confirmed':
        from app.services.items_repo import invalidate_inventory_cache
        if receipt.get('owner_id'):
            invalidate_inventory_cache(receipt['owner_id'])
        if receipt.get('file_cleanup_id'):
            from app.services.deletion_cleanup import clean_agent_files
            background_tasks.add_task(clean_agent_files, receipt['file_cleanup_id'])
        if receipt.get('inventory_id'):
            from app.services.deletion_cleanup import clean_inventory_files
            background_tasks.add_task(clean_inventory_files, receipt['inventory_id'])
    return result

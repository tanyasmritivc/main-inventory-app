"""Account-only controls; no arbitrary event ingestion or client-selected actor."""
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from app.core.auth import AuthenticatedUser, get_current_user
from app.schemas.personalization import ProfileChange, AliasChange, ResetChange, NotificationFeedback
from app.services.account_memory import actor_id
from app.services.personalization import repository
from app.services.supabase_client import get_supabase_raw

router = APIRouter(prefix='/personalization', tags=['personalization'])


@router.get('')
def read(inventory_id: UUID | None=None, user: AuthenticatedUser=Depends(get_current_user)):
    return repository.read(actor_id(user), inventory_id)


@router.post('')
def settings(body: ProfileChange, user: AuthenticatedUser=Depends(get_current_user)):
    return repository.change(actor_id(user), body, 'settings')


@router.post('/aliases')
def alias(body: AliasChange, user: AuthenticatedUser=Depends(get_current_user)):
    return repository.change(actor_id(user), body, 'alias')


@router.post('/reset')
def reset(body: ResetChange, user: AuthenticatedUser=Depends(get_current_user)):
    return repository.change(actor_id(user), body, 'reset')


@router.get('/notifications/{notification_id}/destination')
def destination(notification_id: UUID, user: AuthenticatedUser=Depends(get_current_user)):
    try:
        result = get_supabase_raw().rpc('findez_personalization_destination', {'p_actor':actor_id(user),'p_id':str(notification_id)}).execute().data
    except Exception: raise HTTPException(503, 'This notification could not be opened. Try again.') from None
    if not result: raise HTTPException(404, 'This item or review is no longer available.')
    from app.api.routes.inventory_workspaces import _inventory
    from app.services.world_chat import in_inventory
    from app.services.supabase_client import get_supabase_admin
    actor = actor_id(user)
    inv = _inventory(result['inventory_id'], actor)
    world = inv['workspace'].get('organization_id') or 'personal'
    with in_inventory(actor, world, result['inventory_id']):
        table, column = ('items', 'item_id') if result['entity_type']=='item' else ('capture_reviews', 'review_id')
        rows = get_supabase_admin().table(table).select('*').eq(column, result['entity_id']).eq('user_id', inv['owner_user_id']).limit(1).execute().data or []
        if not rows: raise HTTPException(404, 'This item or review is no longer available.')
    return {**result, 'inventory':inv, 'resource':rows[0]}


@router.post('/notifications/{notification_id}/feedback')
def feedback(notification_id: UUID, body: NotificationFeedback, user: AuthenticatedUser=Depends(get_current_user)):
    try:
        ok = get_supabase_raw().rpc('findez_personalization_feedback', {'p_actor':actor_id(user), 'p_id':str(notification_id),'p_outcome':body.outcome}).execute().data
    except Exception: raise HTTPException(503, 'Notification feedback could not be saved.') from None
    if ok is not True: raise HTTPException(404, 'This notification is no longer available.')
    return {'saved':True}

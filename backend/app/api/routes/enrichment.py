"""Inventory-bound review APIs. Worker capabilities are never exposed to clients."""
from typing import Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from postgrest.exceptions import APIError
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field, ConfigDict, field_validator
from app.core.auth import AuthenticatedUser, get_current_user
from app.api.routes.inventory_workspaces import _inventory
from app.services.supabase_client import get_supabase_raw
from app.services.enrichment.classification import InventoryRole

router = APIRouter(prefix='/inventories/{inventory_id}/enrichment', tags=['inventory-enrichment'])

class Decision(BaseModel):
    model_config = ConfigDict(extra='forbid')
    ids: list[UUID] = Field(min_length=1, max_length=50)
    decision: Literal['approve', 'reject', 'retry']

class RoleUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    role: InventoryRole

class SettingsUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    timezone: str = Field(max_length=100)
    images_enabled: bool
    @field_validator('timezone')
    @classmethod
    def zone(cls, value):
        try: ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError): raise ValueError('Choose a valid time zone.') from None
        return value


def access(inventory_id, user, edit=False):
    from app.core.config import get_settings
    if not get_settings().findez_inventory_intelligence_enabled:
        raise HTTPException(503, 'Inventory enrichment is not enabled yet.')
    inv = _inventory(str(inventory_id), user.user_id)
    if edit and not inv['can_edit']:
        raise HTTPException(403, 'You have view-only access to this inventory.')
    return inv


def rpc(name, values):
    try:
        return get_supabase_raw().rpc(name, values).execute().data
    except APIError as error:
        if error.code == '42501':
            raise HTTPException(403, 'Your inventory access changed. Refresh before trying again.') from None
        if error.code in ('P0002','23514','23505','22023','22P02'):
            raise HTTPException(409, 'This item or suggestion changed. Refresh before trying again.') from None
        raise HTTPException(503, 'Suggestions could not be saved. Please try again.') from None


@router.get('')
def review(inventory_id: UUID, offset: int = 0, kind: Literal['all','image','classification'] = 'all', user: AuthenticatedUser = Depends(get_current_user)):
    inv = access(inventory_id, user)
    if not 0 <= offset <= 100000:
        raise HTTPException(422, 'Choose a valid page.')
    db = get_supabase_raw()
    query = db.table('app_item_enrichment').select('id,item_id,kind,status,identity,result,due_at,created_at').eq('inventory_id', str(inventory_id)).in_('status', ['queued','processing','ready','no_match','failed']).order('created_at').order('id')
    if kind != 'all': query = query.eq('kind', kind)
    rows = query.range(offset, offset + 20).execute().data or []
    settings = db.table('app_inventory_intelligence_settings').select('timezone,images_enabled').eq('inventory_id', str(inventory_id)).execute().data or []
    output = []
    for row in rows[:20]:
        result = {k: v for k, v in (row.get('result') or {}).items() if k not in ('storage_path', 'image_url', 'source_image_url')}
        output.append({**{k: row[k] for k in ('id','item_id','kind','status','due_at')}, 'name': row['identity'].get('name'), 'result': result,
                       'has_preview': bool((row.get('result') or {}).get('storage_path'))})
    return {'items': output, 'next_offset': offset + 20 if len(rows) > 20 else None,
            'can_edit': inv['can_edit'], 'settings': settings[0] if settings else {'timezone': 'UTC', 'images_enabled': True}}


@router.post('/decisions')
def decide(inventory_id: UUID, body: Decision, user: AuthenticatedUser = Depends(get_current_user)):
    access(inventory_id, user, True)
    return rpc('findez_enrichment_decide', {'p_actor': user.user_id, 'p_inventory': str(inventory_id),
        'p_ids': [str(i) for i in body.ids], 'p_decision': body.decision})


@router.put('/items/{item_id}/classification')
def classify(inventory_id: UUID, item_id: UUID, body: RoleUpdate, user: AuthenticatedUser = Depends(get_current_user)):
    access(inventory_id, user, True)
    return rpc('findez_intelligence_config', {'p_actor': user.user_id, 'p_inventory': str(inventory_id),
        'p_operation': 'role', 'p_value': {'item_id': str(item_id), 'role': body.role}})


@router.put('/settings')
def settings(inventory_id: UUID, body: SettingsUpdate, user: AuthenticatedUser = Depends(get_current_user)):
    access(inventory_id, user, True)
    return rpc('findez_intelligence_config', {'p_actor': user.user_id, 'p_inventory': str(inventory_id),
        'p_operation': 'settings', 'p_value': body.model_dump()})


@router.get('/{job_id}/image')
def image(inventory_id: UUID, job_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    access(inventory_id, user)
    db = get_supabase_raw()
    rows = db.table('app_item_enrichment').select('result,item_id').eq('id', str(job_id)).eq('inventory_id', str(inventory_id)).eq('status', 'ready').execute().data or []
    if not rows:
        raise HTTPException(404, 'This suggestion is no longer available.')
    # A moved item cannot retain an image preview in its old organization.
    items = db.table('items').select('item_id').eq('item_id', rows[0]['item_id']).eq('inventory_id', str(inventory_id)).execute().data or []
    path = rows[0]['result'].get('storage_path')
    if not items or not path:
        raise HTTPException(404, 'This suggestion is no longer available.')
    from app.core.config import get_settings
    content = db.storage.from_(get_settings().supabase_storage_bucket).download(path)
    return Response(content, media_type='image/jpeg', headers={'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff'})

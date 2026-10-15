"""Workspace selection and an authorized boundary around existing inventory APIs."""

import asyncio
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.inventory_scope import InventoryScope, current_inventory
from app.services.supabase_client import get_supabase_raw
from app.services.teams_repo import list_user_teams


router = APIRouter(tags=['inventory-workspaces'])


def _workspace(workspace_id, actor_id):
    if workspace_id == 'personal':
        return {'workspace_id': 'personal', 'name': 'Personal', 'kind': 'personal', 'owner_user_id': actor_id, 'team_id': None, 'role': 'owner'}
    try:
        workspace_id = str(UUID(workspace_id))
    except ValueError:
        raise HTTPException(404, 'Workspace not found.')
    client = get_supabase_raw()
    members = client.table('team_memberships').select('role').eq('team_id', workspace_id).eq('user_id', actor_id).limit(1).execute().data or []
    if not members:
        raise HTTPException(403, 'You do not have access to this workspace.')
    teams = client.table('teams').select('team_id,name,owner_user_id').eq('team_id', workspace_id).limit(1).execute().data or []
    if not teams:
        raise HTTPException(404, 'Workspace not found.')
    return {'workspace_id': workspace_id, 'kind': 'team', 'team_id': workspace_id, 'name': teams[0]['name'], 'owner_user_id': teams[0]['owner_user_id'], 'role': members[0]['role']}


def _inventory(inventory_id, actor_id):
    try:
        inventory_id = str(UUID(inventory_id))
    except ValueError:
        raise HTTPException(404, 'Inventory not found.')
    rows = get_supabase_raw().table('app_inventories').select('*').eq('inventory_id', inventory_id).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, 'Inventory not found.')
    inventory = rows[0]
    workspace = _workspace(inventory.get('team_id') or 'personal', actor_id)
    if inventory['owner_user_id'] != workspace['owner_user_id']:
        raise HTTPException(403, 'You do not have access to this inventory.')
    return {**inventory, 'workspace': workspace, 'can_edit': workspace['role'] in ('owner', 'mentor', 'member')}


@router.get('/inventory-workspaces')
def list_inventory_workspaces(user: AuthenticatedUser = Depends(get_current_user)):
    workspaces = [_workspace('personal', user.user_id)]
    workspaces += [{'workspace_id': team['team_id'], 'team_id': team['team_id'], 'kind': 'team', 'name': team['name'], 'owner_user_id': team['owner_user_id'], 'role': team['role']} for team in list_user_teams(user_id=user.user_id)]
    return {'workspaces': workspaces}


@router.get('/inventory-workspaces/{workspace_id}/inventories')
def list_workspace_inventories(workspace_id: str, q: str = Query('', max_length=100), offset: int = Query(0, ge=0), user: AuthenticatedUser = Depends(get_current_user)):
    workspace = _workspace(workspace_id, user.user_id)
    client = get_supabase_raw()
    query = client.table('app_inventory_summaries').select('*', count='exact').eq('owner_user_id', workspace['owner_user_id'])
    query = query.eq('team_id', workspace['team_id']) if workspace['team_id'] else query.is_('team_id', 'null')
    if q.strip():
        query = query.ilike('name', f'%{q.strip()}%')
    result = query.order('created_at').order('inventory_id').range(offset, offset + 99).execute()
    inventories = result.data or []
    total = result.count if result.count is not None else len(inventories)
    return {'workspace': workspace, 'inventories': inventories, 'total': total, 'next_offset': offset + len(inventories) if offset + len(inventories) < total else None}


class NewInventory(BaseModel):
    name: str = Field(min_length=1, max_length=100)


@router.post('/inventory-workspaces/{workspace_id}/inventories')
def create_workspace_inventory(workspace_id: str, body: NewInventory, user: AuthenticatedUser = Depends(get_current_user)):
    workspace = _workspace(workspace_id, user.user_id)
    if workspace['role'] not in ('owner', 'mentor'):
        raise HTTPException(403, 'Only a workspace owner or manager can create inventories.')
    name = body.name.strip()
    if not name:
        raise HTTPException(422, 'Enter an inventory name.')
    row = {'name': name, 'owner_user_id': workspace['owner_user_id'], 'team_id': workspace['team_id'], 'created_by_user_id': user.user_id}
    saved = get_supabase_raw().table('app_inventories').insert(row).execute().data or []
    if not saved:
        raise HTTPException(503, 'This inventory could not be confirmed saved. Refresh before trying again.')
    return {'inventory': {**saved[0], 'workspace': workspace, 'can_edit': True}}


@router.get('/inventories/{inventory_id}')
def get_inventory(inventory_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return {'inventory': _inventory(inventory_id, user.user_id)}


async def inventory_session(request: Request, inventory_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    actor = user.user_id
    inventory = await asyncio.to_thread(_inventory, inventory_id, actor)
    workspace = inventory['workspace']
    scope = InventoryScope(inventory['inventory_id'], actor, inventory['owner_user_id'], inventory.get('team_id'), workspace['role'])
    suffix = request.url.path.split(f'/inventories/{inventory_id}', 1)[-1]
    read_posts = ('/search_items', '/ai_command', '/ai_photo_question', '/ai_upload', '/process_barcode', '/barcode_lookup', '/inventory/bom/analyze', '/eezy/chat')
    if not scope.can_edit and request.method not in ('GET', 'HEAD', 'OPTIONS') and suffix not in read_posts and not suffix.startswith('/conversations'):
        raise HTTPException(403, 'You have view-only access to this inventory.')
    token = current_inventory.set(scope)
    # Legacy inventory services receive their effective owner, while the actor
    # remains independently verified for membership, private chats and auditing.
    user.user_id, user.actor_id = scope.owner_id, actor
    try:
        yield scope
    finally:
        user.user_id = actor
        current_inventory.reset(token)


scoped_router = APIRouter(prefix='/inventories/{inventory_id}', dependencies=[Depends(inventory_session)])

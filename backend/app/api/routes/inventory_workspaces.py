"""Workspace selection and an authorized boundary around existing inventory APIs."""

import asyncio
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field, StrictBool, field_validator

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.inventory_scope import InventoryScope, current_inventory
from app.services.supabase_client import get_supabase_raw
from postgrest.exceptions import APIError
from app.services.teams_repo import list_user_teams
from app.services import permissions


router = APIRouter(tags=['inventory-workspaces'])


def _workspace(workspace_id, actor_id):
    if workspace_id == 'personal':
        return {'workspace_id': 'personal', 'name': 'Personal', 'kind': 'personal', 'owner_user_id': actor_id, 'team_id': None, 'role': 'owner'}
    try:
        workspace_id = str(UUID(workspace_id))
    except ValueError:
        raise HTTPException(404, 'Workspace not found.')
    client = get_supabase_raw()
    membership = permissions.workspace_membership(client, workspace_id, actor_id)
    teams = client.table('teams').select('team_id,name,owner_user_id,organization_id').eq('team_id', workspace_id).limit(1).execute().data or []
    if not teams:
        raise HTTPException(404, 'Workspace not found.')
    if teams[0].get('organization_id') and not (client.table('app_organization_members').select('role').eq('organization_id', teams[0]['organization_id']).eq('user_id', actor_id).limit(1).execute().data or []):
        raise HTTPException(403, 'Organization membership is required for this workspace.')
    orgs = client.table('app_organizations').select('name').eq('organization_id', teams[0]['organization_id']).execute().data if teams[0].get('organization_id') else []
    return {'workspace_id': workspace_id, 'kind': 'team', 'team_id': workspace_id, 'name': teams[0]['name'], 'owner_user_id': teams[0]['owner_user_id'], 'role': membership['role'], 'organization_role': membership.get('organization_role'), 'organization_id': teams[0].get('organization_id'), 'organization_name': orgs[0]['name'] if orgs else None}


def _inventory(inventory_id, actor_id, *, administration=False):
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
    role = inventory_role(inventory, workspace, actor_id)
    can_manage = permissions.can_administer_inventory(inventory, workspace, role)
    if role is None and not (administration and can_manage):
        raise HTTPException(403, 'You do not have access to this inventory.')
    return {**inventory, 'workspace': workspace, 'role': role,
            'can_open': role is not None,
            'can_edit': role in permissions.EDIT_ROLES,
            'can_delete_space': role in permissions.ADMIN_ROLES,
            'can_rename': permissions.can_rename_inventory(inventory, workspace, role), 'can_manage': can_manage}


def inventory_role(inventory, workspace, actor_id, grants=None):
    if grants is None:
        grants = get_supabase_raw().table('app_inventory_members').select('inventory_id,role').eq('inventory_id', inventory['inventory_id']).eq('user_id', actor_id).execute().data or []
    return permissions.inventory_role(inventory, workspace, actor_id, grants)


def can_rename_inventory(inventory, workspace, actor_id, grants=()):
    return permissions.can_rename_inventory(inventory, workspace, inventory_role(inventory, workspace, actor_id, grants))



@router.get('/inventory-workspaces')
def list_inventory_workspaces(user: AuthenticatedUser = Depends(get_current_user)):
    workspaces = [_workspace('personal', user.user_id)]
    workspaces += [{'workspace_id': team['team_id'], 'team_id': team['team_id'], 'kind': 'team', 'name': team['name'], 'owner_user_id': team['owner_user_id'], 'role': team['role'], 'organization_role': team.get('organization_role'), 'organization_id': team.get('organization_id')} for team in list_user_teams(user_id=user.user_id)]
    return {'workspaces': workspaces}


@router.get('/inventory-workspaces/{workspace_id}/inventories')
def list_workspace_inventories(workspace_id: str, q: str = Query('', max_length=100), offset: int = Query(0, ge=0), user: AuthenticatedUser = Depends(get_current_user)):
    workspace = _workspace(workspace_id, user.user_id)
    client = get_supabase_raw()
    query = client.table('app_inventory_summaries').select('*', count='exact').eq('owner_user_id', workspace['owner_user_id'])
    query = query.eq('team_id', workspace['team_id']) if workspace['team_id'] else query.is_('team_id', 'null')
    grants = client.table('app_inventory_members').select('inventory_id,role').eq('user_id', user.user_id).execute().data or []
    if workspace['role'] not in ('owner', 'mentor'):
        allowed = [row['inventory_id'] for row in grants if row['role'] != 'none']
        denied = [row['inventory_id'] for row in grants if row['role'] == 'none']
        query = query.or_('access_mode.neq.restricted' + (',inventory_id.in.(' + ','.join(allowed) + ')' if allowed else ''))
        if denied:
            query = query.not_.in_('inventory_id', denied)
    if q.strip():
        query = query.ilike('name', f'%{q.strip()}%')
    result = query.order('created_at').order('inventory_id').range(offset, offset + 99).execute()
    inventories = result.data or []
    total = result.count if result.count is not None else len(inventories)
    visible = []
    for inv in inventories:
        role = inventory_role(inv, workspace, user.user_id, grants)
        can_manage = permissions.can_administer_inventory(inv, workspace, role)
        if role is None and not can_manage:
            continue
        row = {**inv, 'role': role, 'can_open': role is not None,
               'can_edit': role in permissions.EDIT_ROLES,
               'can_rename': permissions.can_rename_inventory(inv, workspace, role), 'can_manage': can_manage}
        if role is None:
            row.pop('item_count', None)
        visible.append(row)
    return {'workspace': workspace, 'inventories': visible, 'total': total, 'next_offset': offset + len(inventories) if offset + len(inventories) < total else None}


class NewInventory(BaseModel):
    name: str = Field(min_length=1, max_length=100)

    @field_validator('name', mode='before')
    @classmethod
    def trim_name(cls, value):
        return value.strip() if isinstance(value, str) else value


class CreateInventory(NewInventory):
    access_mode: Literal['workspace', 'restricted'] = 'workspace'


@router.patch('/inventory-workspaces/{workspace_id}')
def rename_workspace(workspace_id: UUID, body: NewInventory, user: AuthenticatedUser = Depends(get_current_user)):
    workspace = _workspace(str(workspace_id), user.user_id)
    if permissions.workspace_role(workspace['role']) not in permissions.EDIT_ROLES:
        raise HTTPException(403, 'You have view-only access to this workspace.')
    query = get_supabase_raw().table('teams').update({'name': body.name}).eq('team_id', str(workspace_id))
    query.headers = {**query.headers, 'x-findez-actor': user.user_id}
    try:
        rows = query.execute().data or []
    except APIError as exc:
        if exc.code == '42501':
            raise HTTPException(403, 'Your permission changed. Refresh and try again.') from None
        raise
    if not rows:
        raise HTTPException(409, 'The workspace changed. Refresh before trying again.')
    return {'workspace': {**workspace, 'name': rows[0]['name']}}


@router.post('/inventory-workspaces/{workspace_id}/inventories')
def create_workspace_inventory(workspace_id: str, body: CreateInventory, user: AuthenticatedUser = Depends(get_current_user)):
    workspace = _workspace(workspace_id, user.user_id)
    if workspace['role'] not in ('owner', 'mentor'):
        raise HTTPException(403, 'Only a workspace owner or manager can create inventories.')
    name = body.name.strip()
    if not name:
        raise HTTPException(422, 'Enter an inventory name.')
    try:
        saved = get_supabase_raw().rpc('findez_create_inventory', {
            'p_actor': user.user_id, 'p_workspace': workspace['team_id'],
            'p_name': name, 'p_mode': body.access_mode,
        }).execute().data
    except APIError as exc:
        if exc.code == '23505':
            raise HTTPException(409, 'An inventory with this name already exists. Refresh or choose another name.')
        raise
    if not isinstance(saved, dict) or not saved.get('inventory_id') or saved.get('team_id') != workspace['team_id'] or saved.get('access_mode') != body.access_mode:
        raise HTTPException(503, 'This inventory could not be confirmed saved. Refresh before trying again.')
    return {'inventory': _inventory(saved['inventory_id'], user.user_id)}


@router.get('/inventories/{inventory_id}')
def get_inventory(inventory_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return {'inventory': _inventory(inventory_id, user.user_id)}


@router.patch('/inventories/{inventory_id}')
def rename_inventory(inventory_id: str, body: NewInventory, user: AuthenticatedUser = Depends(get_current_user)):
    inventory = _inventory(inventory_id,user.user_id,administration=True)
    if not inventory['can_rename']:
        raise HTTPException(403,'Only inventory owners, admins or workspace administrators can rename it.')
    if not body.name.strip():
        raise HTTPException(422,'Enter an inventory name.')
    try:
        query = get_supabase_raw().table('app_inventories').update({'name':body.name.strip()}).eq('inventory_id',inventory['inventory_id'])
        query.headers = {**query.headers, 'x-findez-actor': user.user_id}
        rows = query.execute().data or []
    except APIError as exc:
        if exc.code == '23505':
            raise HTTPException(409,'An inventory with this name already exists.')
        if exc.code == '42501':
            raise HTTPException(403,'Your permission to manage this inventory changed.') from None
        if exc.code in ('40P01','40001'):
            raise HTTPException(409,'This inventory is being updated. Refresh and try again.') from None
        raise
    if not rows:
        raise HTTPException(404,'Inventory not found.')
    return {'inventory':rows[0]}


class ConfirmInventoryDelete(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    delete_contents: StrictBool = False

    model_config = {'extra': 'forbid'}


@router.delete('/inventories/{inventory_id}')
def delete_empty_inventory(inventory_id: UUID, body: ConfirmInventoryDelete, background_tasks: BackgroundTasks,
                           user: AuthenticatedUser = Depends(get_current_user)):
    inventory = _inventory(str(inventory_id), user.user_id, administration=True)
    if not inventory['can_manage']:
        raise HTTPException(403, 'Only an inventory owner or admin can delete it.')
    try:
        result = get_supabase_raw().rpc('findez_delete_inventory_contents' if body.delete_contents else 'findez_delete_empty_inventory', {
            'p_actor': user.user_id, 'p_inventory': str(inventory_id), 'p_name': body.name,
        }).execute().data
    except APIError as exc:
        errors = {
            '42501': (403, 'Your inventory access changed. Refresh before trying again.'),
            'P0002': (404, 'This inventory is no longer available.'),
            '22023': (409, 'The inventory name changed. Refresh and type its current name.'),
            '23514': (409, 'This inventory has linked records in another inventory or an unsupported dependency. Resolve those links before deleting everything.' if body.delete_contents else 'This inventory contains saved records. Move or remove them before deleting it.'),
            '23503': (409, 'This inventory has linked records and cannot be deleted.'),
            '23505': (409, 'The workspace changed. Refresh before trying again.'),
            '40P01': (409, 'The workspace changed. Refresh before trying again.'),
            'PGRST202': (503, 'Inventory deletion is not available yet. Please try again later.'),
        }
        if exc.code in errors:
            status, message = errors[exc.code]
            raise HTTPException(status, message) from None
        raise
    if not isinstance(result, dict) or result.get('deleted') is not True or result.get('inventory_id') != str(inventory_id):
        raise HTTPException(503, 'Deletion could not be confirmed. Refresh before retrying.')
    from app.services.items_repo import invalidate_inventory_cache
    invalidate_inventory_cache(inventory['owner_user_id'])
    if body.delete_contents or result.get('file_cleanup_pending') is True:
        from app.services.deletion_cleanup import clean_inventory_files
        background_tasks.add_task(clean_inventory_files, str(inventory_id))
        result['file_cleanup_pending'] = True
    return result


class MoveSpace(BaseModel):
    inventory_id: UUID


@router.post('/inventories/{inventory_id}/spaces/{space_id}/move')
def move_space(inventory_id: str, space_id: UUID, body: MoveSpace, user: AuthenticatedUser = Depends(get_current_user)):
    source = _inventory(inventory_id,user.user_id)
    target = _inventory(str(body.inventory_id),user.user_id)
    if source.get('team_id') != target.get('team_id'):
        raise HTTPException(422,'Choose an inventory in the same workspace.')
    if not source['can_edit'] or not target['can_edit']:
        raise HTTPException(403,'You have view-only access to this inventory.')
    client = get_supabase_raw()
    if not (client.table('spaces').select('id').eq('id',str(space_id)).eq('inventory_id',source['inventory_id']).limit(1).execute().data or []):
        raise HTTPException(404,'This Space is not in the selected inventory.')
    try:
        client.rpc('findez_move_inventory_space',{'p_space':str(space_id),'p_inventory':target['inventory_id']}).execute()
    except APIError as exc:
        if exc.code == '23505':
            raise HTTPException(409,'The destination already has a Space with this name. Rename one before moving it.')
        if exc.code == '23514':
            raise HTTPException(409,'This Space has linked project allocations or reviews. Resolve those links before moving it.')
        raise
    from app.services.items_repo import invalidate_inventory_cache
    invalidate_inventory_cache(source['owner_user_id'])
    return {'moved':True,'inventory_id':target['inventory_id']}


async def inventory_session(request: Request, inventory_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    actor = user.user_id
    previous_actor = user.actor_id
    inventory = await asyncio.to_thread(_inventory, inventory_id, actor)
    workspace = inventory['workspace']
    scope = InventoryScope(inventory['inventory_id'], actor, inventory['owner_user_id'], inventory.get('team_id'), inventory['role'])
    suffix = request.url.path.split(f'/inventories/{inventory_id}', 1)[-1]
    if scope.team_id and suffix.startswith('/sharing'):
        raise HTTPException(403,'Invite people through workspace settings to share team inventory.')
    read_posts = ('/search_items', '/ai_command', '/ai_photo_question', '/ai_upload', '/process_barcode', '/barcode_lookup', '/inventory/bom/analyze', '/eezy/chat')
    preview = False
    if not scope.can_edit and suffix in ('/extract_from_image', '/inventory/extract_from_image'):
        form = await request.form()
        preview = str(form.get('preview_only', '')).lower() in ('true', '1')
    if not scope.can_edit and request.method not in ('GET', 'HEAD', 'OPTIONS') and suffix not in read_posts and not suffix.startswith('/conversations') and not suffix.startswith('/ai_actions/') and not preview:
        raise HTTPException(403, 'You have view-only access to this inventory.')
    token = current_inventory.set(scope)
    # Legacy inventory services receive their effective owner, while the actor
    # remains independently verified for membership, private chats and auditing.
    user.user_id, user.actor_id = scope.owner_id, actor
    try:
        yield scope
    finally:
        user.user_id = actor
        user.actor_id = previous_actor
        current_inventory.reset(token)


scoped_router = APIRouter(prefix='/inventories/{inventory_id}', dependencies=[Depends(inventory_session)])

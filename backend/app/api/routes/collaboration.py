"""Organization administration and inventory-specific access, backed by audited RPCs."""
from uuid import UUID
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from postgrest.exceptions import APIError

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_raw
from app.api.routes.inventory_workspaces import _workspace, _inventory, inventory_role
from app.services.access_invitations import invite_or_change

router = APIRouter(tags=['collaboration'])


def manage(actor, action, data):
    try:
        result = get_supabase_raw().rpc('findez_manage_collaboration', {
            'p_actor': actor, 'p_action': action, 'p_data': data,
        }).execute().data
    except APIError as exc:
        messages = {'42501': (403, 'You do not have permission to make this change.'),
                    'P0002': (404, 'Record not found. New members need an existing FindEZ account.'),
                    '23505': (409, 'This name or assignment already exists.'),
                    '23514': (422, 'Check the member, role and parent workspace. Remove workspace assignments before removing organization membership.'),
                    '23503': (422, 'Choose an existing member or location.')}
        if exc.code in messages:
            status, message = messages[exc.code]
            raise HTTPException(status, message)
        raise
    if not result:
        raise HTTPException(503, 'The change could not be confirmed saved. Refresh before retrying.')
    return result


def organization(org_id, actor):
    raw = get_supabase_raw()
    rows = raw.table('app_organization_members').select('role').eq('organization_id', str(org_id)).eq('user_id', actor).execute().data or []
    if not rows:
        raise HTTPException(403, 'You do not have access to this organization.')
    orgs = raw.table('app_organizations').select('*').eq('organization_id', str(org_id)).execute().data or []
    if not orgs:
        raise HTTPException(404, 'Organization not found.')
    return {**orgs[0], 'role': rows[0]['role']}


def members_with_names(rows):
    ids = list({r['user_id'] for r in rows})
    profiles = get_supabase_raw().table('profiles').select('id,display_name,first_name,last_name').in_('id', ids).execute().data if ids else []
    names = {p['id']: p.get('display_name') or ' '.join(filter(None, [p.get('first_name'), p.get('last_name')])) or 'Member' for p in profiles or []}
    return [{**r, 'display_name': names.get(r['user_id'], 'Member')} for r in rows]


class Name(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class OrganizationMember(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    role: Literal['member', 'admin'] = 'member'


class Role(BaseModel):
    role: Literal['admin', 'editor', 'viewer', 'none', 'inherit']


class Policy(BaseModel):
    access_mode: Literal['workspace', 'restricted']
    default_role: Literal['viewer', 'editor'] = 'viewer'


class Location(Name):
    parent_id: UUID | None = None


class AttachLocation(BaseModel):
    location_id: UUID


@router.get('/organizations')
def organizations(user: AuthenticatedUser = Depends(get_current_user)):
    raw = get_supabase_raw()
    memberships = raw.table('app_organization_members').select('organization_id,role').eq('user_id', user.user_id).execute().data or []
    ids = [m['organization_id'] for m in memberships]
    rows = raw.table('app_organizations').select('*').in_('organization_id', ids).order('name').execute().data if ids else []
    roles = {m['organization_id']: m['role'] for m in memberships}
    return {'organizations': [{**r, 'role': roles[r['organization_id']]} for r in rows or []]}


@router.post('/organizations')
def create_organization(body: Name, user: AuthenticatedUser = Depends(get_current_user)):
    return {'organization': manage(user.user_id, 'organization_create', body.model_dump())}


@router.get('/organizations/{organization_id}')
def organization_overview(organization_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    org = organization(organization_id, user.user_id)
    raw = get_supabase_raw()
    # Even organization owners see workspace data only when explicitly assigned.
    memberships = raw.table('team_memberships').select('team_id,role').eq('user_id', user.user_id).execute().data or []
    ids = [m['team_id'] for m in memberships]
    workspaces = raw.table('teams').select('team_id,name,organization_id').eq('organization_id', str(organization_id)).in_('team_id', ids).order('name').execute().data if ids else []
    members = raw.table('app_organization_members').select('user_id,role').eq('organization_id', str(organization_id)).execute().data or []
    attachable = raw.table('teams').select('team_id,name').eq('owner_user_id', user.user_id).is_('organization_id', 'null').execute().data if org['role'] in ('owner', 'admin') else []
    return {'organization': org, 'workspaces': workspaces or [], 'members': members_with_names(members), 'attachable': attachable or []}


@router.post('/organizations/{organization_id}/members')
def add_organization_member(organization_id: UUID, body: OrganizationMember, user: AuthenticatedUser = Depends(get_current_user)):
    return invite_or_change(user.user_id, 'organization', str(organization_id), body.role, email=body.email)


@router.delete('/organizations/{organization_id}/members/{member_id}')
def remove_organization_member(organization_id: UUID, member_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return manage(user.user_id, 'organization_member', {'organization_id': str(organization_id), 'user_id': str(member_id), 'role': 'none'})


@router.post('/organizations/{organization_id}/workspaces')
def create_project(organization_id: UUID, body: Name, user: AuthenticatedUser = Depends(get_current_user)):
    return {'workspace': manage(user.user_id, 'workspace_create', {**body.model_dump(), 'organization_id': str(organization_id)})}


@router.put('/inventory-workspaces/{workspace_id}/members/{member_id}')
def assign_workspace_member(workspace_id: UUID, member_id: UUID, body: Role, user: AuthenticatedUser = Depends(get_current_user)):
    return invite_or_change(user.user_id, 'workspace', str(workspace_id), body.role, member_id=str(member_id))


@router.get('/inventory-workspaces/{workspace_id}/overview')
def workspace_overview(workspace_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    workspace = _workspace(str(workspace_id), user.user_id)
    raw = get_supabase_raw()
    members = raw.table('team_memberships').select('user_id,role').eq('team_id', str(workspace_id)).execute().data or []
    candidates = []
    if workspace.get('organization_id') and workspace['role'] in ('owner', 'mentor'):
        candidates = raw.table('app_organization_members').select('user_id,role').eq('organization_id', workspace['organization_id']).execute().data or []
    # Physical location library is administration-only; inventory users see only
    # explicit attachments through the scoped Spaces route.
    locations = raw.table('app_physical_locations').select('*').eq('team_id', str(workspace_id)).order('created_at').execute().data if workspace['role'] in ('owner','mentor') else []
    return {'workspace': workspace, 'members': members_with_names(members), 'candidates': members_with_names(candidates), 'locations': locations or []}


@router.get('/inventories/{inventory_id}/access')
def inventory_access(inventory_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    inv = _inventory(str(inventory_id), user.user_id)
    if not inv.get('team_id'):
        return {'inventory': inv, 'members': [{'user_id': user.user_id, 'role': 'owner', 'source': 'personal', 'display_name': 'You'}], 'candidates': [], 'locations': []}
    raw = get_supabase_raw()
    members = raw.table('team_memberships').select('user_id,role').eq('team_id', inv['team_id']).execute().data or []
    grants = raw.table('app_inventory_members').select('user_id,inventory_id,role').eq('inventory_id', str(inventory_id)).execute().data or []
    effective = []
    for member in members:
        override = next((g for g in grants if g['user_id'] == member['user_id']), None)
        role = inventory_role(inv, {**inv['workspace'], 'role': member['role']}, member['user_id'], [override] if override else [])
        if role or inv['can_manage']:
            effective.append({**member, 'workspace_role': member['role'], 'role': role or 'none',
                'override': override['role'] if override else 'inherit', 'source': 'inventory' if override else 'workspace'})
    locations = raw.table('app_physical_locations').select('*').eq('team_id', inv['team_id']).order('created_at').execute().data if inv['can_manage'] else []
    return {'inventory': inv, 'members': members_with_names(effective), 'locations': locations or []}


@router.patch('/inventories/{inventory_id}/access')
def change_policy(inventory_id: UUID, body: Policy, user: AuthenticatedUser = Depends(get_current_user)):
    return manage(user.user_id, 'inventory_policy', {**body.model_dump(), 'inventory_id': str(inventory_id)})


@router.put('/inventories/{inventory_id}/access/{member_id}')
def change_inventory_member(inventory_id: UUID, member_id: UUID, body: Role, user: AuthenticatedUser = Depends(get_current_user)):
    return invite_or_change(user.user_id, 'inventory', str(inventory_id), body.role, member_id=str(member_id))


@router.get('/inventories/{inventory_id}/audit')
def inventory_audit(inventory_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    _inventory(str(inventory_id), user.user_id)
    rows = get_supabase_raw().table('app_access_audit').select('*').eq('inventory_id', str(inventory_id)).order('created_at', desc=True).limit(100).execute().data or []
    return {'activity': rows}


@router.post('/inventory-workspaces/{workspace_id}/locations')
def create_location(workspace_id: UUID, body: Location, user: AuthenticatedUser = Depends(get_current_user)):
    return {'location': manage(user.user_id, 'location_create', {**body.model_dump(mode='json'), 'team_id': str(workspace_id)})}


@router.post('/inventories/{inventory_id}/locations')
def attach_location(inventory_id: UUID, body: AttachLocation, user: AuthenticatedUser = Depends(get_current_user)):
    return {'space': manage(user.user_id, 'location_attach', {**body.model_dump(mode='json'), 'inventory_id': str(inventory_id)})}


@router.post('/organizations/{organization_id}/workspaces/{workspace_id}')
def attach_workspace(organization_id: UUID, workspace_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return manage(user.user_id, 'workspace_attach', {'organization_id': str(organization_id), 'team_id': str(workspace_id)})


@router.get('/inventory-workspaces/{workspace_id}/audit')
def workspace_audit(workspace_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    workspace = _workspace(str(workspace_id), user.user_id)
    raw = get_supabase_raw()
    rows = raw.table('app_access_audit').select('*').eq('team_id', str(workspace_id)).order('created_at', desc=True).limit(100).execute().data or []
    visible = []
    for row in rows:
        if row.get('inventory_id'):
            try:
                _inventory(row['inventory_id'], user.user_id)
            except HTTPException as exc:
                if exc.status_code in (403, 404):
                    continue
                raise
        visible.append(row)
    return {'activity': visible}

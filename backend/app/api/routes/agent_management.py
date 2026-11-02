"""Organization-bound delegation. Inventory reads retain existing user permissions."""
import base64
import hashlib
import hmac
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from postgrest.exceptions import APIError
from pydantic import Field, model_validator

from app.api.routes.api_v1 import APIModel
from app.api.routes import collaboration, inventory_workspaces
from app.core.api_key_auth import APIKeyPrincipal, api_error, require_api_scope
from app.core.auth import AuthenticatedUser
from app.core.config import get_settings
from app.services.supabase_client import get_supabase_raw

router = APIRouter(prefix='/api/v1/organization', tags=['agent-management'])
Kind = Literal['organization', 'workspace', 'inventory', 'space']


def organization_key(principal):
    if not principal.organization_id:
        raise HTTPException(403, 'Issue a key for a specific organization to use management actions. Existing keys retain inventory-only access.')
    return principal


def bound(principal, kind, resource_id, *, administration=False):
    """No personal or unattached workspace can enter an organization-key request."""
    organization_key(principal)
    resource_id = str(resource_id)
    raw = get_supabase_raw()
    actor = principal.org_id
    if kind == 'organization':
        if resource_id != principal.organization_id:
            raise HTTPException(403, 'This resource is outside the key organization.')
        return collaboration.organization(resource_id, actor)
    if kind == 'workspace':
        rows = raw.table('teams').select('organization_id').eq('team_id', resource_id).limit(1).execute().data or []
        if not rows or rows[0].get('organization_id') != principal.organization_id:
            raise HTTPException(404, 'Workspace not found in this organization.')
        return inventory_workspaces._workspace(resource_id, actor)
    if kind == 'space':
        rows = raw.table('spaces').select('id,name,inventory_id').eq('id', resource_id).limit(1).execute().data or []
        if not rows:
            raise HTTPException(404, 'Space not found.')
        return {**rows[0], 'inventory': bound(principal, 'inventory', rows[0]['inventory_id'], administration=administration)}
    if kind == 'inventory':
        rows = raw.table('app_inventories').select('team_id').eq('inventory_id', resource_id).limit(1).execute().data or []
        if not rows or not rows[0].get('team_id'):
            raise HTTPException(404, 'Inventory not found in this organization.')
        bound(principal, 'workspace', rows[0]['team_id'])
        return inventory_workspaces._inventory(resource_id, actor, administration=administration)
    raise HTTPException(422, 'Choose an organization, workspace, inventory or Space.')


def database_error(exc):
    status, message = {
        '42501': (403, 'Your key or account no longer has permission for this action.'),
        'P0002': (404, 'The resource is no longer available.'),
        '23505': (409, 'This name, assignment or pending invitation already exists.'),
        '22023': (409, 'Check the action fields. Reuse a request_id only for the same action and values.'),
        '23514': (409, 'Check current access, the Space allowance, parent membership and linked records.'),
        '23503': (409, 'A required member or parent resource is unavailable.'),
        '40001': (409, 'The resource changed. Refresh before trying again.'),
        '40P01': (409, 'Another change is in progress. Retry with the same request_id.'),
    }.get(exc.code, (503, 'The action could not be confirmed. Retry with the same request_id.'))
    return HTTPException(status, message)


@router.get('')
def organization_directory(response: Response, principal: APIKeyPrincipal = Depends(require_api_scope('structure:read'))):
    organization_key(principal)
    response.headers['Cache-Control'] = 'no-store'
    org = bound(principal, 'organization', principal.organization_id)
    return {'organization': {key: org[key] for key in ('organization_id', 'name', 'owner_user_id', 'role')}}


@router.get('/directory')
def resource_directory(kind: Literal['workspace', 'inventory', 'space'], response: Response,
                       parent_id: UUID | None = None, offset: int = Query(0, ge=0), page_size: int = Query(100, ge=1, le=100),
                       principal: APIKeyPrincipal = Depends(require_api_scope('structure:read'))):
    organization_key(principal)
    response.headers['Cache-Control'] = 'no-store'
    user = AuthenticatedUser(principal.org_id)
    raw = get_supabase_raw()
    if kind == 'workspace':
        if parent_id and str(parent_id) != principal.organization_id:
            raise HTTPException(403, 'Choose this key organization.')
        rows = raw.table('teams').select('team_id,name,organization_id,owner_user_id').eq(
            'organization_id', principal.organization_id).order('name').order('team_id').range(offset, offset + page_size).execute().data or []
        memberships = raw.table('team_memberships').select('team_id,role').eq('user_id', principal.org_id).execute().data or []
        roles = {r['team_id']: r['role'] for r in memberships}
        rows = [{**r, 'role': roles.get(r['team_id']), 'can_open': r['team_id'] in roles} for r in rows]
    elif not parent_id:
        raise HTTPException(422, 'parent_id is required for inventories and Spaces.')
    elif kind == 'inventory':
        bound(principal, 'workspace', parent_id)
        result = inventory_workspaces.list_workspace_inventories(str(parent_id), q='', offset=offset, user=user)
        rows = result['inventories']
        return {**result, 'inventories': rows[:page_size], 'next_offset': offset + page_size if len(rows) > page_size else result.get('next_offset')}
    else:
        bound(principal, 'inventory', parent_id)
        rows = raw.table('app_inventory_space_summaries').select('id,name,inventory_id,item_count,created_at').eq(
            'inventory_id', str(parent_id)).order('name').order('id').range(offset, offset + page_size).execute().data or []
    return {'resources': rows[:page_size], 'offset': offset, 'next_offset': offset + page_size if len(rows) > page_size else None}


@router.get('/members')
def resource_members(kind: Literal['organization', 'workspace', 'inventory'], resource_id: UUID, response: Response,
                     offset: int = Query(0, ge=0), page_size: int = Query(100, ge=1, le=100),
                     principal: APIKeyPrincipal = Depends(require_api_scope('members:read'))):
    resource = bound(principal, kind, resource_id, administration=True)
    response.headers['Cache-Control'] = 'no-store'
    raw = get_supabase_raw()
    query = raw.table('app_organization_members' if kind == 'organization' else 'team_memberships').select('user_id,role')
    query = query.eq('organization_id', str(resource_id)) if kind == 'organization' else query.eq('team_id', str(resource_id) if kind == 'workspace' else resource['team_id'])
    rows = query.order('user_id').range(offset, offset + page_size).execute().data or []
    more = len(rows) > page_size
    rows = rows[:page_size]
    if kind == 'inventory':
        ids = [row['user_id'] for row in rows]
        grants = raw.table('app_inventory_members').select('user_id,inventory_id,role').eq('inventory_id', str(resource_id)).in_('user_id', ids).execute().data if ids else []
        effective = []
        for member in rows:
            override = next((row for row in grants or [] if row['user_id'] == member['user_id']), None)
            role = inventory_workspaces.inventory_role(resource, {**resource['workspace'], 'role': member['role']}, member['user_id'], [override] if override else [])
            if role or resource['can_manage']:
                effective.append({**member, 'workspace_role': member['role'], 'role': role or 'none', 'override': override['role'] if override else 'inherit'})
        rows = effective
    return {'members': collaboration.members_with_names(rows), 'offset': offset, 'next_offset': offset + page_size if more else None}


@router.get('/invitations')
def resource_invitations(kind: Literal['organization', 'workspace', 'inventory'], resource_id: UUID, response: Response,
                         offset: int = Query(0, ge=0), page_size: int = Query(100, ge=1, le=100),
                         principal: APIKeyPrincipal = Depends(require_api_scope('members:read'))):
    bound(principal, kind, resource_id, administration=True)
    response.headers['Cache-Control'] = 'no-store'
    from app.services.access_invitations import invitation_rpc, decorate
    rows = invitation_rpc(principal.org_id, 'sent', {'scope': kind, 'resource_id': str(resource_id)})
    return {'invitations': [decorate(row) for row in rows[offset:offset + page_size]],
            'offset': offset, 'next_offset': offset + page_size if len(rows) > offset + page_size else None}


# Required/optional fields per action. Unknown and irrelevant values are rejected,
# so a model cannot smuggle a second operation into a valid request.
ACTION_FIELDS = {
    'organization_rename': ({'name'}, set(), 'organization'),
    'workspace_create': ({'name'}, set(), 'organization'),
    'workspace_rename': ({'name'}, set(), 'workspace'),
    'inventory_create': ({'name'}, {'access_mode'}, 'workspace'),
    'inventory_rename': ({'name'}, set(), 'inventory'),
    'space_create': ({'name'}, set(), 'inventory'),
    'space_rename': ({'name'}, set(), 'space'),
    'space_move': ({'inventory_id'}, set(), 'space'),
    'inventory_policy': ({'access_mode', 'default_role'}, set(), 'inventory'),
    'member_invite': ({'email', 'role'}, set(), None),
    'member_change': ({'user_id', 'role'}, set(), None),
    'member_remove': ({'user_id'}, set(), None),
    'invitation_cancel': ({'invitation_id'}, set(), None),
    'location_create': ({'name'}, {'parent_id'}, 'workspace'),
    'location_attach': ({'location_id'}, set(), 'inventory'),
}
MEMBER_ACTIONS = frozenset(('member_invite', 'member_change', 'member_remove', 'invitation_cancel', 'inventory_policy'))


class OrganizationAction(APIModel):
    operation: Literal['organization_rename', 'workspace_create', 'workspace_rename', 'inventory_create', 'inventory_rename',
                       'space_create', 'space_rename', 'space_move', 'inventory_policy', 'member_invite', 'member_change',
                       'member_remove', 'invitation_cancel', 'location_create', 'location_attach']
    request_id: UUID = Field(description='Fresh UUID for a new action. Reuse it with identical values after a timeout; successful retries return the saved receipt.')
    kind: Kind = Field(description='Parent kind for creation: organization for workspace_create; workspace for inventory_create/location_create; inventory for space_create. For rename/move, use the target kind. For membership actions, use organization/workspace/inventory.')
    resource_id: UUID = Field(description='Exact UUID from the directory: the parent for create, target for rename/move/policy/location_attach, or membership resource for invite/change/remove/cancel.')
    name: str | None = Field(default=None, min_length=1, max_length=100, description="Required for every create/rename operation; omit for other operations.")
    access_mode: Literal['workspace', 'restricted'] | None = Field(default=None, description='Required with default_role for inventory_policy; optional for inventory_create. workspace inherits membership; restricted requires individual grants.')
    default_role: Literal['viewer', 'editor'] | None = Field(default=None, description='Required only for inventory_policy, with access_mode.')
    email: str | None = Field(default=None, max_length=254, description='Required only for member_invite. The recipient must accept before receiving access.', pattern=r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
    user_id: UUID | None = Field(default=None, description="Required for member_change and member_remove; resolve from members, never guess.")
    role: Literal['member', 'admin', 'editor', 'viewer', 'inherit'] | None = Field(default=None, description='Required for member_invite/member_change. Organization: member/admin. Workspace or inventory: viewer/editor/admin. Inventory member_change also permits inherit.')
    inventory_id: UUID | None = Field(default=None, description="Required only for space_move: destination inventory in the same workspace.")
    invitation_id: UUID | None = Field(default=None, description="Required only for invitation_cancel; obtain from invitations.")
    parent_id: UUID | None = Field(default=None, description="Optional only for location_create: parent physical location UUID in this workspace.")
    location_id: UUID | None = Field(default=None, description="Required only for location_attach: physical location UUID in this inventory workspace.")

    @model_validator(mode='after')
    def action_fields(self):
        required, optional, kind = ACTION_FIELDS[self.operation]
        supplied = self.model_fields_set - {'operation', 'request_id', 'kind', 'resource_id'}
        if not required <= supplied or supplied - required - optional or any(getattr(self, field) is None for field in required):
            raise ValueError(f'{self.operation} requires {", ".join(sorted(required))}; optional fields: {", ".join(sorted(optional)) or "none"}.')
        if (kind and self.kind != kind) or (not kind and self.kind == 'space'):
            raise ValueError('This action does not apply to the selected resource kind.')
        if self.name is not None:
            self.name = self.name.strip()
            if not self.name:
                raise ValueError('Name must not be blank.')
        if self.role is not None:
            roles = {'member', 'admin'} if self.kind == 'organization' else {'admin', 'editor', 'viewer'}
            if self.kind == 'inventory' and self.operation == 'member_change':
                roles.add('inherit')
            if self.role not in roles:
                raise ValueError('Choose a role supported by this resource.')
        return self


def save_action(principal, body, data, limit=None):
    try:
        result = get_supabase_raw().rpc('findez_agent_manage', {
            'p_key': principal.key_id, 'p_request': str(body.request_id), 'p_operation': body.operation,
            'p_kind': body.kind, 'p_resource': str(body.resource_id), 'p_data': data, 'p_space_limit': limit,
        }).execute().data
    except APIError as exc:
        raise database_error(exc) from None
    if not isinstance(result, dict):
        raise HTTPException(503, 'The change could not be confirmed. Retry with the same request_id.')
    return result


@router.post('/actions')
def perform_action(body: OrganizationAction, request: Request, response: Response,
                   principal: APIKeyPrincipal = Depends(require_api_scope(None))):
    organization_key(principal)
    required = 'members:write' if body.operation in MEMBER_ACTIONS else 'structure:write'
    if not principal.allows(required):
        raise api_error(request, 403, 'insufficient_scope', f'This action requires {required}.')
    response.headers['Cache-Control'] = 'no-store'
    # SQL repeats key, organization and actor checks under transaction locks.
    resource = bound(principal, body.kind, body.resource_id, administration=True)
    data = body.model_dump(mode='json', exclude_none=True, exclude={'operation', 'request_id', 'kind', 'resource_id'})
    limit = None
    if body.operation == 'space_create':
        from app.services.limits import resolve_effective_limits
        limits, _ = resolve_effective_limits(resource['owner_user_id'])
        limit = limits['spaces']
    if body.operation in ('member_invite', 'member_change') and not (body.operation == 'member_change' and body.kind == 'organization'):
        from app.services.access_invitations import invite_or_change
        secret = str(get_settings().supabase_jwt_secret)
        if not secret:
            raise HTTPException(503, 'Invitations are temporarily unavailable.')
        digest = hmac.new(secret.encode(), f'agent-invite:{principal.key_id}:{body.request_id}'.encode(), hashlib.sha256).digest()
        # Same operation retries send the same recipient-bound code, never invalidate an earlier email.
        code = base64.b32encode(digest).decode()[:12]
        result = invite_or_change(principal.org_id, body.kind, str(body.resource_id), body.role,
            email=body.email, member_id=str(body.user_id) if body.user_id else None, _code=code,
            _save=lambda invitation: save_action(principal, body, {**data, 'code_hash': invitation['code_hash']}, limit))
    else:
        result = save_action(principal, body, data, limit)
    from app.services.items_repo import invalidate_inventory_cache
    owner = resource.get('owner_user_id') or resource.get('inventory', {}).get('owner_user_id')
    if owner:
        invalidate_inventory_cache(owner)
    return {'request_id': str(body.request_id), 'operation': body.operation, 'result': result}


class DeletePreview(APIModel):
    request_id: UUID
    kind: Literal['item', 'space', 'inventory', 'workspace']
    resource_id: UUID


@router.post('/deletions', status_code=201)
def prepare_deletion(body: DeletePreview, request: Request, response: Response,
                     principal: APIKeyPrincipal = Depends(require_api_scope(None))):
    organization_key(principal)
    required = 'items:delete' if body.kind == 'item' else 'structure:delete'
    if not principal.allows(required):
        raise api_error(request, 403, 'insufficient_scope', f'This action requires {required}.')
    response.headers['Cache-Control'] = 'no-store'
    try:
        result = get_supabase_raw().rpc('findez_agent_prepare_delete', {
            'p_key': principal.key_id, 'p_request': str(body.request_id),
            'p_kind': body.kind, 'p_resource': str(body.resource_id),
        }).execute().data
    except APIError as exc:
        raise database_error(exc) from None
    if not isinstance(result, dict) or not result.get('id'):
        raise HTTPException(503, 'The deletion preview could not be prepared. No deletion was requested.')
    result['approval_url'] = f"{str(get_settings().frontend_url).rstrip('/')}/agent-approvals/{result['id']}"
    result['instructions'] = 'Show this preview and approval link to the user. The signed-in key owner must review and confirm in FindEZ. The API key cannot confirm. Poll the status afterward; pending does not mean deleted.'
    return result


@router.get('/deletions/{approval_id}')
def deletion_status(approval_id: UUID, response: Response,
                    principal: APIKeyPrincipal = Depends(require_api_scope(None))):
    organization_key(principal)
    response.headers['Cache-Control'] = 'no-store'
    rows = get_supabase_raw().table('api_agent_delete_approvals').select(
        'id,key_id,kind,resource_id,status,expires_at,receipt').eq('id', str(approval_id)).eq('key_id', principal.key_id).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, 'Deletion request not found.')
    required = 'items:delete' if rows[0]['kind'] == 'item' else 'structure:delete'
    if not principal.allows(required):
        raise HTTPException(403, f'This request requires {required}.')
    return rows[0]

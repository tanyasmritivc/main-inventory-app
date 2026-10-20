"""Resource permissions shared by every application entry point.

Database policy in migrations 054 and 062 independently enforces the same boundaries.
Workspace role aliases are retained at the storage/API boundary for old clients.
"""
from fastapi import HTTPException

WORKSPACE_ROLES = {'owner': 'owner', 'mentor': 'admin', 'member': 'editor', 'viewer': 'viewer'}
READ_ROLES = frozenset(('owner', 'admin', 'editor', 'viewer'))
EDIT_ROLES = frozenset(('owner', 'admin', 'editor'))
ADMIN_ROLES = frozenset(('owner', 'admin'))


def workspace_role(role):
    return WORKSPACE_ROLES.get(role)


def inventory_role(inventory, workspace, actor_id, grants):
    if not inventory.get('team_id'):
        return 'owner' if inventory.get('owner_user_id') == actor_id else None
    if workspace.get('organization_role') in ADMIN_ROLES:
        return workspace['organization_role']
    inherited = workspace_role(workspace.get('role'))
    if inherited is None:
        return None
    grant = next((r['role'] for r in grants if r['inventory_id'] == inventory['inventory_id']), None)
    if grant == 'none':
        return None
    if grant is not None:
        return grant if grant in READ_ROLES else None
    return None if inventory.get('access_mode') == 'restricted' else inherited


def can_administer_inventory(inventory, workspace, content_role):
    return content_role in ADMIN_ROLES or (
        bool(inventory.get('team_id')) and workspace_role(workspace.get('role')) in ADMIN_ROLES
    )


def require_inventory_action(role, action):
    allowed = ADMIN_ROLES if action in ('delete_space', 'manage') else EDIT_ROLES if action == 'edit' else READ_ROLES
    if role not in allowed:
        message = ('Only inventory owners and admins can delete a Space.' if action == 'delete_space'
                   else 'Only inventory owners and admins can manage this inventory.' if action == 'manage'
                   else 'You have view-only access to this inventory.' if action == 'edit'
                   else 'You do not have access to this inventory.')
        raise HTTPException(403, message)


def require_workspace_parent(raw, team_id, actor_id):
    teams = raw.table('teams').select('organization_id').eq('team_id', team_id).limit(1).execute().data or []
    if not teams:
        raise HTTPException(403, 'You no longer have access to this workspace.')
    organization_id = teams[0].get('organization_id')
    if organization_id and not (raw.table('app_organization_members').select('role').eq('organization_id', organization_id).eq('user_id', actor_id).limit(1).execute().data or []):
        raise HTTPException(403, 'Organization membership is required for this workspace.')


def organization_workspace_role(raw, team_id, actor_id):
    teams = raw.table('teams').select('organization_id').eq('team_id', team_id).limit(1).execute().data or []
    if not teams or not teams[0].get('organization_id'):
        return None
    rows = raw.table('app_organization_members').select('role').eq('organization_id', teams[0]['organization_id']).eq('user_id', actor_id).limit(1).execute().data or []
    return rows[0].get('role') if rows else None


def workspace_membership(raw, team_id, actor_id):
    parent_role = organization_workspace_role(raw, team_id, actor_id)
    if parent_role in ADMIN_ROLES:
        return {'role': 'owner' if parent_role == 'owner' else 'mentor', 'organization_role': parent_role}
    memberships = raw.table('team_memberships').select('member_id,role').eq('team_id', team_id).eq('user_id', actor_id).limit(1).execute().data or []
    if not memberships or workspace_role(memberships[0].get('role')) is None:
        raise HTTPException(403, 'You no longer have access to this workspace.')
    require_workspace_parent(raw, team_id, actor_id)
    return {**memberships[0], 'organization_role': parent_role}


def can_rename_inventory(inventory, workspace, content_role):
    return content_role in EDIT_ROLES or can_administer_inventory(inventory, workspace, content_role)


def workspace_roster(members, organization_members):
    """Show effective administrator roles even when an old assignment says Viewer."""
    result = {row['user_id']: dict(row) for row in members}
    for row in organization_members:
        if row.get('role') in ADMIN_ROLES:
            result[row['user_id']] = {**result.get(row['user_id'], {}), 'user_id': row['user_id'],
                'role': 'owner' if row['role'] == 'owner' else 'mentor', 'organization_role': row['role']}
    return list(result.values())

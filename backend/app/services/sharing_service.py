from __future__ import annotations

import secrets
import string

from app.services.supabase_client import get_supabase_admin


def generate_unique_code(client) -> str:
    chars = string.ascii_uppercase + string.digits
    for _ in range(10):
        code = ''.join(secrets.choice(chars) for _ in range(6))
        existing = (
            client.table('team_shares')
            .select('share_code')
            .eq('share_code', code)
            .execute()
        )
        if not existing.data:
            return code
    raise ValueError('Could not generate unique code')


def create_share(*, user_id: str, share_name: str, permission: str) -> dict:
    client = get_supabase_admin()
    code = generate_unique_code(client)
    result = client.table('team_shares').insert({
        'owner_user_id': user_id,
        'share_code': code,
        'share_name': share_name,
        'permission': permission,
        'is_active': True,
    }).execute()
    return result.data[0] if result.data else {}


def get_my_shares(*, user_id: str) -> list:
    client = get_supabase_admin()
    shares = (
        client.table('team_shares')
        .select('*')
        .eq('owner_user_id', user_id)
        .eq('is_active', True)
        .order('created_at', desc=True)
        .execute()
    )
    result = []
    for share in (shares.data or []):
        members = (
            client.table('team_members')
            .select('member_id')
            .eq('share_id', share['share_id'])
            .execute()
        )
        share['member_count'] = len(members.data or [])
        result.append(share)
    return result


def join_share(*, user_id: str, share_code: str) -> dict:
    client = get_supabase_admin()
    share = (
        client.table('team_shares')
        .select('*')
        .eq('share_code', share_code.upper())
        .eq('is_active', True)
        .execute()
    )
    if not share.data:
        raise ValueError('Share not found or revoked')
    s = share.data[0]
    if s['owner_user_id'] == user_id:
        raise ValueError('You cannot join your own share')
    existing = (
        client.table('team_members')
        .select('member_id')
        .eq('share_id', s['share_id'])
        .eq('member_user_id', user_id)
        .execute()
    )
    if existing.data:
        raise ValueError('Already a member')
    client.table('team_members').insert({
        'share_id': s['share_id'],
        'member_user_id': user_id,
    }).execute()
    return s


def get_joined_shares(*, user_id: str) -> list:
    client = get_supabase_admin()
    memberships = (
        client.table('team_members')
        .select('*, team_shares(*)')
        .eq('member_user_id', user_id)
        .execute()
    )
    return memberships.data or []


def revoke_share(*, user_id: str, share_id: str) -> bool:
    client = get_supabase_admin()
    client.table('team_shares').update({'is_active': False}).eq(
        'share_id', share_id
    ).eq('owner_user_id', user_id).execute()
    return True


def remove_member(*, owner_user_id: str, share_id: str, member_user_id: str) -> bool:
    client = get_supabase_admin()
    share = (
        client.table('team_shares')
        .select('share_id')
        .eq('share_id', share_id)
        .eq('owner_user_id', owner_user_id)
        .execute()
    )
    if not share.data:
        raise ValueError('Not authorized')
    client.table('team_members').delete().eq('share_id', share_id).eq(
        'member_user_id', member_user_id
    ).execute()
    return True


def get_share_inventory(*, requesting_user_id: str, share_id: str) -> list:
    client = get_supabase_admin()
    share = (
        client.table('team_shares')
        .select('*')
        .eq('share_id', share_id)
        .eq('is_active', True)
        .execute()
    )
    if not share.data:
        raise ValueError('Share not found')
    s = share.data[0]
    is_owner = s['owner_user_id'] == requesting_user_id
    is_member = False
    if not is_owner:
        m = (
            client.table('team_members')
            .select('member_id')
            .eq('share_id', share_id)
            .eq('member_user_id', requesting_user_id)
            .execute()
        )
        is_member = bool(m.data)
    if not is_owner and not is_member:
        raise ValueError('Not authorized')
    from app.services.items_repo import search_items_basic
    all_items = search_items_basic(user_id=s['owner_user_id'], q='')
    space_name = (s.get('share_name') or '').strip().lower()
    if space_name:
        return [item for item in all_items if (item.get('location') or '').strip().lower() == space_name]
    return all_items


def get_share_members(*, owner_user_id: str, share_id: str) -> list:
    client = get_supabase_admin()
    share = (
        client.table('team_shares')
        .select('share_id')
        .eq('share_id', share_id)
        .eq('owner_user_id', owner_user_id)
        .execute()
    )
    if not share.data:
        raise ValueError('Not authorized')
    members = (
        client.table('team_members')
        .select('*')
        .eq('share_id', share_id)
        .execute()
    )
    return members.data or []

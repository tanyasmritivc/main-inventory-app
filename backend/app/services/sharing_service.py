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


def get_share_item_events(*, requesting_user_id: str, share_id: str, item_id: str) -> list:
    client = get_supabase_admin()

    # Verify share exists and is active
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

    # Verify requester is owner or active member (same check as get_share_inventory)
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

    # Verify item_id is scoped to this share (same location filter as get_share_inventory)
    from app.services.items_repo import search_items_basic
    owner_items = search_items_basic(user_id=s['owner_user_id'], q='')
    space_name = (s.get('share_name') or '').strip().lower()
    if space_name:
        space_items = [i for i in owner_items if (i.get('location') or '').strip().lower() == space_name]
    else:
        space_items = owner_items
    item_ids_in_space = {i['item_id'] for i in space_items if i.get('item_id')}
    if item_id not in item_ids_in_space:
        raise ValueError('Item not found in this share')

    # Fetch all events for the item using service-role client (bypasses RLS)
    result = (
        client.table('item_events')
        .select('*')
        .eq('item_id', item_id)
        .order('created_at', desc=True)
        .limit(50)
        .execute()
    )
    return result.data or []


def get_share_members(*, owner_user_id: str, share_id: str) -> list:
    client = get_supabase_admin()

    # Allow both owner AND members to see the member list
    share = (
        client.table('team_shares')
        .select('share_id, owner_user_id, share_name, permission')
        .eq('share_id', share_id)
        .execute()
    )
    if not share.data:
        raise ValueError('Share not found')

    s = share.data[0]
    is_owner = s['owner_user_id'] == owner_user_id
    is_member = False
    if not is_owner:
        m = client.table('team_members').select('member_id').eq('share_id', share_id).eq('member_user_id', owner_user_id).execute()
        is_member = bool(m.data)
    if not is_owner and not is_member:
        raise ValueError('Not authorized')

    members = (
        client.table('team_members')
        .select('*')
        .eq('share_id', share_id)
        .execute()
    )

    result = []

    # Add owner first
    try:
        owner = client.auth.admin.get_user_by_id(s['owner_user_id'])
        owner_email = owner.user.email if owner and owner.user else 'Unknown'
        owner_profile = client.table('profiles').select('display_name, avatar_color').eq('id', s['owner_user_id']).execute()
        owner_display = (owner_profile.data[0].get('display_name') or owner_email.split('@')[0]) if owner_profile.data else owner_email.split('@')[0]
        result.append({
            'user_id': s['owner_user_id'],
            'display_name': owner_display,
            'email': owner_email,
            'role': 'owner',
            'joined_at': s.get('created_at'),
            'avatar_color': (owner_profile.data[0].get('avatar_color') or '#636366') if owner_profile.data else '#636366',
        })
    except Exception:
        result.append({
            'user_id': s['owner_user_id'],
            'display_name': 'Owner',
            'email': '',
            'role': 'owner',
            'joined_at': None,
            'avatar_color': '#636366',
        })

    # Add members
    for m in (members.data or []):
        try:
            u = client.auth.admin.get_user_by_id(m['member_user_id'])
            email = u.user.email if u and u.user else 'Unknown'
            profile = client.table('profiles').select('display_name, avatar_color').eq('id', m['member_user_id']).execute()
            display = (profile.data[0].get('display_name') or email.split('@')[0]) if profile.data else email.split('@')[0]
            result.append({
                'user_id': m['member_user_id'],
                'member_id': m['member_id'],
                'display_name': display,
                'email': email,
                'role': 'member',
                'joined_at': m.get('joined_at'),
                'avatar_color': (profile.data[0].get('avatar_color') or '#636366') if profile.data else '#636366',
            })
        except Exception:
            result.append({
                'user_id': m['member_user_id'],
                'member_id': m.get('member_id'),
                'display_name': 'Member',
                'email': '',
                'role': 'member',
                'joined_at': m.get('joined_at'),
                'avatar_color': '#636366',
            })

    return result

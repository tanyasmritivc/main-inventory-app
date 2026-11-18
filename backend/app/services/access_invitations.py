"""Recipient-bound collaboration invitations. No access is granted by delivery."""
import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from postgrest.exceptions import APIError

from app.core.config import get_settings
from app.services.invitation_email import render_invitation_email
from app.services.email_delivery import send_transactional_email
from app.services.supabase_client import get_supabase_raw

logger = logging.getLogger(__name__)
ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'


def invitation_rpc(actor: str, action: str, data: dict | None = None):
    try:
        result = get_supabase_raw().rpc('findez_access_invitation', {
            'p_actor': actor, 'p_action': action, 'p_data': data or {},
        }).execute().data
    except APIError as exc:
        errors = {
            '42501': (403, 'Use the invited account with a confirmed email. The sender must still be allowed to grant access.'),
            'P0002': (404, 'This invitation is unavailable. Ask the sender for a new invitation.'),
            '23505': (409, 'This person already has access or a pending invitation. Cancel the pending invitation before sending another.'),
            '23514': (422, 'This invitation cannot be used. Check its expiry, status and parent membership.'),
            '23503': (422, 'The member or workspace is no longer available.'),
        }
        if exc.code in errors:
            status, message = errors[exc.code]
            raise HTTPException(status, message) from None
        raise
    if result is None:
        raise HTTPException(503, 'The invitation could not be confirmed. Refresh before retrying.')
    return result


def code_hash(code: str) -> str:
    return hashlib.sha256(code.upper().encode('ascii')).hexdigest()


def decorate(invitation: dict) -> dict:
    from app.api.routes.collaboration import members_with_names
    actor = invitation.get('invited_by')
    inviter = members_with_names([{'user_id': actor}])[0] if actor else None
    scope, resource = invitation['scope'], invitation['resource_id']
    destination = {
        'organization': f'/organizations/{resource}',
        'workspace': f'/workspaces/{resource}',
        'inventory': f'/home?inventory={resource}',
    }[scope]
    return {**invitation, 'name': invitation['resource_name'], 'destination': destination, 'inviter': inviter}


def invite_or_change(actor: str, scope: str, resource: str, role: str, *, email: str | None = None, member_id: str | None = None, _save=None, _code: str | None = None) -> dict:
    code = _code or ''.join(secrets.choice(ALPHABET) for _ in range(12))
    data = {'scope': scope, 'resource_id': resource, 'role': role, 'code_hash': code_hash(code)}
    data.update({'user_id': member_id} if member_id else {'email': email})
    saved = _save(data) if _save else invitation_rpc(actor, 'change' if member_id else 'create', data)
    if 'invitation_id' not in saved:
        return saved
    skip_delivery = saved.pop('_skip_delivery', False)
    invitation = decorate(saved)
    base = str(get_settings().frontend_url).rstrip('/')
    url = f'{base}/join/access?code={code}'
    name = invitation['name']
    if skip_delivery:
        return {'invitation': invitation, 'code': code, 'invite_url': url, 'email_sent': None, 'delivery_status': 'not_retried'}
    from app.services.push_notifications import enqueue_invitation
    enqueue_invitation(saved['invitation_id'])
    inviter_name = (invitation.get('inviter') or {}).get('display_name') or 'A team member'
    sent = False
    try:
        send_transactional_email(
            to=invitation['recipient_email'],
            subject=f'Invitation to {name} on FindEZ',
            text=(f'{inviter_name} invited you to join FindEZ.\nYou are invited to {name} ({scope}) as {role}. '
                  f'Review and accept or decline: {url}\n'
                  f'Or open {base}/join/access and enter code {code}. '
                  'Sign in with this email address. No access is granted until you accept. '
                  'This invitation expires in 7 days. If you did not expect it, you can decline or ignore it.'),
            html=render_invitation_email(
                title=f"Invitation to {name}",
                introduction=f"Invited by {inviter_name}",
                access_label=f"{scope.title()} access: {role.title()}",
                action_label="Review invitation", action_url=url, code=code,
                fallback_url=f"{base}/join/access",
                instructions="Sign in with this email address. You choose whether to accept. "
                "No access is granted until then. Expires in 7 days.",
            ),
            message_id=f"<access-invite-{invitation['invitation_id']}@findez.ai>",
        )
        sent = True
    except Exception:
        # Keep the pending record and usable code, but never claim delivery.
        # SMTP exceptions may contain credentials or recipient addresses.
        logger.warning('Access invitation email failed invitation=%s', invitation['invitation_id'])
    return {'invitation': invitation, 'code': code, 'invite_url': url, 'email_sent': sent}


def inbox(actor: str) -> list[dict]:
    return [decorate(row) for row in invitation_rpc(actor, 'inbox')]


def notification_rows(actor: str) -> list[dict]:
    # The actionable inbox intentionally contains only pending invitations.
    # Notification history retains decisions/expiry without restoring access.
    client = get_supabase_raw()
    identity = client.auth.admin.get_user_by_id(actor).user
    if not identity or not identity.email_confirmed_at or not identity.email:
        return []
    cutoff = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
    rows = client.table('app_access_invitations').select(
        'invitation_id,scope,resource_id,resource_name,role,status,invited_by,team_id,created_at,expires_at,seen_at'
    ).eq('recipient_email', identity.email.lower()).gte('created_at', cutoff).order('created_at', desc=True).execute().data or []
    now = datetime.now(timezone.utc)
    for row in rows:
        row.pop('code_hash', None)
        row.pop('recipient_email', None)
        if row['status'] == 'pending' and datetime.fromisoformat(row['expires_at'].replace('Z', '+00:00')) <= now:
            row['status'] = 'expired'
    return [{
        'activity_id': row['invitation_id'], 'action': 'access_invitation',
        'actor_id': row['invited_by'], 'team_id': row.get('team_id'),
        'created_at': row['created_at'], 'is_read': bool(row.get('seen_at')) or row['status'] != 'pending',
        'summary': f"Invitation to {row['name']}",
        'display_text': f"Invitation to {row['name']}" + (f" ({row['status']})" if row['status'] != 'pending' else ''),
        'activity_type': 'Invitation', 'team_name': '', 'invitation': row,
        'metadata': {'invitation_id': row['invitation_id']},
    } for row in map(decorate, rows)]

"""Recipient-bound collaboration invitations. No access is granted by delivery."""
import hashlib
import html
import logging
import secrets

from fastapi import HTTPException
from postgrest.exceptions import APIError

from app.core.config import get_settings
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
    scope, resource = invitation['scope'], invitation['resource_id']
    destination = {
        'organization': f'/organizations/{resource}',
        'workspace': f'/workspaces/{resource}',
        'inventory': f'/home?inventory={resource}',
    }[scope]
    return {**invitation, 'name': invitation['resource_name'], 'destination': destination}


def invite_or_change(actor: str, scope: str, resource: str, role: str, *, email: str | None = None, member_id: str | None = None) -> dict:
    code = ''.join(secrets.choice(ALPHABET) for _ in range(12))
    data = {'scope': scope, 'resource_id': resource, 'role': role, 'code_hash': code_hash(code)}
    data.update({'user_id': member_id} if member_id else {'email': email})
    saved = invitation_rpc(actor, 'change' if member_id else 'create', data)
    if 'invitation_id' not in saved:
        return saved
    invitation = decorate(saved)
    base = str(get_settings().frontend_url).rstrip('/')
    url = f'{base}/join/access?code={code}'
    name = invitation['name']
    sent = False
    try:
        send_transactional_email(
            to=invitation['recipient_email'],
            subject=f'Invitation to {name} on FindEZ',
            text=(f'You are invited to {name} ({scope}) as {role}. '
                  f'Review and accept or decline: {url}\n'
                  f'Or open {base}/join/access and enter code {code}. '
                  'Sign in with this email address. No access is granted until you accept. '
                  'This invitation expires in 7 days. If you did not expect it, you can decline or ignore it.'),
            html=(f'<h1>Invitation to {html.escape(name)}</h1>'
                  f'<p>{html.escape(scope.title())} access: {html.escape(role.title())}</p>'
                  f'<p><a href="{html.escape(url, quote=True)}">Review invitation</a></p>'
                  f'<p>Or enter code <strong>{code}</strong> at {html.escape(base)}/join/access.</p>'
                  '<p>Sign in with this email address. You choose whether to accept. '
                  'No access is granted until then. Expires in 7 days.</p>'),
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
    return [{
        'activity_id': row['invitation_id'], 'action': 'access_invitation',
        'actor_id': row['invited_by'], 'team_id': row.get('team_id'),
        'created_at': row['created_at'], 'is_read': bool(row.get('seen_at')),
        'summary': f"Invitation to {row['name']}",
        'display_text': f"Invitation to {row['name']}",
        'activity_type': 'Invitation', 'team_name': '', 'invitation': row,
        'metadata': {'invitation_id': row['invitation_id']},
    } for row in inbox(actor)]

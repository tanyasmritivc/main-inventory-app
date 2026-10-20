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


def invite_or_change(actor: str, scope: str, resource: str, role: str, *, email: str | None = None, member_id: str | None = None) -> dict:
    code = ''.join(secrets.choice(ALPHABET) for _ in range(12))
    data = {'scope': scope, 'resource_id': resource, 'role': role, 'code_hash': code_hash(code)}
    data.update({'user_id': member_id} if member_id else {'email': email})
    saved = invitation_rpc(actor, 'change' if member_id else 'create', data)
    if 'invitation_id' not in saved:
        return saved
    from app.services.push_notifications import enqueue_invitation
    enqueue_invitation(saved['invitation_id'])
    invitation = decorate(saved)
    base = str(get_settings().frontend_url).rstrip('/')
    url = f'{base}/join/access?code={code}'
    name = invitation['name']
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
            html=(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>FindEZ invitation</title></head>
<body style="margin:0;padding:0;width:100%;background:#f4f3ef;color:#24211d;font-family:Arial,Helvetica,sans-serif;-webkit-text-size-adjust:100%;">
<table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" bgcolor="#f4f3ef"><tr><td align="center" style="padding:32px 16px;">
<!--[if mso]><table role="presentation" width="560" border="0" cellspacing="0" cellpadding="0"><tr><td><![endif]-->
<table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width:560px;"><tr><td style="padding:0 4px 24px;">
<table role="presentation" border="0" cellspacing="0" cellpadding="0"><tr><td width="40"><img src="https://findez.ai/favicon.png" width="32" height="32" alt="" style="display:block;border:0;border-radius:7px;"></td><td style="font-size:23px;font-weight:700;letter-spacing:-1px;color:#24211d;">FindEZ</td></tr></table>
</td></tr><tr><td bgcolor="#ffffff" style="background:#ffffff;border:1px solid #e4e0d9;border-top:3px solid #bc4800;border-radius:12px;padding:30px 24px 8px;">
<h1 style="margin:0 0 18px;color:#24211d;font-size:28px;font-weight:700;letter-spacing:-0.6px;line-height:1.25;overflow-wrap:break-word;">Invitation to {html.escape(name)}</h1>
<p>Invited by {html.escape(inviter_name)}</p>
<p style="margin:0 0 22px;color:#55534f;font-size:16px;line-height:1.65;overflow-wrap:break-word;">{html.escape(scope.title())} access: {html.escape(role.title())}</p><table role="presentation" border="0" cellspacing="0" cellpadding="0" style="margin:6px 0 28px;"><tr><td bgcolor="#bc4800" style="border-radius:8px;text-align:center;"><a href="{html.escape(url, quote=True)}" style="display:inline-block;padding:15px 24px;border:1px solid #bc4800;border-radius:8px;background:#bc4800;color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:700;line-height:1.4;text-decoration:none;text-align:center;mso-padding-alt:0;">Review invitation</a></td></tr></table><p style="margin:0 0 22px;color:#55534f;font-size:14px;line-height:1.65;overflow-wrap:break-word;">Or enter code <strong style="font-family:Consolas,Menlo,monospace;color:#24211d;">{code}</strong> at {html.escape(base)}/join/access.</p><p style="margin:0 0 22px;color:#55534f;font-size:14px;line-height:1.65;overflow-wrap:break-word;">Sign in with this email address. You choose whether to accept. No access is granted until then. Expires in 7 days.</p>
</td></tr></table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr></table></body></html>
"""),
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

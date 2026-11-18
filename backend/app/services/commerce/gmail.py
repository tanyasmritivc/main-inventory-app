"""Opt-in, read-only Gmail purchase ingestion; fixed Google endpoints only."""
import base64
import hashlib
import json
import re
import secrets
import time
from email.utils import parseaddr
from urllib.parse import urlencode

import httpx
from fastapi import HTTPException

from app.services.commerce.config import settings
from app.services.commerce import repository as repo
from app.services.commerce.security import seal, unseal
from app.services.commerce.purchase_email import plain_email

SCOPE = 'https://www.googleapis.com/auth/gmail.readonly'
QUERY = 'from:(amazon.com) {subject:order subject:ordered subject:shipped subject:delivered subject:return subject:refund subject:cancelled subject:canceled}'


def manage(actor, inventory, action, payload=None):
    return repo.execute(repo.get_supabase_raw().rpc('findez_gmail_manage', {
        'p_actor': actor, 'p_inventory': str(inventory), 'p_action': action, 'p_payload': payload or {}}))


def job(action, payload=None):
    return repo.execute(repo.get_supabase_raw().rpc('findez_gmail_job', {'p_action': action, 'p_payload': payload or {}}))


def start(actor, inventory):
    cfg = settings(); cfg.require_gmail()
    state, verifier = secrets.token_urlsafe(32), secrets.token_urlsafe(48)
    aad = f'gmail-oauth:{actor}:{inventory}'
    result = manage(actor, inventory, 'start', {'state_hash': hashlib.sha256(state.encode()).hexdigest(),
        'verifier_ciphertext': seal({'verifier': verifier}, aad)})
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
    return {'connection_id': result['connection_id'], 'authorization_url': 'https://accounts.google.com/o/oauth2/v2/auth?' + urlencode({
        'client_id': cfg.gmail_client_id, 'redirect_uri': cfg.gmail_redirect_uri, 'response_type': 'code',
        'scope': SCOPE, 'state': state, 'access_type': 'offline', 'prompt': 'consent select_account',
        'code_challenge': challenge, 'code_challenge_method': 'S256', 'include_granted_scopes': 'false'}), 'expires_in': 600}


class Gmail:
    def __init__(self, client=None):
        self.client = client or httpx.Client(timeout=15, follow_redirects=False)

    def close(self):
        self.client.close()

    def call(self, method, url, **kwargs):
        try:
            with self.client.stream(method, url, **kwargs) as response:
                response.raise_for_status()
                raw = bytearray()
                for chunk in response.iter_bytes():
                    raw.extend(chunk)
                    if len(raw) > 2 * 1024 * 1024:
                        raise ValueError()
            return json.loads(raw) if raw else {}
        except (httpx.HTTPError, ValueError):
            raise HTTPException(502, 'Gmail could not complete the request. Retry or reconnect your account.') from None

    def tokens(self, *, code=None, verifier=None, refresh=None):
        cfg = settings()
        data = {'client_id': cfg.gmail_client_id, 'client_secret': cfg.gmail_client_secret.get_secret_value()}
        if code:
            data.update(grant_type='authorization_code', code=code, code_verifier=verifier, redirect_uri=cfg.gmail_redirect_uri)
        else:
            data.update(grant_type='refresh_token', refresh_token=refresh)
        value = self.call('POST', 'https://oauth2.googleapis.com/token', data=data)
        if not value.get('access_token') or not (value.get('refresh_token') or refresh) or ((code or 'scope' in value) and SCOPE not in value.get('scope', '').split()):
            raise HTTPException(400, 'Read-only Gmail permission and offline access are required. Connect again.')
        return {'access_token': value['access_token'], 'refresh_token': value.get('refresh_token') or refresh,
                'expires_at': time.time() + int(value.get('expires_in', 0))}

    def get(self, path, token, params=None):
        return self.call('GET', 'https://gmail.googleapis.com/gmail/v1/users/me/' + path,
                         headers={'Authorization': 'Bearer ' + token}, params=params)

    def revoke(self, token):
        # POST body avoids credentials in query/access logs. An unavailable Google
        # endpoint must not retain local access. User can also revoke in Google.
        try:
            response = self.client.post('https://oauth2.googleapis.com/revoke', data={'token': token})
            return response.status_code in (200, 400)
        except httpx.HTTPError:
            return False


def complete(actor, inventory, connection_id, code, state):
    settings().require_gmail()
    row = manage(actor, inventory, 'claim', {'connection_id': str(connection_id),
        'state_hash': hashlib.sha256(state.encode()).hexdigest()})
    provider = Gmail()
    tokens = None
    try:
        verifier = unseal(row['verifier_ciphertext'], f'gmail-oauth:{actor}:{inventory}')['verifier']
        tokens = provider.tokens(code=code, verifier=verifier)
        profile = provider.get('profile', tokens['access_token'])
        email = profile.get('emailAddress')
        if not isinstance(email, str) or len(email) > 320 or '@' not in email:
            raise HTTPException(502, 'Gmail account identity could not be confirmed.')
        manage(actor, inventory, 'finish', {'lease': row['lease'], 'email': email,
            'token_ciphertext': seal(tokens, row['connection_id'])})
        return {'connected': True}
    except Exception:
        if tokens:
            provider.revoke(tokens['refresh_token'])
        # Authorization state stays consumed; disconnect clears it before retry.
        raise
    finally:
        provider.close()


def disconnect(actor, inventory, purge):
    row = manage(actor, inventory, 'purge' if purge else 'disconnect')
    revoked = True
    if row.get('token_ciphertext'):
        provider = Gmail()
        try:
            tokens = unseal(row['token_ciphertext'], row['connection_id'])
            revoked = provider.revoke(tokens['refresh_token'])
        except Exception:
            revoked = False
        finally:
            provider.close()
    return {'disconnected': True, 'purged': purge, 'google_revocation_confirmed': revoked}


def body_text(value):
    payload = value.get('payload') or {}
    headers = {h['name'].lower(): h['value'] for h in payload.get('headers', [])}
    sender = parseaddr(headers.get('from', ''))[1].lower()
    domain = sender.rsplit('@', 1)[-1]
    if domain != 'amazon.com' and not domain.endswith('.amazon.com'):
        return None
    subject = headers.get('subject', '')
    if not re.search(r'\b(order|ordered|shipped|delivered|return|returned|refund|refunded|cancelled|canceled)\b', subject, re.I):
        return None
    plain, html = [], []
    def visit(part, depth=0):
        if depth > 20:
            raise ValueError('Unsupported message nesting')
        if part.get('filename'):
            return
        data = (part.get('body') or {}).get('data')
        if data and part.get('mimeType') in ('text/plain', 'text/html'):
            decoded = base64.urlsafe_b64decode(data + '=' * (-len(data) % 4)).decode('utf-8', errors='replace')
            (plain if part['mimeType'] == 'text/plain' else html).append(decoded)
        for child in part.get('parts', []):
            visit(child, depth+1)
    visit(payload)
    if not plain and not html:
        raise ValueError('No inline message body; attachments are not downloaded')
    return plain_email({'subject': subject, 'text': '\n'.join(plain), 'html': '\n'.join(html)})


def poll_one():
    settings().require_gmail()
    row = job('claim')
    if not row:
        return False
    provider = Gmail()
    base = {'connection_id': row['connection_id'], 'lease': row['lease']}
    try:
        tokens = unseal(row['token_ciphertext'], row['connection_id'])
        if tokens['expires_at'] <= time.time() + 60:
            tokens = provider.tokens(refresh=tokens['refresh_token'])
            job('tokens', {**base, 'token_ciphertext': seal(tokens, row['connection_id'])})
        now = int(time.time())
        cursor = row['cursor'] or {'after': now - 90*86400, 'before': now}
        params = {'q': QUERY + f" after:{cursor['after']} before:{cursor['before']}", 'maxResults': 20, 'includeSpamTrash': 'false'}
        if cursor.get('page'):
            params['pageToken'] = cursor['page']
        page = provider.get('messages', tokens['access_token'], params)
        batch = []
        for entry in page.get('messages', []):
            email_id = entry['id']
            if not re.fullmatch(r'[a-zA-Z0-9_-]{1,100}', email_id):
                raise ValueError('Invalid Gmail message identity')
            existing = repo.execute(repo.get_supabase_raw().table('commerce_purchase_emails').select('id')
                .eq('connection_id', row['connection_id']).eq('email_id', email_id).limit(1))
            if existing:
                continue
            message = provider.get('messages/' + email_id, tokens['access_token'], {'format': 'full'})
            try:
                value = {'text': body_text(message) or ''}
            except (ValueError, UnicodeError):
                value = {'text': '', 'parse_error': True}
            batch.append({'email_id': email_id, 'body_ciphertext': seal(value, 'purchase-email:' + row['connection_id'] + ':' + email_id)})
        if page.get('nextPageToken'):
            cursor = {**cursor, 'page': page['nextPageToken']}
        else:
            # Overlap protects delivery/date boundary races; message IDs dedupe.
            cursor = {'after': cursor['before'] - 86400, 'before': now + 1}
        job('commit', {**base, 'cursor': cursor, 'messages': batch})
    except Exception:
        job('fail', base)
    finally:
        provider.close()
    return True

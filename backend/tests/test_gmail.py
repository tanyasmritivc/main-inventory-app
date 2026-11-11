import base64
import json
import time
from unittest.mock import patch, MagicMock
from urllib.parse import parse_qs, urlsplit
from uuid import uuid4

import httpx
import pytest
from fastapi import HTTPException

from app.services.commerce import gmail
from app.services.commerce.config import CommerceSettings


@pytest.fixture
def configured():
    cfg = CommerceSettings(gmail_enabled=True, gmail_client_id='test-client', gmail_client_secret='test-secret',
        gmail_redirect_uri='https://www.example.test/connect/gmail/callback', encryption_key=base64.b64encode(b'x'*32).decode())
    with patch.object(gmail, 'settings', return_value=cfg), patch('app.services.commerce.security.settings', return_value=cfg):
        yield cfg


def test_oauth_uses_readonly_scope_pkce_and_actor_bound_encrypted_verifier(configured):
    actor, inventory, cid = str(uuid4()), str(uuid4()), str(uuid4())
    with patch.object(gmail, 'manage', return_value={'connection_id': cid}) as manage:
        result = gmail.start(actor, inventory)
        query = parse_qs(urlsplit(result['authorization_url']).query)
        assert query['scope'] == [gmail.SCOPE]
        assert query['code_challenge_method'] == ['S256']
        assert query['access_type'] == ['offline']
        saved = manage.call_args.args[3]
        assert saved['state_hash'] != query['state'][0]
        assert 'verifier' in gmail.unseal(saved['verifier_ciphertext'], f'gmail-oauth:{actor}:{inventory}')
        with pytest.raises(HTTPException):
            gmail.unseal(saved['verifier_ciphertext'], f'gmail-oauth:other:{inventory}')


def test_exchange_sends_pkce_and_validates_scope(configured):
    seen = []
    def handler(request):
        seen.append(request)
        return httpx.Response(200, json={'access_token': 'access', 'refresh_token': 'refresh', 'expires_in': 3600, 'scope': gmail.SCOPE})
    provider = gmail.Gmail(httpx.Client(transport=httpx.MockTransport(handler)))
    value = provider.tokens(code='code', verifier='verifier')
    assert value['refresh_token'] == 'refresh'
    assert b'code_verifier=verifier' in seen[0].content
    assert seen[0].url.host == 'oauth2.googleapis.com'
    provider = gmail.Gmail(httpx.Client(transport=httpx.MockTransport(lambda _: httpx.Response(200, json={'access_token': 'access', 'refresh_token': 'refresh', 'scope': 'gmail.send'}))))
    with pytest.raises(HTTPException):
        provider.tokens(code='code', verifier='verifier')


def test_refresh_accepts_omitted_unchanged_scope_and_preserves_refresh_token(configured):
    provider = gmail.Gmail(httpx.Client(transport=httpx.MockTransport(lambda _: httpx.Response(200, json={'access_token': 'access', 'expires_in': 3600}))))
    assert provider.tokens(refresh='refresh')['refresh_token'] == 'refresh'


def test_upstream_errors_redacted_and_redirect_not_followed():
    requests = []
    def handler(request):
        requests.append(request)
        return httpx.Response(302, headers={'location': 'https://evil.test/?private=secret'})
    provider = gmail.Gmail(httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False))
    with pytest.raises(HTTPException) as error:
        provider.get('profile', 'access')
    assert 'secret' not in error.value.detail and len(requests) == 1


def payload(sender='auto-confirm@amazon.com', subject='Your order', text='Motor Quantity: 2'):
    return {'payload': {'headers': [{'name': 'From', 'value': sender}, {'name': 'Subject', 'value': subject}],
        'mimeType': 'multipart/alternative', 'parts': [
            {'mimeType': 'text/plain', 'body': {'data': base64.urlsafe_b64encode(text.encode()).decode().rstrip('=')}},
            {'filename': 'private.pdf', 'mimeType': 'text/plain', 'body': {'data': 'cHJpdmF0ZQ=='}}]}}


def test_gmail_content_filter_excludes_other_senders_ads_and_attachments():
    assert 'Motor' in gmail.body_text(payload())
    assert 'private' not in gmail.body_text(payload())
    assert gmail.body_text(payload(sender='amazon.com@evil.test')) is None
    assert gmail.body_text(payload(sender='auto-confirm@amazon.com.evil.test')) is None
    assert gmail.body_text(payload(subject='Prime deals today')) is None


def test_poll_is_bounded_filtered_paginated_and_never_marks_read(configured):
    cid = str(uuid4())
    tokens = gmail.seal({'access_token': 'token', 'refresh_token': 'refresh', 'expires_at': time.time()+5000}, cid)
    row = {'connection_id': cid, 'lease': str(uuid4()), 'cursor': {}, 'token_ciphertext': tokens}
    provider = MagicMock()
    provider.get.side_effect = [{'messages': [{'id': 'abc123'}], 'nextPageToken': 'page2'}, payload()]
    with patch.object(gmail, 'job', side_effect=[row, {}]) as job, patch.object(gmail, 'Gmail', return_value=provider), \
         patch.object(gmail.repo, 'execute', return_value=[]), patch.object(gmail.repo, 'get_supabase_raw'):
        assert gmail.poll_one()
        params = provider.get.call_args_list[0].args[2]
        assert params['q'].startswith(gmail.QUERY) and params['maxResults'] == 20
        assert params['includeSpamTrash'] == 'false'
        committed = job.call_args.args[1]
        assert committed['cursor']['page'] == 'page2'
        encrypted = committed['messages'][0]['body_ciphertext']
        assert 'Motor' not in encrypted
        assert 'Motor' in gmail.unseal(encrypted, f'purchase-email:{cid}:abc123')['text']
        assert provider.get.call_args_list[1].args[2] == {'format': 'full'}


def test_disconnect_clears_local_access_before_google_revocation(configured):
    cid = str(uuid4())
    token = gmail.seal({'refresh_token': 'refresh'}, cid)
    with patch.object(gmail, 'manage', return_value={'connection_id': cid, 'token_ciphertext': token}) as manage, \
         patch.object(gmail, 'Gmail') as provider:
        provider.return_value.revoke.return_value = False
        result = gmail.disconnect('actor', 'inventory', True)
        assert manage.call_args.args[2] == 'purge'
        assert result == {'disconnected': True, 'purged': True, 'google_revocation_confirmed': False}


def test_revocation_token_is_post_body_not_url(configured):
    def handler(request):
        assert request.method == 'POST' and not request.url.query
        assert request.content == b'token=refresh-secret'
        return httpx.Response(200)
    provider = gmail.Gmail(httpx.Client(transport=httpx.MockTransport(handler)))
    assert provider.revoke('refresh-secret')

"""Personal OAuth grants with single-use states and cross-worker refresh leases."""
import hashlib
import os
import secrets
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode
from uuid import uuid4

import httpx
from fastapi import HTTPException

from app.services.supabase_client import get_supabase_raw
from .security import seal, unseal, cipher
from .onshape import request_json

AUTHORIZE = 'https://oauth.onshape.com/oauth/authorize'
TOKEN = 'https://oauth.onshape.com/oauth/token'
CALLBACK = 'https://www.findez.ai/cad/onshape/callback'


def settings():
    client, secret = os.getenv('ONSHAPE_CLIENT_ID', ''), os.getenv('ONSHAPE_CLIENT_SECRET', '')
    if not client or not secret:
        raise HTTPException(503, 'The Onshape app is awaiting registration. Use a flattened CSV export for now.')
    cipher()
    return client, secret


def enabled():
    try:
        settings()
        return True
    except HTTPException:
        return False


def start(actor):
    client, _ = settings()
    state = secrets.token_urlsafe(32)
    db = get_supabase_raw()
    # One pending grant per account; a later start invalidates the earlier tab.
    db.table('cad_oauth_states').upsert({'actor_id': actor, 'state_hash': hashlib.sha256(state.encode()).hexdigest(),
        'expires_at': (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()}).execute()
    return {'authorization_url': AUTHORIZE + '?' + urlencode({'client_id': client, 'response_type': 'code',
        'redirect_uri': CALLBACK, 'scope': 'OAuth2Read', 'state': state})}


async def exchange(**grant):
    client_id, client_secret = settings()
    async with httpx.AsyncClient(timeout=30, follow_redirects=False) as client:
        result = await request_json(client, 'POST', TOKEN, data={'client_id': client_id, 'client_secret': client_secret, **grant})
    if not isinstance(result.get('access_token'), str) or not result['access_token'] or not isinstance(result.get('refresh_token'), str):
        raise HTTPException(502, 'Onshape did not return a complete authorization. Connect again.')
    expires = result.get('expires_in')
    if type(expires) is not int or not 60 <= expires <= 86400:
        raise HTTPException(502, 'Onshape returned an invalid token lifetime.')
    return {'tokens': seal('onshape', {'access': result['access_token'], 'refresh': result['refresh_token']}),
            'expires_at': (datetime.now(timezone.utc) + timedelta(seconds=expires - 30)).isoformat()}


async def complete(actor, code, state):
    settings()
    db = get_supabase_raw()
    generation = str(uuid4())
    consumed = db.rpc('findez_cad_begin_connection', {'p_actor': actor,
        'p_state': hashlib.sha256(state.encode()).hexdigest(), 'p_generation': generation}).execute().data
    if not consumed:
        raise HTTPException(409, 'This Onshape connection request expired or was already used. Connect again.')
    # Generation guards prevent delayed callbacks from resurrecting a disconnected grant.
    grant = await exchange(grant_type='authorization_code', code=code, redirect_uri=CALLBACK)
    saved = db.table('cad_onshape_connections').update(grant).eq('actor_id', actor).eq('generation', generation).execute().data
    if not saved:
        raise HTTPException(409, 'The connection changed. Connect Onshape again.')
    return {'connected': True}


def status(actor):
    if not enabled():
        return {'enabled': False, 'connected': False}
    rows = get_supabase_raw().table('cad_onshape_connections').select('tokens').eq('actor_id', actor).limit(1).execute().data or []
    return {'enabled': True, 'connected': bool(rows and rows[0].get('tokens'))}


def disconnect(actor):
    settings()
    get_supabase_raw().rpc('findez_cad_disconnect', {'p_actor': actor}).execute()
    return {'connected': False}


async def access_token(actor):
    settings()
    db = get_supabase_raw()
    rows = db.table('cad_onshape_connections').select('*').eq('actor_id', actor).limit(1).execute().data or []
    if not rows or not rows[0].get('tokens'):
        raise HTTPException(409, 'Connect your Onshape account first.')
    row = rows[0]
    tokens = unseal('onshape', row['tokens'])
    if datetime.fromisoformat(row['expires_at']) > datetime.now(timezone.utc):
        return tokens['access'], row['generation']
    locked = db.rpc('findez_cad_refresh_lease', {'p_actor': actor, 'p_generation': row['generation']}).execute().data
    if not locked:
        raise HTTPException(409, 'Onshape is reconnecting in another request. Try again shortly.')
    try:
        grant = await exchange(grant_type='refresh_token', refresh_token=tokens['refresh'])
        saved = db.table('cad_onshape_connections').update({**grant, 'refresh_until': None}).eq('actor_id', actor).eq('generation', row['generation']).execute().data
        if not saved:
            raise HTTPException(409, 'Onshape was disconnected. Connect again.')
        return unseal('onshape', grant['tokens'])['access'], row['generation']
    except Exception:
        # Keep the lease until expiry after an unknown token-rotation outcome.
        raise


def assert_connected(actor, generation):
    rows = get_supabase_raw().table('cad_onshape_connections').select('generation').eq('actor_id', actor).eq('generation', generation).limit(1).execute().data
    if not rows:
        raise HTTPException(409, 'Onshape was disconnected while comparing. Connect again.')

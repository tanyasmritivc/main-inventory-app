"""Run only against a disposable database: API_TEST_ADMIN_DSN is required."""
import os
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import asyncpg
import httpx
import pytest
import pytest_asyncio
from fastapi import FastAPI
from pydantic import SecretStr

from app.api.v1 import auth, routes, database
from app.api.v1.crypto import create_secret, verify_secret
from app.core.auth import AuthenticatedUser

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def env(monkeypatch):
    dsn = os.environ.get('API_TEST_ADMIN_DSN')
    if not dsn:
        pytest.skip('Set API_TEST_ADMIN_DSN to a disposable PostgreSQL database')
    admin = await asyncpg.connect(dsn)
    # The fixture uses a fresh database per test, never drops an existing database.
    dbname = 'api_test_' + uuid4().hex
    await admin.execute(f'CREATE DATABASE {dbname}')
    from urllib.parse import urlsplit, urlunsplit
    url = urlsplit(dsn)
    test_dsn = urlunsplit(url._replace(path='/' + dbname))
    conn = await asyncpg.connect(test_dsn)
    for role in ('anon', 'authenticated'):
        if not await conn.fetchval('SELECT 1 FROM pg_roles WHERE rolname=$1', role):
            await conn.execute(f'CREATE ROLE {role}')
    # API role is cluster-wide; provision it once and omit only CREATE ROLE on subsequent tests.
    migration = (Path(__file__).parents[2] / 'supabase/migrations/032_api_keys.sql').read_text()
    if await conn.fetchval("SELECT 1 FROM pg_roles WHERE rolname='findez_api'"):
        migration = migration.replace('CREATE ROLE findez_api LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;', '')
    await conn.execute("CREATE SCHEMA auth; CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid $$; GRANT USAGE ON SCHEMA auth TO PUBLIC")
    await conn.execute((Path(__file__).parents[2] / 'supabase/migrations/001_init.sql').read_text())
    await conn.execute('CREATE POLICY legacy_update ON public.items FOR UPDATE USING(auth.uid()=user_id) WITH CHECK(auth.uid()=user_id)')
    await conn.execute(migration)
    user, org, other_org, ws, sibling, foreign = [uuid4() for _ in range(6)]
    await conn.execute("INSERT INTO organizations VALUES($1,'A'),($2,'B')", org, other_org)
    await conn.execute("INSERT INTO organization_memberships VALUES($1,$2,'admin')", org, user)
    await conn.execute("INSERT INTO workspaces(id,org_id,name) VALUES($1,$2,'One'),($3,$2,'Two'),($4,$5,'Foreign')", ws, org, sibling, foreign, other_org)
    for location, workspace in [('One',ws),('Two',sibling),('Foreign',foreign),('Legacy',None)]:
        # Same owner deliberately exercises the legacy permissive RLS policy.
        await conn.execute("INSERT INTO items(user_id,workspace_id,name,category,quantity,location) VALUES($1,$2,'Part','Parts',2,$3)", user, workspace, location)
    role_url = urlunsplit(url._replace(netloc='findez_api@' + url.netloc.split('@')[-1], path='/' + dbname))
    settings = SimpleNamespace(api_keys_environment='test', api_keys_database_url=SecretStr(role_url))
    for module in (auth, routes, database):
        monkeypatch.setattr(module, 'get_settings', lambda: settings)
    app = FastAPI(lifespan=database.integration_lifespan)
    app.include_router(routes.router)
    async def fake_session(request, creds):
        if creds.credentials != 'valid-session':
            raise auth.APIError(401,'session_required','Session required')
        return AuthenticatedUser(str(user))
    monkeypatch.setattr(auth, 'get_current_user', fake_session)
    async with database.integration_lifespan(app):
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),base_url='http://test') as client:
            yield SimpleNamespace(client=client, conn=conn, app=app, user=user, org=org, ws=ws, sibling=sibling, foreign=foreign)
    await conn.close()
    await admin.execute(f'DROP DATABASE {dbname}')
    await admin.close()


def headers(key):
    return {'Authorization': 'Bearer ' + key}


async def mint(env, scopes, workspace=True):
    response = await env.client.post('/api/v1/keys', headers=headers('valid-session'), json={
        'name':'ERP', 'workspace_id':str(env.ws) if workspace else None,'scopes':scopes})
    assert response.status_code == 201, response.text
    return response.json()


async def test_key_lifecycle_and_errors(env):
    key = await mint(env,['items:read'])
    assert key['key'].startswith('findez_test_sk_') and len(key['key'].split('_sk_')[1]) == 32
    row = await env.conn.fetchrow('SELECT * FROM api_keys WHERE id=$1',key['id'])
    assert row['key_prefix']==key['key'][:20] and row['key_hash'].startswith('$argon2id$')
    assert await verify_secret(key['key'],row['key_hash'])
    result = await env.client.get('/api/v1/keys',headers=headers('valid-session'))
    assert key['key'] not in result.text and 'key_hash' not in result.text
    assert (await env.client.post('/api/v1/keys',headers=headers(key['key']),json={'name':'x','scopes':['org:read']})).status_code==401
    for token in ('bad',key['key'][:-1]+('A' if key['key'][-1]!='A' else 'B'),key['key'].replace('_test_','_live_')):
        result=await env.client.get('/api/v1/items',headers=headers(token))
        assert result.status_code==401 and result.json()['error']['code']=='invalid_api_key'
        assert result.headers['X-Correlation-ID']==result.json()['error']['correlation_id']
    assert (await env.client.get('/api/v1/spaces',headers=headers(key['key']))).status_code==403
    assert (await env.client.get('/api/v1/items',headers=headers(key['key']))).status_code==200
    assert await env.conn.fetchval('SELECT last_used_at IS NOT NULL FROM api_keys WHERE id=$1',key['id'])
    await env.conn.execute("UPDATE api_keys SET expires_at=now()-interval '1 second' WHERE id=$1",key['id'])
    assert (await env.client.get('/api/v1/items',headers=headers(key['key']))).status_code==401
    assert (await env.client.delete('/api/v1/keys/'+key['id'],headers=headers('valid-session'))).status_code==204
    assert await env.conn.fetchval('SELECT revoked_at IS NOT NULL FROM api_keys WHERE id=$1',key['id'])


async def test_rls_unfiltered_queries_and_pool_reset(env):
    key=await mint(env,['items:read'])
    claims={'sub':str(env.user),'auth_kind':'api_key','api_key_id':key['id'],'api_scope':'items:read','environment':'test'}
    # Initialize the real validated restricted-role pool through the HTTP dependency.
    result=await env.client.get('/api/v1/items',headers=headers(key['key']))
    assert [r['location'] for r in result.json()['data']]==['One']
    async with env.app.state.api_key_pool.acquire() as conn:
        async with conn.transaction():
            await database.set_claims(conn,claims)
            assert await conn.fetchval('SELECT count(*) FROM items')==1
            with pytest.raises(asyncpg.InsufficientPrivilegeError):
                async with conn.transaction():
                    await conn.execute("INSERT INTO items(user_id,workspace_id,name,category,quantity,location) VALUES($1,$2,'Bad','X',1,'X')",env.user,env.ws)
            assert await conn.execute("UPDATE items SET quantity=99")=='UPDATE 0'
            with pytest.raises(asyncpg.InsufficientPrivilegeError):
                async with conn.transaction():
                    await conn.fetch('SELECT key_hash FROM api_keys')
        assert await conn.fetchval('SELECT count(*) FROM items')==0
    global_key=await mint(env,['org:read'],False)
    result=await env.client.get('/api/v1/items',headers=headers(global_key['key']))
    assert {r['location'] for r in result.json()['data']}=={'One','Two'}
    result=await env.client.get('/api/v1/workspaces/summary',headers=headers(global_key['key']))
    assert len(result.json()['data'])==2 and all(r['total_parts']==2 for r in result.json()['data'])


async def test_bulk_writes_and_atomic_rollback(env):
    key=await mint(env,['import:write','items:read','workspace:read'])
    payload={'name':'Motor','category':'Parts','quantity':3,'location':'Shelf','source_system':'ERP','external_id':'123'}
    h=headers(key['key'])
    assert (await env.client.post('/api/v1/items',headers=h,json=payload)).status_code==403
    first=await env.client.post('/api/v1/items/bulk',headers=h,json={'items':[payload]})
    assert first.status_code==200, first.text
    payload['quantity']=7
    second=await env.client.post('/api/v1/items/bulk',headers=h,json={'items':[payload]})
    assert second.status_code==200,second.text
    assert first.json()['data'][0]['item_id']==second.json()['data'][0]['item_id']
    assert second.json()['data'][0]['quantity']==7
    result=await env.client.get('/api/v1/spaces',headers=h)
    assert {r['location'] for r in result.json()['data']}=={'One','Shelf'}
    global_key=await mint(env,['org:write'],False)
    payload['external_id']='rollback'
    result=await env.client.post('/api/v1/items/bulk',headers=headers(global_key['key']),json={'items':[
        dict(payload,workspace_id=str(env.ws)),dict(payload,workspace_id=str(env.foreign))]})
    assert result.status_code==403,result.text
    assert await env.conn.fetchval("SELECT count(*) FROM items WHERE external_id='rollback'")==0
    writer=await mint(env,['items:write'])
    h=headers(writer['key'])
    result=await env.client.patch('/api/v1/items/'+first.json()['data'][0]['item_id'],headers=h,json={'quantity':8})
    assert result.status_code==200,result.text
    foreign_id=await env.conn.fetchval('SELECT item_id FROM items WHERE workspace_id=$1',env.foreign)
    assert (await env.client.patch('/api/v1/items/'+str(foreign_id),headers=h,json={'quantity':9})).status_code==404
    assert (await env.client.post('/api/v1/items/bulk',headers=h,json={'items':[payload]})).status_code==403


async def test_rate_limits_and_validation(env):
    key=await mint(env,['items:read'])
    h=headers(key['key'])
    await env.client.get('/api/v1/items',headers=h)
    await env.conn.execute('UPDATE api_private.rate_windows SET requests=120 WHERE key_id=$1',key['id'])
    result=await env.client.get('/api/v1/items',headers=h)
    assert result.status_code==429 and result.headers['Retry-After']=='60'
    result=await env.client.post('/api/v1/keys',headers=headers('valid-session'),json={'name':'bad','workspace_id':str(env.ws),'scopes':['org:write']})
    assert result.status_code==422 and 'input' not in result.text
    result=await env.client.post('/api/v1/keys',headers=headers('valid-session'),json={'name':'bad','workspace_id':str(env.foreign),'scopes':['items:read']})
    assert result.status_code==409 and 'SQL' not in result.text
    result=await env.client.get('/api/v1/keys',headers={**headers('valid-session'),'X-FindEZ-Org-ID':str(uuid4())})
    assert result.status_code==403


async def test_pagination_global_create_and_revocation_at_database(env):
    key=await mint(env,['org:read','org:write'],False)
    h=headers(key['key'])
    body={'name':'New','category':'Parts','quantity':4,'location':'Drawer','workspace_id':str(env.sibling)}
    result=await env.client.post('/api/v1/items',headers=h,json=body)
    assert result.status_code==201,result.text
    ids=[]
    cursor=None
    while True:
        result=await env.client.get('/api/v1/items',headers=h,params={'limit':1,**({'after':cursor} if cursor else {})})
        assert result.status_code==200,result.text
        ids.extend(row['item_id'] for row in result.json()['data'])
        cursor=result.json()['next_cursor']
        if cursor is None:
            break
    assert len(ids)==len(set(ids))==3
    async with env.app.state.api_key_pool.acquire() as conn:
        async with conn.transaction():
            await database.set_claims(conn,{'sub':str(env.user),'auth_kind':'api_key','api_key_id':key['id'],'api_scope':'items:read','environment':'test'})
            assert await conn.fetchval('SELECT count(*) FROM items')==3
            await env.conn.execute('UPDATE api_keys SET revoked_at=now() WHERE id=$1',key['id'])
            assert await conn.fetchval('SELECT count(*) FROM items')==0
    result=await env.client.get('/api/v1/items',headers=h)
    assert result.status_code==401


async def test_unsafe_role_fails_closed(env,monkeypatch):
    monkeypatch.setattr(database,'get_settings',lambda:SimpleNamespace(
        api_keys_database_url=SecretStr(os.environ['API_TEST_ADMIN_DSN'])))
    result=await env.client.get('/api/v1/items',headers=headers('findez_test_sk_'+'A'*32))
    assert result.status_code==503,result.text
    assert result.json()['error']['code']=='unsafe_database_role'


async def test_prefix_collision_and_bulk_rate_limit(env):
    key=await mint(env,['import:write'])
    _,_,wrong_hash=await create_secret('test')
    await env.conn.execute("INSERT INTO api_keys(org_id,workspace_id,name,key_prefix,key_hash,scopes,created_by) VALUES($1,$2,'Collision',$3,$4,ARRAY['items:read'],$5)",env.org,env.ws,key['key_prefix'],wrong_hash,env.user)
    body={'items':[{'name':'Bolt','category':'Parts','quantity':1,'location':'Box','source_system':'ERP','external_id':'1'}]}
    result=await env.client.post('/api/v1/items/bulk',headers=headers(key['key']),json=body)
    assert result.status_code==200,result.text
    await env.conn.execute('UPDATE api_private.rate_windows SET bulk_requests=10 WHERE key_id=$1',key['id'])
    result=await env.client.post('/api/v1/items/bulk',headers=headers(key['key']),json=body)
    assert result.status_code==429

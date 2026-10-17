"""Real HTTP scope and legacy-route regressions; SQL tests cover stored policy."""
from types import SimpleNamespace
from uuid import uuid4

from fastapi import Request
from app.core.auth import AuthenticatedUser, get_current_user
from app.services.resource_access import begin_actor, request_actor
from app.api.routes.inventory_workspaces import inventory_role
from backend.tests.test_inventory_journeys import api, OWNER, MEMBER, VIEWER, TEAM, TEAM_INV


def enable_actor(client, db):
    async def actor(request: Request):
        user_id = request.headers.get('x-test-actor', OWNER)
        begin_actor(user_id)
        return AuthenticatedUser(user_id=user_id)
    client.app.dependency_overrides[get_current_user] = actor
    def rpc(name, data):
        assert name == 'findez_inventory_fences'
        memberships = {r['team_id']: r['role'] for r in db.rows['team_memberships'] if r['user_id'] == data['p_actor']}
        rows = []
        for inv in db.rows['app_inventories']:
            if inv.get('access_mode', 'legacy') == 'legacy': continue
            role = memberships.get(inv['team_id'])
            grants = [r for r in db.rows['app_inventory_members'] if r['user_id'] == data['p_actor']]
            effective = inventory_role(inv, {'role':role}, data['p_actor'], grants) if role else None
            rows.append({'inventory_id':inv['inventory_id'],'team_id':inv['team_id'],'role':effective})
        return SimpleNamespace(execute=lambda:SimpleNamespace(data=rows))
    db.rpc = rpc


def test_restricted_inventory_cannot_be_reached_via_ids_legacy_team_or_owned_search(api):
    client,db = api
    inv = next(r for r in db.rows['app_inventories'] if r['inventory_id']==TEAM_INV)
    inv.update(access_mode='restricted',default_role='viewer')
    # The original creator now has only a workspace membership, no inventory grant.
    db.rows['items'][-2]['user_id'] = MEMBER
    db.rows['team_spaces'] = [{'team_id':TEAM,'space_id':TEAM_INV,'team_space_id':str(uuid4())}]
    enable_actor(client,db)
    headers={'x-test-actor':MEMBER}
    assert client.get(f'/inventories/{TEAM_INV}',headers=headers).status_code==403
    assert client.get(f'/inventories/{TEAM_INV}/access',headers=headers).status_code==403
    assert client.get(f'/inventories/{TEAM_INV}/audit',headers=headers).status_code==403
    assert client.get(f'/teams/{TEAM}/spaces/{TEAM_INV}/items',headers=headers).status_code==404
    result=client.post('/search_items',headers=headers,json={'query':''})
    assert result.status_code==200,result.text
    assert result.json()['items']==[]
    assert request_actor.get() is None


def test_editor_override_viewer_default_revocation_and_cache_scope(api):
    client,db=api
    inv=next(r for r in db.rows['app_inventories'] if r['inventory_id']==TEAM_INV)
    inv.update(access_mode='workspace',default_role='viewer')
    enable_actor(client,db)
    headers={'x-test-actor':MEMBER}
    assert client.get(f'/inventories/{TEAM_INV}',headers=headers).json()['inventory']['role']=='viewer'
    assert client.patch(f'/inventories/{TEAM_INV}/update_item',headers=headers,json={'item_id':TEAM_INV,'quantity':9}).status_code==403
    db.rows['app_inventory_members']=[{'inventory_id':TEAM_INV,'user_id':MEMBER,'role':'editor'}]
    assert client.patch(f'/inventories/{TEAM_INV}/update_item',headers=headers,json={'item_id':TEAM_INV,'quantity':9}).status_code==200
    result=client.post(f'/inventories/{TEAM_INV}/search_items',headers=headers,json={'query':''})
    assert result.status_code==200,result.text
    assert result.json()['items'][0]['quantity']==9
    db.rows['app_inventory_members'][0]['role']='none'
    assert client.post(f'/inventories/{TEAM_INV}/search_items',headers=headers,json={'query':''}).status_code==403
    result=client.post('/search_items',headers=headers,json={'query':''})
    assert result.status_code==200 and result.json()['items']==[]


def test_members_view_is_inventory_specific_not_entire_workspace(api):
    client,db=api
    inv=next(r for r in db.rows['app_inventories'] if r['inventory_id']==TEAM_INV)
    inv.update(access_mode='restricted',default_role='viewer')
    db.rows['app_inventory_members']=[{'inventory_id':TEAM_INV,'user_id':MEMBER,'role':'viewer'}]
    result=client.get(f'/inventories/{TEAM_INV}/access',headers={'x-test-actor':MEMBER})
    assert result.status_code==200,result.text
    assert {m['user_id'] for m in result.json()['members']}=={OWNER,MEMBER}
    assert result.json()['inventory']['can_manage'] is False
    # Removal invalidates a surviving grant even if database cleanup is delayed.
    db.rows['team_memberships']=[m for m in db.rows['team_memberships'] if m['user_id']!=MEMBER]
    assert client.get(f'/inventories/{TEAM_INV}/access',headers={'x-test-actor':MEMBER}).status_code==403


def test_legacy_viewer_cannot_modify_owned_files_or_photos(api):
    client,db=api
    inv=next(r for r in db.rows['app_inventories'] if r['inventory_id']==TEAM_INV)
    inv.update(access_mode='workspace',default_role='viewer')
    item=next(r for r in db.rows['items'] if r['inventory_id']==TEAM_INV)
    item['user_id']=MEMBER
    path=f'{MEMBER}/note.txt'
    db.rows['documents'].append({'user_id':MEMBER,'inventory_id':TEAM_INV,'storage_path':path,'filename':'note.txt','mime_type':'text/plain'})
    enable_actor(client,db)
    headers={'x-test-actor':MEMBER}
    for result in [
        client.patch('/documents/note',headers=headers,json={'storage_path':path,'text':'Forbidden'}),
        client.delete('/documents',headers=headers,params={'storage_path':path}),
        client.post(f'/items/{TEAM_INV}/photos',headers=headers,files={'file':('photo.jpg',b'not uploaded','image/jpeg')}),
        client.delete(f'/items/{TEAM_INV}/photos/primary',headers=headers),
    ]:
        assert result.status_code==403,result.text
    db.storage.from_.assert_not_called()
    assert db.writes==[]

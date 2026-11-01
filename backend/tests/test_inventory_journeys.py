"""Exercise real HTTP routers and repository queries against a bounded store.

No model, storage server, credentials or customer records are used.
"""
from collections import defaultdict
from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi import Request
from fastapi.testclient import TestClient

from app.core.auth import AuthenticatedUser, get_current_user
from app.main import create_app
from app.services import items_repo
from app.services.inventory_scope import current_inventory

OWNER, OTHER, MEMBER, VIEWER = [str(uuid4()) for _ in range(4)]
A, B, TEAM_INV, FOREIGN, TEAM = [str(uuid4()) for _ in range(5)]


class Query:
    def __init__(self, db, table):
        self.db,self.table = db,table
        self.filters,self.fields,self.operation,self.payload = [],'*','read',None
        self.start,self.end = 0,1000
        self.negated=False
        self.headers={}
    def select(self, fields='*', **kwargs): self.fields=fields; return self
    def eq(self,key,value): self.filters.append(lambda row: row.get(key)==value); return self
    def in_(self,key,values):
        negated=self.negated; self.negated=False
        self.filters.append(lambda row: (row.get(key) in values) != negated); return self
    @property
    def not_(self): self.negated=True; return self
    def is_(self,key,value):
        negated=self.negated; self.negated=False
        self.filters.append(lambda row: ((row.get(key) is None) if value=='null' else row.get(key)==value) != negated)
        return self
    def or_(self,expression):
        alternatives=[part.split('.',2) for part in expression.split(',')]
        self.filters.append(lambda row:any(row.get(key)==value for key,op,value in alternatives if op=='eq'))
        return self
    def order(self,*args,**kwargs): return self
    def limit(self,value): self.end=value; return self
    def maybe_single(self): return self
    def range(self,start,end): self.start,self.end=start,end+1; return self
    def insert(self,payload,**kwargs): self.operation,self.payload='insert',payload; return self
    def update(self,payload,**kwargs): self.operation,self.payload='update',payload; return self
    def delete(self,**kwargs): self.operation='delete'; return self
    def execute(self):
        rows=self.db.rows[self.table]
        if self.table=='app_inventory_space_summaries':
            rows=[{**space,'item_count':sum(item.get('space_id')==space['id'] for item in self.db.rows['items'])} for space in self.db.rows['spaces']]
        matches=[row for row in rows if all(test(row) for test in self.filters)]
        if self.operation=='insert':
            matches=[]
            for data in self.payload if isinstance(self.payload,list) else [self.payload]:
                row={'id':str(uuid4()),'created_at':'2026-10-14T00:00:00Z',**data}
                rows.append(row); matches.append(row)
            self.db.writes.append((self.table,self.operation,deepcopy(matches)))
        elif self.operation=='update':
            for row in matches: row.update(self.payload)
            self.db.writes.append((self.table,self.operation,deepcopy(matches)))
        elif self.operation=='delete':
            self.db.rows[self.table]=[row for row in rows if row not in matches]
            self.db.writes.append((self.table,self.operation,deepcopy(matches)))
        selected=matches[self.start:self.end]
        if self.fields!='*': selected=[{key.strip():row.get(key.strip()) for key in self.fields.split(',')} for row in selected]
        return SimpleNamespace(data=deepcopy(selected),count=len(matches))


@pytest.fixture
def api():
    db=SimpleNamespace(rows=defaultdict(list),writes=[],storage=MagicMock())
    db.table=lambda table:Query(db,table)
    for inv,owner,team in [(A,OWNER,None),(B,OWNER,None),(TEAM_INV,OWNER,TEAM),(FOREIGN,OTHER,None)]:
        db.rows['app_inventories'].append({'inventory_id':inv,'owner_user_id':owner,'team_id':team,'name':inv,'is_default':True})
        db.rows['spaces'].append({'id':inv,'user_id':owner,'inventory_id':inv,'name':'Drawer','created_at':'2026-10-14T00:00:00Z'})
        db.rows['items'].append({'item_id':inv,'user_id':owner,'inventory_id':inv,'space_id':inv,'name':'Soldering iron','category':'Tools','quantity':1,'location':'Drawer'})
    db.rows['teams']=[{'team_id':TEAM,'owner_user_id':OWNER,'name':'Workshop'}]
    db.rows['team_memberships']=[{'team_id':TEAM,'user_id':actor,'role':role} for actor,role in [(OWNER,'owner'),(MEMBER,'member'),(VIEWER,'viewer')]]
    db.rows['documents']=[{'user_id':OWNER,'inventory_id':inv,'storage_path':path,'filename':'notes.txt','inventory_visibility':visibility,'mime_type':'text/plain'}
        for inv,path,visibility in [(A,f'{OWNER}/a.txt','inventory'),(B,f'{OWNER}/b.txt','inventory'),(TEAM_INV,f'{OWNER}/private.txt','personal'),(TEAM_INV,f'{OWNER}/shared.txt','inventory')]]
    app=create_app()
    async def actor(request:Request): return AuthenticatedUser(user_id=request.headers.get('x-test-actor',OWNER))
    app.dependency_overrides[get_current_user]=actor
    items_repo._INVENTORY_CACHE.clear()
    with patch('app.services.supabase_client.get_supabase_raw',return_value=db), \
         patch('app.api.routes.inventory_workspaces.get_supabase_raw',return_value=db), \
         patch('app.api.routes.collaboration.get_supabase_raw',return_value=db), \
         patch('app.api.routes.items.parse_search_query_to_keywords',side_effect=lambda query:{'text':query}), \
         patch('app.services.catalog_service.save_to_catalog'), \
         patch('app.services.limits.resolve_effective_limits',return_value=({'spaces':None},None)):
        yield TestClient(app),db
    items_repo._INVENTORY_CACHE.clear()
    assert current_inventory.get() is None


def test_http_reads_and_writes_stay_in_the_selected_inventory(api):
    client,db=api
    for inv in (A,B):
        result=client.post(f'/inventories/{inv}/search_items',json={'query':''})
        assert result.status_code==200,result.text
        assert [item['item_id'] for item in result.json()['items']]==[inv]
    result=client.patch(f'/inventories/{A}/update_item',json={'item_id':A,'quantity':7})
    assert result.status_code==200,result.text
    assert client.post(f'/inventories/{B}/search_items',json={'query':''}).json()['items'][0]['quantity']==1
    before=deepcopy(db.rows)
    assert client.patch(f'/inventories/{A}/update_item',json={'item_id':B,'location':'New room'}).status_code==404
    assert dict(db.rows)==dict(before)
    assert client.get(f'/inventories/{FOREIGN}/spaces').status_code==403
    # The old route is unchanged and the request-local context is reset.
    assert {space['id'] for space in client.get('/spaces').json()['spaces']}=={A,B,TEAM_INV}


def test_member_access_viewer_read_only_and_foreign_parent_rejection(api):
    client,db=api
    member={'x-test-actor':MEMBER}; viewer={'x-test-actor':VIEWER}
    assert client.get(f'/inventories/{TEAM_INV}/spaces',headers=member).status_code==200
    assert client.get(f'/inventories/{TEAM_INV}/spaces',headers=viewer).status_code==200
    writes=len(db.writes)
    assert client.patch(f'/inventories/{TEAM_INV}/update_item',headers=viewer,json={'item_id':TEAM_INV,'quantity':99}).status_code==403
    assert len(db.writes)==writes
    assert client.get(f'/inventories/{A}/spaces',headers=member).status_code==403
    result=client.patch(f'/inventories/{TEAM_INV}/update_item',headers=member,json={'item_id':TEAM_INV,'quantity':2})
    assert result.status_code==200,result.text
    result=client.post(f'/inventories/{TEAM_INV}/spaces/{B}/bins',headers=member,json={'name':'Foreign parent'})
    assert result.status_code==404,result.text
    assert next(item for item in db.rows['items'] if item['item_id']==TEAM_INV)['space_id']==TEAM_INV


def test_private_chats_stay_actor_private_and_document_deletion_authorizes_before_storage(api):
    client,db=api
    member={'x-test-actor':MEMBER};viewer={'x-test-actor':VIEWER}
    private=client.post(f'/inventories/{TEAM_INV}/conversations',headers=member)
    assert private.status_code==200,private.text
    conversation=private.json()['id']
    assert client.get(f'/inventories/{TEAM_INV}/conversations',headers=viewer).json()==[]
    assert client.get(f'/inventories/{TEAM_INV}/conversations/{conversation}',headers=viewer).status_code==404
    assert client.get(f'/inventories/{B}/conversations/{conversation}',headers=member).status_code==403
    visible=client.get(f'/inventories/{TEAM_INV}/documents',headers=member)
    assert visible.status_code==200,visible.text
    assert [doc['storage_path'] for doc in visible.json()['documents']]==[f'{OWNER}/shared.txt']
    assert visible.json()['documents'][0]['inventory_id']==TEAM_INV
    assert client.delete(f'/inventories/{A}/documents',params={'storage_path':f'{OWNER}/b.txt'}).status_code==404
    assert client.patch(f'/inventories/{TEAM_INV}/documents/note',headers=member,json={'storage_path':f'{OWNER}/private.txt','text':'Forged'}).status_code==404
    db.storage.from_.assert_not_called()
    assert client.patch(f'/inventories/{TEAM_INV}/documents/note',headers=member,json={'storage_path':f'{OWNER}/shared.txt','text':'Updated note'}).status_code==200
    db.storage.from_().update.assert_called_once()


def test_scoped_search_includes_items_beyond_the_rest_page_limit(api):
    client,db=api
    db.rows['items'] += [{**db.rows['items'][0],'item_id':str(uuid4()),'name':f'Part {n}'} for n in range(1105)]
    result=client.post(f'/inventories/{A}/search_items',json={'query':''})
    assert result.status_code==200,result.text
    assert len(result.json()['items'])==1106
    assert len({item['item_id'] for item in result.json()['items']})==1106


def test_capture_receipts_persist_retrieve_and_retry_without_cross_inventory_duplicates(api):
    client,db=api
    body={'items':[{'name':'Loose screw','category':'Hardware','quantity':2,'location':'Drawer','client_request_id':'same-capture-draft'}]}
    with patch('app.api.routes.items.is_pro_user',return_value=True):
        first=client.post(f'/inventories/{A}/inventory/bulk_create',json=body)
        assert first.status_code==200,first.text
        assert first.json()['failures']==[],first.text
        receipt=first.json()['inserted'][0]
        again=client.post(f'/inventories/{A}/inventory/bulk_create',json=body)
        assert again.json()['inserted'][0]['item_id']==receipt['item_id']
        other=client.post(f'/inventories/{B}/inventory/bulk_create',json=body)
        assert other.json()['inserted'][0]['item_id']!=receipt['item_id']
    found=client.post(f'/inventories/{A}/search_items',json={'query':'Loose screw'}).json()['items']
    assert len(found)==1 and found[0]['item_id']==receipt['item_id'] and found[0]['quantity']==2
    assert found[0]['space_id']==A

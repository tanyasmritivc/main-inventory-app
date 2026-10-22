from contextlib import contextmanager
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace as NS
from unittest.mock import patch
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.services import chat_photo_attachment as photos, world_chat as world
from app.services.chat_item_actions import use_photo
from backend.tests.test_world_chat_routes import transport, ACTOR, WORLD, CID, events

INV, ITEM, OTHER = [str(uuid4()) for _ in range(3)]
SOURCE = f'https://storage.test/storage/v1/object/public/images/{ACTOR}/ask-abc.jpg'
inv = {'inventory_id': INV, 'owner_user_id': ACTOR, 'can_edit': True, 'name': 'Parts', 'workspace': {'name': 'Lab'}}
item = {'item_id': ITEM, 'inventory_id': INV, 'name': 'Arduino Uno', 'location': 'Shelf A', 'quantity': 12, 'image_url': None}
@contextmanager
def scope(*args):
    assert args[-1] == INV
    yield inv

def choice():
    return {'item_id': ITEM, 'inventory_id': INV, 'name': item['name'], 'location': item['location'], 'workspace_name': 'Lab', 'inventory_name': 'Parts', 'match': 'similar'}
def card():
    return {'version': 1, 'id': str(uuid4()), 'conversation_id': CID, 'revision': 1, 'status': 'pending',
            'source_url': SOURCE, 'choices': [choice()], 'query': 'Ardunio Uno',
            'expires_at': (datetime.now(timezone.utc)+timedelta(minutes=30)).isoformat()}

@pytest.mark.parametrize('query', ['Ardunio Uno', 'arduino uno', 'Arduino Unoo'])
def test_typo_ranking_without_claiming_identity(query):
    assert photos.rank(query, item) > .68
    assert photos.rank('resistor', item) < .68
    if query != 'arduino uno': assert photos.rank(query, item) < 1

def test_model_number_difference_is_similar_not_exact():
    assert .68 < photos.rank('ESP32', {'name':'ESP33'}) < 1

def test_proposal_preserves_duplicate_locations_and_does_not_write():
    second = {**item, 'item_id': OTHER, 'location': 'Shelf B'}
    with use_photo({'source_url': SOURCE, 'items': []}), patch.object(world,'directory',return_value={'inventories':[inv]}), patch.object(world,'in_inventory',side_effect=scope), patch('app.services.ai_agent._current_items',return_value=[item,second]), patch('app.services.item_photos._storage_path',return_value='owned'), patch.object(photos,'get_supabase_raw') as write:
        result = photos.propose(ACTOR,WORLD,{'query':'Ardunio Uno'})
    assert len(result['photo_attachment']['choices']) == 2
    assert all(c['match'] == 'similar' for c in result['photo_attachment']['choices'])
    assert result['saved'] is False
    write.assert_not_called()

def test_missing_photo_and_revoked_scope_cannot_propose():
    with pytest.raises(HTTPException): photos.propose(ACTOR,WORLD,{'query':'Arduino'})
    with use_photo({'source_url':SOURCE,'items':[]}), patch('app.services.item_photos._storage_path',return_value='owned'), patch.object(world,'inventory_scope',side_effect=HTTPException(403,'Revoked')):
        with pytest.raises(HTTPException): photos.propose(ACTOR,WORLD,{'query':'Arduino','inventory_id':INV})

@pytest.fixture
def state():
    c=card(); data={'id':str(uuid4()), 'answer_context':{'photo_attachment':c}}
    def load(*args): return deepcopy(data)
    def replace(cid,row,new):
        assert row['answer_context']['photo_attachment']['revision'] == data['answer_context']['photo_attachment']['revision']
        data['answer_context']['photo_attachment'] = deepcopy(new)
        return new
    with patch.object(photos,'load',side_effect=load), patch.object(photos,'replace',side_effect=replace), patch.object(world,'in_inventory',side_effect=scope), patch.object(photos,'_link',return_value={'photo_added':True,'item_id':ITEM}) as link:
        yield NS(data=data, c=c, link=link)

def test_cancel_is_durable_and_never_writes_photo(state):
    a=photos.decide(ACTOR,WORLD,CID,state.c['id'],'cancel')
    assert a['status']=='cancelled'
    assert photos.decide(ACTOR,WORLD,CID,state.c['id'],'confirm',INV,ITEM)['status']=='cancelled'
    state.link.assert_not_called()

def test_only_presented_exact_id_can_be_confirmed(state):
    with pytest.raises(HTTPException): photos.decide(ACTOR,WORLD,CID,state.c['id'],'confirm',INV,OTHER)
    state.link.assert_not_called()

def test_lost_write_response_freezes_target_and_retry_resumes(state):
    state.link.side_effect=[HTTPException(503,'Retry'),{'photo_added':True,'item_id':ITEM}]
    with pytest.raises(HTTPException): photos.decide(ACTOR,WORLD,CID,state.c['id'],'confirm',INV,ITEM)
    assert state.data['answer_context']['photo_attachment']['status']=='saving'
    with pytest.raises(HTTPException): photos.decide(ACTOR,WORLD,CID,state.c['id'],'cancel')
    with pytest.raises(HTTPException): photos.decide(ACTOR,WORLD,CID,state.c['id'],'confirm',INV,OTHER)
    assert photos.decide(ACTOR,WORLD,CID,state.c['id'],'confirm',INV,ITEM)['status']=='confirmed'
    photos.decide(ACTOR,WORLD,CID,state.c['id'],'confirm',INV,ITEM)
    assert state.link.call_count==2

def test_expired_or_revoked_photo_request_does_not_write(state):
    state.data['answer_context']['photo_attachment']['expires_at']='2020-01-01T00:00:00+00:00'
    with pytest.raises(HTTPException): photos.decide(ACTOR,WORLD,CID,state.c['id'],'confirm',INV,ITEM)
    state.link.assert_not_called()

class Store:
    def __init__(self, primary=None):
        self.item={**item,'image_url':primary}; self.events=[]; self.lost=False; self.inserts=0
    def table(self, name): return Query(self,name)
class Query:
    def __init__(self,store,name): self.store,self.name=store,name;self.filters=[];self.payload=None;self.op='select'
    def select(self,*a): return self
    def eq(self,k,v): self.filters.append((k,v));return self
    def is_(self,k,v): return self.eq(k,None)
    def limit(self,*a):return self
    def insert(self,p):self.op='insert';self.payload=p;return self
    def update(self,p):self.op='update';self.payload=p;return self
    def execute(self):
        rows=self.store.events if self.name=='item_events' else [self.store.item]
        if self.op=='insert':
            self.store.inserts+=1;self.store.events.append(self.payload)
            if self.store.lost: self.store.lost=False;raise RuntimeError('Response lost after commit')
            return NS(data=[self.payload])
        matched=[r for r in rows if all(r.get(k)==v for k,v in self.filters)]
        if self.op=='update':
            for row in matched:row.update(self.payload)
        return NS(data=deepcopy(matched))

@pytest.mark.parametrize('primary', [None,'existing-photo'])
def test_actual_link_is_idempotent_preserves_quantity_and_primary(primary):
    db=Store(primary);db.item['user_id']=ACTOR;db.lost=True;c=card()
    with patch.object(photos,'get_supabase_admin',return_value=db), patch('app.services.item_photos._storage_path',return_value='owned'), patch('app.services.item_photos._get_item',side_effect=lambda **kw:deepcopy(db.item)), patch('app.services.item_photos._photo_events',side_effect=lambda **kw:db.events), patch('app.services.items_repo.invalidate_inventory_cache'):
        first=photos._link(ACTOR,inv,c,choice());second=photos._link(ACTOR,inv,c,choice())
    assert first==second and db.inserts==1 and db.item['quantity']==12
    assert db.item['image_url']==(primary or SOURCE)

def test_changed_identity_is_not_silently_linked():
    db=Store();db.item['name']='Different part'
    with patch.object(photos,'get_supabase_admin',return_value=db), patch('app.services.item_photos._storage_path',return_value='owned'), patch('app.services.item_photos._get_item',return_value=db.item):
        with pytest.raises(HTTPException) as error: photos._link(ACTOR,inv,card(),choice())
    assert error.value.status_code==409 and db.inserts==0

def test_cross_author_conversation_rejected_before_read():
    with patch.object(world,'conversation',side_effect=HTTPException(404,'Not yours')), patch.object(photos,'get_supabase_raw') as raw:
        with pytest.raises(HTTPException):photos.load(ACTOR,WORLD,CID,str(uuid4()))
    raw.assert_not_called()

def test_new_capability_is_opt_in_at_route(transport):
    with patch.object(world,'stream_turn',return_value=events()) as model:
        transport.client.post(f'/worlds/{WORLD}/ai_command',json={'message':'Attach photo','supports_photo_attachment':True})
    assert model.call_args.kwargs['supports_photo_attachment'] is True

from types import SimpleNamespace as NS
from unittest.mock import patch
from uuid import uuid4
import json
import pytest
from app.services import saved_photo_search as gallery, world_item_photos as photos, ai_agent as agent
from app.services.inventory_scope import InventoryScope, current_inventory
from app.services.item_photos import ORIGINAL_SCAN_PHOTO

OWNER, ITEM, INVENTORY = [str(uuid4()) for _ in range(3)]
URL=f'https://placeholder.supabase.co//storage/v1/object/public/item-images/{OWNER}/later.jpg'

class Query:
    def __init__(self, rows): self.rows=rows;self.ids=[]
    def select(self,*a):return self
    def in_(self,key,ids):self.ids=ids;return self
    def eq(self,*a):return self
    def order(self,*a):return self
    def range(self,*a):return self
    def execute(self):return NS(data=[r for r in self.rows if r['item_id'] in self.ids])

@pytest.mark.parametrize('created_at', ['2026-10-01T00:00:00+00:00', '2026-10-01T00:00:00'])
@pytest.mark.parametrize('event_kind, expected', [('attachment',True),('unknown',None),('original',None)])
def test_catalog_reports_later_photo_without_inventing_legacy_attachment_dates(event_kind,expected,created_at):
    item={'item_id':ITEM,'image_url':URL,'created_at':created_at}
    event={'item_id':ITEM,'image_url':URL,'created_at':'2026-10-28T00:00:00+00:00','content':ORIGINAL_SCAN_PHOTO if event_kind=='original' else None}
    client=NS(table=lambda name:Query([item] if name=='items' else ([] if event_kind=='unknown' else [event])))
    with patch.object(gallery,'get_supabase_admin',return_value=client):
        result=gallery.photo_catalog([{'item_id':ITEM,'name':'Imported fastener'}])
    photo=result[0]['photos'][0]
    assert photo['path']==f'{OWNER}/later.jpg'
    assert photo['added_after_item_creation'] is expected
    assert (photo['added_at'] is not None)==(event_kind=='attachment')


def test_status_counts_actual_gallery_without_downloading_and_paginates_missing_items():
    catalog=[{'item_id':str(uuid4()),'item_created_at':None,'photos':[]} for _ in range(102)]
    catalog[0]['photos']=[{'path':None,'added_at':None,'added_after_item_creation':None}]
    with patch.object(agent,'_current_items',return_value=catalog),patch.object(gallery,'photo_catalog',return_value=catalog),patch.object(photos,'get_supabase_raw') as storage:
        result=photos.read_current(OWNER,OWNER,INVENTORY,include_images=False)
        page2=photos.read_current(OWNER,OWNER,INVENTORY,include_images=False,offset=100)
    assert result['items_with_photos']==1 and result['items_without_photos']==101
    assert result['photos_available']==1 and result['photos_read']==0
    assert len(result['items'])==25 and result['next_offset']==25 and not result['complete']
    assert len(page2['items'])==2 and page2['next_offset'] is None
    assert 'path' not in result['items'][0]['photos'][0]
    storage.assert_not_called()


def test_inventory_photo_tool_uses_bound_actor_and_inventory_not_supplied_destination():
    actor=str(uuid4());token=current_inventory.set(InventoryScope(INVENTORY,actor,OWNER,None,'viewer'))
    try:
        with patch.object(photos,'read_current',return_value={}) as read:
            photos.read_scoped(OWNER,include_images=False)
        read.assert_called_once_with(actor,OWNER,INVENTORY,include_images=False)
    finally:current_inventory.reset(token)
    schema=next(t['function']['parameters'] for t in agent._TOOLS if t['function']['name']=='inventory_item_photos')
    assert 'inventory_id' not in schema['properties'] and schema['additionalProperties'] is False


def test_inventory_photo_pixels_reach_model_but_never_returned_trace():
    call=NS(id='photo',function=NS(name='inventory_item_photos',arguments='{}'))
    responses=iter([iter([{'type':'done','content':'','tool_calls':[call]}]),iter([{'type':'done','content':'The photo shows a red container.','tool_calls':[]}])])
    parts=[{'type':'image_url','image_url':{'url':'data:image/jpeg;base64,PRIVATE_PIXELS'}}]
    messages=[]
    with patch.object(agent,'completion_events',side_effect=lambda response:response),patch.object(agent,'_guarded_tool_call',return_value={'photos_read':1,'_image_parts':parts}):
        events=list(agent.iter_model_turn(user_id=OWNER,message='Describe the photo',messages=messages,model_call=lambda *a:next(responses),allowed_tools={'inventory_item_photos'}))
    assert 'PRIVATE_PIXELS' in str(messages)
    assert 'PRIVATE_PIXELS' not in str(events)
    provider=NS(model='text',conversation_id='test',timezone='UTC')
    kwargs=agent._completion_kwargs(provider,messages=messages,stream=True,allow_tools=True)
    assert kwargs['model']==agent.get_settings().findez_chat_vision_model
    assert kwargs['max_tokens']==8192

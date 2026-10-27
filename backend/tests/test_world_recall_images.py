from contextlib import contextmanager
from io import BytesIO
from types import SimpleNamespace as NS
from unittest.mock import patch
from uuid import uuid4
import asyncio
import json
import pytest
from fastapi import HTTPException
from PIL import Image
from app.services import world_recall as recall, world_item_photos as photos, world_chat as world
from app.services.extraction_stream import stream_extraction

ACTOR, ORG, OTHER, ITEM, INVENTORY = [str(uuid4()) for _ in range(5)]

class Query:
    def __init__(self, rows): self.rows, self.filters = rows, {}
    def select(self, value):
        assert 'conversations!inner' in value
        return self
    def eq(self, key, value): self.filters[key] = value; return self
    def ilike(self, key, value): self.pattern = value; return self
    def order(self, *a, **kw): return self
    def range(self, a, b): self.bounds = (a,b); return self
    def execute(self):
        return NS(data=[r for r in self.rows if all(r[k] == v for k,v in self.filters.items())])


def test_recall_filters_author_and_world_in_database_without_receipts():
    rows = [{'conversations.user_id': a, 'conversations.world_key': o, 'role': 'user',
        'conversation_id': str(uuid4()), 'content': text, 'answer_context': {'pending_actions':['NEVER']}}
        for a,o,text in [(ACTOR,ORG,'coffee corner'),(OTHER,ORG,'private'),(ACTOR,OTHER,'other org'),(ACTOR,'personal','personal')]]
    query=Query(rows)
    with patch.object(world,'authorize',side_effect=lambda a,w:w), patch.object(recall,'get_supabase_raw',return_value=NS(table=lambda _:query)):
        result=recall.recall(ACTOR,ORG,'coffee')
    assert [r['statement'] for r in result['messages']] == ['coffee corner']
    assert 'NEVER' not in str(result)
    assert query.bounds == (0,20)


def test_recall_revoked_org_never_reads_history():
    with patch.object(world,'authorize',side_effect=HTTPException(403)), patch.object(recall,'get_supabase_raw') as db:
        with pytest.raises(HTTPException): recall.recall(ACTOR,ORG)
    db.assert_not_called()

@contextmanager
def scope(*args): yield {'owner_user_id':ACTOR}


def pixels():
    out=BytesIO(); Image.new('RGB',(20,20),'red').save(out,'PNG'); return out.getvalue()

@pytest.mark.parametrize('removed,allowed,expected', [(False,True,1),(True,True,0),(False,False,0)])
def test_current_later_added_gallery_pixels_and_removal(removed,allowed,expected):
    from app.services import ai_agent
    item={'item_id':ITEM,'name':'Container','quantity':12}
    refs=[(ITEM,'later-added.jpg')]
    storage=NS(download=lambda _:pixels())
    raw=NS(storage=NS(from_=lambda _:storage))
    with patch.object(world,'in_inventory',scope), patch.object(world,'inventory_scope'), patch.object(ai_agent,'_current_items',return_value=[item]), \
         patch.object(photos.gallery,'references',side_effect=[refs,[] if removed else refs]), patch.object(photos.gallery,'_authorized',return_value=allowed), patch.object(photos,'get_supabase_raw',return_value=raw):
        result=photos.read(ACTOR,ORG,INVENTORY)
    assert result['photos_read'] == expected
    assert len(result['_image_parts']) == expected*2
    if expected:
        assert result['_image_parts'][1]['image_url']['url'].startswith('data:image/jpeg;base64,')
        assert result['photos'][0]['quantity']==12
    else: assert result['unavailable']==1 and not result['complete']


def test_image_tool_rejects_foreign_inventory_before_loading_pixels():
    with patch.object(world,'in_inventory',side_effect=HTTPException(403)),patch.object(photos,'get_supabase_raw') as db:
        with pytest.raises(HTTPException): photos.read(ACTOR,ORG,INVENTORY)
    db.assert_not_called()


def test_stream_reports_actual_stages_and_one_result():
    async def extract(report):
        report('Reading details for 3 objects...')
        await asyncio.sleep(0)
        report('Checked 3 of 3 objects...')
        return NS(model_dump=lambda:{'items':[],'summary':{}})
    async def run(): return [v async for v in stream_extraction(extract)]
    events=[json.loads(v[6:]) for v in asyncio.run(run()) if v.startswith('data:')]
    assert [e['message'] for e in events[:-1]] == ['Preparing your photo...','Reading details for 3 objects...','Checked 3 of 3 objects...']
    assert events[-1]['type']=='done'


def test_stream_failure_never_exposes_raw_exception_or_done():
    async def extract(report): raise ValueError('secret provider payload')
    async def run(): return ''.join([v async for v in stream_extraction(extract)])
    result=asyncio.run(run())
    assert 'secret provider' not in result and '"error"' in result and '"done"' not in result


def test_photo_pixels_reach_glm_but_never_saved_diagnostics():
    call = NS(id='photo-call',function=NS(name='world_item_photos',arguments=json.dumps({'inventory_id':INVENTORY})))
    parts=[{'type':'image_url','image_url':{'url':'data:image/jpeg;base64,PRIVATE_PIXELS'}}]
    completions=[iter([{'type':'done','content':'','tool_calls':[call]}]),iter([{'type':'done','content':'The photo shows a container; hidden contents cannot be counted.','tool_calls':[]}])]
    with patch.object(world,'directory',return_value={}), patch.object(world,'execute',return_value={'photos':[], '_image_parts':parts}), \
         patch('app.services.agent_gateway_client.gateway_completion') as gateway, \
         patch('app.services.completion_stream.completion_events',side_effect=completions):
        result=list(world.stream_turn(ACTOR,ORG,'Inspect saved photos',[],str(uuid4())))[-1]
    assert 'PRIVATE_PIXELS' in str(gateway.call_args.kwargs['messages'])
    assert 'PRIVATE_PIXELS' not in str(result)
    assert result['answer_context']['operation_diagnostics'][0]['read_only'] is True

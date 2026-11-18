import json
from copy import deepcopy
from unittest.mock import patch
from app.services.world_inventory_preview import inventory_preview
from app.services.world_chat import model_data, resource_links, stream_turn
from app.services.agent_gateway_client import _as_namespace as ns

ACTOR='10000000-0000-0000-0000-000000000001'
ORG='20000000-0000-0000-0000-000000000001'
INV='30000000-0000-0000-0000-000000000001'


def records(count=15):
    return [{'item_id':f'40000000-0000-0000-0000-{i:012d}', 'inventory_id':INV,
             'name':f'PN-F{i}', 'quantity':None if i==0 else i, 'location':'Fasteners',
             'unit_price':0,'currency':'USD','expires_on':None,
             'image_url':'https://private.invalid/photo', 'scan_evidence':{'raw':'x'*10000},
             'import_data':{'source':'catalog.xlsx','fields':[
                 {'name':'Description','value':f'Gear M0.8 {i+10}T 6mm D-bore'},
                 {'name':'Length','value':0}, {'name':'Finish','value':'zinc'}]}}
            for i in range(count)]


def test_imported_descriptions_and_all_row_facts_survive_shared_boundary():
    rows=records(); result={'items':rows,'record_count':15,'known_units':105,
        'unknown_quantity_records':1,'complete':True,'rows_truncated':False,
        'resource_links':resource_links({'items':rows})}
    before=deepcopy(result)
    # Regression: nested imported values previously reached depth 6 and vanished.
    assert '[data omitted]' in json.dumps(model_data(result))
    packed=model_data(inventory_preview(result))
    assert result==before
    assert len(packed['items'])==15
    assert packed['known_units']==105 and packed['unknown_quantity_records']==1
    for i,row in enumerate(packed['items']):
        assert row['name']==f'PN-F{i}'
        assert row['description']==f'Gear M0.8 {i+10}T 6mm D-bore'
        assert row['quantity']==(None if i==0 else i)
        assert row['location']=='Fasteners' and row['inventory_id']==INV
        assert row['href'].startswith('findez://item/')
    assert packed['item_details'][0]['imported_fields'][1]['value']==0
    assert packed['item_details'][0]['unit_price']==0 and packed['item_details'][0]['currency']=='USD'
    assert packed['item_details'][0]['expires_on'] is None
    assert 'private.invalid' not in json.dumps(packed) and 'scan_evidence' not in json.dumps(packed)


def test_preview_cap_is_distinct_from_complete_query_totals():
    result={'items':records(25),'record_count':25,'known_units':300,'complete':True,'rows_truncated':False}
    packed=model_data(inventory_preview(result))
    assert packed['preview_truncated'] is True
    assert packed['record_count']==25 and packed['complete'] is True
    assert len(packed['items'])==20
    assert packed['items'][-1]['description']=='Gear M0.8 29T 6mm D-bore'


def test_empty_and_failed_results_do_not_become_complete_inventory_claims():
    assert inventory_preview({'error':'unavailable'})=={'error':'unavailable'}
    result=inventory_preview({'items':[],'complete':False})
    assert result['complete'] is False and result['items']==[]


def test_tool_allowance_ends_with_explicit_grounded_answer_instruction():
    calls=[]
    def gateway(**kw):
        calls.append(kw)
        if kw['tools']:
            return iter([ns({'choices':[{'message':{'content':'','tool_calls':[
                {'id':f'call{len(calls)}','function':{'name':'world_search','arguments':json.dumps({'query':f'gear{len(calls)}'})}}]},'finish_reason':'tool_calls'}]})])
        assert 'No tools are available' in kw['messages'][-1]['content']
        return iter([ns({'choices':[{'message':{'content':'**Inventory checked**\n\nNo matching records were returned; the search coverage is incomplete.'},'finish_reason':'stop'}]})])
    with patch('app.services.world_chat.authorize',return_value=ORG),patch('app.services.world_chat.execute',return_value={'items':[],'complete':False}) as execute,patch('app.services.agent_gateway_client.gateway_completion',gateway):
        events=list(stream_turn(ACTOR,ORG,'Find gears',[],'fixture'))
    assert execute.call_count==8 and len(calls)==9
    assert events[-1]['type']=='done'


def test_query_schema_explains_and_semantics_to_model():
    from app.services.world_chat import TOOLS
    schema=next(t['function']['parameters'] for t in TOOLS if t['function']['name']=='world_query')
    assert 'AND' in schema['properties']['terms']['description']

from unittest.mock import Mock, patch
from types import SimpleNamespace as NS
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.services import world_chat as w, world_item_changes as m
from app.services.inventory_scope import current_inventory

ACTOR, WORLD, INV, ITEM, TARGET, SPACE = [str(uuid4()) for _ in range(6)]
def inv(edit=True):
    return {'inventory_id':INV,'name':'Hardware','owner_user_id':ACTOR,'role':'editor' if edit else 'viewer',
            'can_edit':edit,'workspace':{'name':'Workshop','organization_id':WORLD}}
def snapshot():
    return {'snapshot':'frozen','item':{'item_id':ITEM,'inventory_id':INV,'name':'Bolt','quantity':3,'location':'Shelf',
      'unit_price':None,'currency':None,'reorder_enabled':False,'reorder_threshold':None,'reorder_quantity':None}}

@pytest.mark.parametrize('changes',[{}, {'quantity':True}, {'quantity':-1}, {'quantity':None}, {'unit_price':float('nan')},
 {'unit_price':-2}, {'unit_price':1.23456}, {'currency':'usd'}, {'expires_on':'2026-02-30'}, {'expires_on':'20261020'}, {'name':' '},
 {'reorder_enabled':None}, {'reorder_quantity':0}, {'user_id':ACTOR}])
def test_invalid_edits_fail_before_any_read(changes):
    with patch.object(w,'authorize'), patch.object(m,'get_supabase_raw') as db:
        with pytest.raises(ValueError): w.execute(ACTOR,WORLD,'world_edit_item',{'inventory_id':INV,'item_id':ITEM,'changes':changes})
    db.assert_not_called()

@pytest.mark.parametrize('changes',[{'unit_price':2}, {'reorder_enabled':True}, {'reorder_enabled':True,'reorder_threshold':2}])
def test_price_and_rule_require_complete_details(changes):
    db=Mock(); db.rpc.return_value.execute.return_value=NS(data=snapshot())
    with patch.object(w,'authorize'), patch.object(w,'_inventory',return_value=inv()), patch.object(m,'get_supabase_raw',return_value=db):
        with pytest.raises(ValueError): w.execute(ACTOR,WORLD,'world_edit_item',{'inventory_id':INV,'item_id':ITEM,'changes':changes})
    db.table.assert_not_called()

def test_edit_proposal_has_exact_changes_and_no_writes():
    db=Mock(); db.rpc.return_value.execute.return_value=NS(data=snapshot())
    changes={'unit_price':2.5,'currency':'USD','expires_on':'2027-01-01','reorder_enabled':True,'reorder_threshold':2,'reorder_quantity':10}
    with patch.object(w,'authorize'), patch.object(w,'_inventory',return_value=inv()), patch.object(m,'get_supabase_raw',return_value=db):
        result=w.execute(ACTOR,WORLD,'world_edit_item',{'inventory_id':INV,'item_id':ITEM,'changes':changes})
    action=result['pending_action']; entry=action['items'][0]
    assert action['version']==2 and action['operation']=='edit' and action['status']=='pending'
    assert entry['changes']==changes and entry['snapshot']=='frozen'
    assert 'Unit price: Not set → 2.5' in entry['details']
    assert result['inventory_changed'] is False and current_inventory.get() is None
    db.table.assert_not_called()
    assert db.rpc.call_args.args[0]=='findez_world_item_snapshot'

@pytest.mark.parametrize('name,args',[
 ('world_edit_item',{'item_id':ITEM,'changes':{'name':'New'}}),
 ('world_move_item',{'item_id':ITEM,'target_inventory_id':TARGET,'target_space_id':SPACE}),
 ('world_reorder_decision',{'request_id':ITEM,'status':'approved'})])
def test_viewer_cannot_propose_changes(name,args):
    with patch.object(w,'authorize'), patch.object(w,'_inventory',return_value=inv(False)), patch.object(m,'get_supabase_raw') as db:
        with pytest.raises(HTTPException) as error:w.execute(ACTOR,WORLD,name,{'inventory_id':INV,**args})
    assert error.value.status_code==403
    db.return_value.table.assert_not_called();db.return_value.rpc.assert_not_called()

def test_move_checks_destination_editor_and_never_writes():
    db=Mock();db.rpc.return_value.execute.return_value=NS(data=snapshot())
    destination=inv(False);destination['inventory_id']=TARGET
    with patch.object(w,'authorize'), patch.object(w,'_inventory',side_effect=[inv(),destination]), patch.object(m,'get_supabase_raw',return_value=db):
        with pytest.raises(HTTPException) as error:w.execute(ACTOR,WORLD,'world_move_item',{'inventory_id':INV,'item_id':ITEM,'target_inventory_id':TARGET,'target_space_id':SPACE})
    assert error.value.status_code==403
    db.table.assert_not_called()

def test_unknown_or_failed_receipt_cannot_claim_success():
    db=Mock();db.rpc.return_value.execute.return_value=NS(data={'status':'confirmed'})
    with patch.object(m,'get_supabase_raw',return_value=db):
        with pytest.raises(HTTPException) as error:m.change_action(actor=ACTOR,world=WORLD,inventory=INV,action_id=ITEM,decision='confirm')
    assert error.value.status_code==502

def test_tool_schemas_are_self_contained():
    import json
    schemas=[t for t in w.TOOLS if t['function']['name'].startswith(('world_edit','world_move','world_reorder','world_tracking'))]
    assert len(schemas)==5 and '$ref' not in json.dumps(schemas)


def test_move_invalidates_both_inventory_owners_after_verified_receipt():
    db=Mock(); db.rpc.return_value.execute.return_value=NS(data={'id':ITEM,'inventory_id':INV,
      'operation':'move','status':'confirmed','receipt':{'operation':'move','count':1,'items':[{'inventory_id':TARGET}]}})
    with patch.object(m,'get_supabase_raw',return_value=db), patch.object(w,'inventory_scope',side_effect=lambda a,w,i:{'owner_user_id':i}), patch('app.services.items_repo.invalidate_inventory_cache') as invalidate:
        result=m.change_action(actor=ACTOR,world=WORLD,inventory=INV,action_id=ITEM,decision='confirm')
    assert result['status']=='confirmed'
    assert {c.args[0] for c in invalidate.call_args_list}=={INV,TARGET}

from datetime import datetime, timedelta, timezone
from unittest.mock import Mock
from uuid import uuid4
import pytest
from pydantic import ValidationError
from fastapi import HTTPException
from app.services.cad import pricing, purchasing, revisions
from backend.tests.test_cad_workspace import Query, INV, ACTOR


def quote(**changes):
    now = datetime.now(timezone.utc)
    return pricing.Quote.model_validate(dict(vendor='Supplier', product_url='https://example.com/part',
        source_note='Quote supplied by purchasing lead', currency='USD', unit_price='0.18',
        quoted_at=now.isoformat(), valid_until=(now+timedelta(days=7)).isoformat(),
        exact_part_confirmed=True, **changes))


def test_pack_moq_and_bulk_break_can_reduce_total_without_rounding_money():
    value = pricing.estimate(quote(pack_size=10, minimum_quantity=25,
        tiers=[{'minimum_quantity': 50, 'unit_price': '0.08'}]), 24)
    assert value['order_quantity'] == 50 and value['surplus_quantity'] == 26
    assert value['subtotal'] == '4.00'
    assert value['excludes'] == ['shipping', 'tax']


def test_pack_rounding_applies_tier_at_actual_order_quantity():
    value = pricing.estimate(quote(pack_size=12, tiers=[{'minimum_quantity': 30, 'unit_price': '0.15'}]), 25)
    assert value['order_quantity'] == 36 and value['subtotal'] == '5.40'


def test_expiry_and_out_of_stock_are_not_purchase_options():
    q = quote(availability='out_of_stock')
    assert not pricing.estimate(q, 1)['purchasable']
    assert pricing.estimate(quote(), 1, datetime.now(timezone.utc)+timedelta(days=8))['expired']


@pytest.mark.parametrize('field,value', [('currency','usd'),('pack_size',0),('pack_size',True),
    ('unit_price','NaN'),('unit_price','-0.1'),('product_url','javascript:alert(1)'),
    ('product_url','https://secret:password@example.com'),('exact_part_confirmed',False),
    ('exact_part_confirmed','true'),('vendor','   ')])
def test_bad_quotes_rejected(field, value):
    data=quote().model_dump(mode='json'); data[field]=value
    with pytest.raises(ValidationError): pricing.Quote.model_validate(data)


def test_no_extra_fields_in_receiving_or_implicit_quantity_coercion():
    data=dict(request_id=str(uuid4()),expected_revision=1,action='receive',line_id=str(uuid4()),
        item_id=str(uuid4()),quantity=2,identity_confirmed=True)
    assert purchasing.Action.model_validate(data).quantity==2
    with pytest.raises(ValidationError): purchasing.Action.model_validate({**data,'quote_id':str(uuid4())})
    with pytest.raises(ValidationError): purchasing.Action.model_validate({**data,'quantity':'2'})


def test_feature_gate_prevents_database_access(monkeypatch):
    monkeypatch.delenv('CAD_PURCHASING_ENABLED', raising=False)
    db=Mock();monkeypatch.setattr(purchasing,'get_supabase_raw',db)
    with pytest.raises(HTTPException) as e: purchasing.plans(INV,ACTOR)
    assert e.value.status_code==503;db.assert_not_called()


def test_scoped_read_is_rechecked_and_totals_never_mix_currencies(monkeypatch):
    monkeypatch.setenv('CAD_PURCHASING_ENABLED','true')
    auth=Mock();monkeypatch.setattr(purchasing,'authorize_inventory',auth)
    lines=[{'id':str(i),'selected_quote':{'vendor':'Supplier','currency':currency,'estimate':{'subtotal':'1.20'}}}
        for i,currency in enumerate(['USD','USD','EUR'])]
    db=Query([{'id':'plan','inventory_id':INV,'lines':lines}]);monkeypatch.setattr(purchasing,'get_supabase_raw',lambda:db)
    result=purchasing.detail(INV,ACTOR,'plan')
    assert result['totals']=={'USD':'2.40','EUR':'1.20'}
    assert ('eq',('inventory_id',INV),{}) in db.calls
    assert auth.call_count==2


def test_replayed_creation_does_not_recalculate_stock(monkeypatch):
    monkeypatch.setenv('CAD_PURCHASING_ENABLED','true')
    monkeypatch.setattr(purchasing,'authorize_inventory',Mock())
    db=Query([{'id':'event'}]);monkeypatch.setattr(purchasing,'get_supabase_raw',lambda:db)
    rpc=Mock(return_value={'id':'existing'});monkeypatch.setattr(purchasing,'_rpc',rpc)
    evaluate=Mock();monkeypatch.setattr(purchasing.projects,'evaluate',evaluate)
    body=purchasing.CreatePlan(request_id=uuid4(),bom_version_id=uuid4())
    assert purchasing.create(INV,ACTOR,body)=={'id':'existing'}
    evaluate.assert_not_called()
    assert rpc.call_args.args[-1]==['create',str(body.bom_version_id)]


def test_revision_diff_counts_requirements_not_shared_stock():
    def row(key, name, qty, part='M4', **kwargs):
        return dict(key=key,name=name,required=qty,part_number=part,manufacturer='Maker',
            procurement_policy='purchase',status='short',**kwargs)
    a={'items':[row('a','Screw',4),row('b','Bearing',2,'608')]}
    b={'items':[row('c','Renamed screw',6),row('d','Washer',1,'W4')]}
    result=revisions.changes(a,b)
    assert sorted((r['change'],r['delta']) for r in result)==[('added',1),('quantity',2),('removed',-2)]
    assert not any(r['needs_review'] for r in result)


def test_revision_diff_does_not_merge_unidentified_same_names():
    def row(key, qty):return dict(key=key,name='Bracket',manufacturer='',part_number='',
        procurement_policy='fabricate',status='needs_review',required=qty)
    result=revisions.changes({'items':[row('a',1)]},{'items':[row('b',1)]})
    assert len(result)==2 and all(r['needs_review'] for r in result)


def test_cross_project_revision_diff_rejected(monkeypatch):
    monkeypatch.setattr(revisions.projects,'version',Mock(side_effect=[{'project_id':'one'},{'project_id':'two'}]))
    with pytest.raises(HTTPException) as error: revisions.compare(INV,ACTOR,'a','b')
    assert error.value.status_code==422

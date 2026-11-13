"""Synthetic provider contracts, security boundaries and deterministic comparisons."""
from copy import deepcopy
from types import SimpleNamespace as NS
from uuid import uuid4
import asyncio
import json

import httpx
import pytest
from cryptography.fernet import Fernet
from fastapi import HTTPException, FastAPI
from fastapi.testclient import TestClient

from app.services.cad import onshape, corrections, connections, security, tabular
from app.services.cad.comparison import compare
from app.api.routes import cad_onshape
from app.core.auth import AuthenticatedUser, get_current_user

ASSEMBLY = onshape.Assembly(document_id='a'*24, element_id='b'*24, wvm_id='c'*24, configuration='Size=small;Color=Black')


def bom():
    return {'name': 'Synthetic drivetrain', 'headers': [
        {'id': 'n', 'propertyName': 'Name'}, {'id': 'q', 'propertyName': 'Quantity'},
        {'id': 'p', 'propertyName': 'Part number'}, {'id': 'd', 'propertyName': 'Description'}],
        'rows': [{'rowId': '1', 'indentLevel': 0, 'headerIdToValue': {'n': 'M3 screw', 'q': 8, 'p': 'M3-12', 'd': 'Ignored'},
                  'itemSource': {'documentId': 'a'*24, 'elementId': 'b'*24, 'partId': 'JHD'}}],
        'topLevelAssemblyRow': {'headerIdToValue': {'n': 'Robot', 'q': 1}}}


def stock(**kwargs):
    return {'item_id': 'item1', 'name': 'M3 screw', 'part_number': 'M3-12', 'brand': '', 'quantity': 10, **kwargs}


def test_flat_bom_counts_totals_once_and_ignores_description_material():
    snapshot = onshape.normalize(bom(), ASSEMBLY, 'd'*24)
    result = compare(snapshot, [stock()], [], [])
    assert result['summary']['required_units'] == 8
    assert result['items'][0]['status'] == 'covered'
    assert result['source_verification'] == 'onshape_api'
    assert result['revision']['id'] == 'd'*24


@pytest.mark.parametrize('quantity', [0, -1, 1.1, True, '1e3', '2 m', 1000000001, {'unknown': 2}])
def test_bad_quantities_fail_closed(quantity):
    data = bom(); data['rows'][0]['headerIdToValue']['q'] = quantity
    with pytest.raises(ValueError): onshape.normalize(data, ASSEMBLY, 'd'*24)


def test_structured_duplicate_and_ambiguous_boms_rejected():
    for mutation in ('nested', 'duplicate', 'headers', 'missing'):
        data = bom()
        if mutation == 'nested': data['rows'][0]['indentLevel'] = 2
        if mutation == 'duplicate': data['rows'] *= 2
        if mutation == 'headers': data['headers'].append({'id': 'q2','propertyName':'Quantity'})
        if mutation == 'missing': data['headers'] = []
        with pytest.raises(ValueError): onshape.normalize(data, ASSEMBLY, 'd'*24)


def test_csv_onshape_headers_prefer_name_and_keep_identifiers():
    raw = b'Item,Name,Description,Part number,Quantity,Material\n1,M3 screw,Not an identity,M3-12,8,Steel\n2,Washer,,00012,4,\n'
    preview = tabular.preview(raw, 'onshape.csv')['sheets'][0]
    assert preview['suggested_mapping'] == {'name': 1, 'quantity': 4, 'part_number': 3}
    snapshot = tabular.snapshot(raw, 'onshape.csv', preview['name'], preview['suggested_mapping'], True)
    result = compare(snapshot, [stock()], [], [])
    assert result['summary']['required_units'] == 12
    assert result['items'][1]['part_number'] == '00012'
    assert result['items'][0]['status'] == 'covered'


def test_name_only_review_and_supplier_collision():
    data = bom(); data['rows'][0]['headerIdToValue']['p'] = ''
    result = compare(onshape.normalize(data, ASSEMBLY, 'd'*24), [stock()], [], [])
    assert result['items'][0]['status'] == 'needs_review'
    result = compare(onshape.normalize(bom(), ASSEMBLY, 'd'*24), [stock(brand='A'), stock(item_id='item2', brand='B')], [], [])
    assert result['items'][0]['status'] == 'needs_review'


def test_saved_corrections_share_stock_and_invalidate_changed_items():
    snapshot = onshape.normalize(bom(), ASSEMBLY, 'd'*24)
    line = snapshot.lines[0]
    snapshot.lines.append(line.model_copy(update={'key': 'second'}))
    item = stock(name='Another name', part_number='Other')
    saved = {corrections.identity(line.model_dump()): {'decision':'match','item_id':'item1','item_fingerprint':corrections.item_identity(item)}}
    result = compare(snapshot, [item], [], [], saved)
    assert [r['assigned'] for r in result['items']] == [8, 2]
    assert result['items'][1]['status'] == 'short'
    changed = compare(snapshot, [{**item, 'part_number': 'Changed'}], [], [], saved)
    assert all(r['status'] == 'needs_review' and r['assigned'] == 0 for r in changed['items'])
    # Quantity and location changes do not invalidate identity decisions.
    assert corrections.item_identity(item) == corrections.item_identity({**item,'quantity':2,'location':'Other bin'})


def test_no_match_overrides_exact_match():
    snapshot = onshape.normalize(bom(), ASSEMBLY, 'd'*24)
    saved = {corrections.identity(snapshot.lines[0].model_dump()): {'decision': 'no_match'}}
    assert compare(snapshot, [stock()], [], [], saved)['items'][0]['status'] == 'missing'


def test_review_receipts_actor_inventory_purpose_and_tamper(monkeypatch):
    monkeypatch.setenv('CAD_SECRET_KEY', Fernet.generate_key().decode())
    token = security.seal('cad_review', {'actor':'a','inventory':'inv','identity':'f'*64})
    for actor, inv, value in [('b','inv',token), ('a','other',token), ('a','inv',token+'broken')]:
        with pytest.raises(HTTPException): corrections.save(inv,actor,value,'no_match',None)
    with pytest.raises(HTTPException): security.unseal('onshape',token)


def test_provider_requests_pin_revision_and_never_fetch_geometry(monkeypatch):
    requests = []
    async def request(client, method, url, **kwargs):
        requests.append((method,url,kwargs))
        return {'id':'d'*24} if url.endswith('currentmicroversion') else bom()
    monkeypatch.setattr(onshape,'request_json',request)
    result = asyncio.run(onshape.extract(ASSEMBLY,'test-token'))
    assert len(requests) == 2
    assert all(r[0] == 'GET' for r in requests)
    assert '/m/'+'d'*24 in requests[1][1]
    assert requests[1][2]['params']['indented'] == 'false'
    assert requests[1][2]['params']['configuration'] == ASSEMBLY.configuration
    assert result.revision.id == 'd'*24


@pytest.mark.parametrize('status,expected', [(429,429),(401,403),(403,403),(404,404),(302,502),(500,502)])
def test_upstream_errors_do_not_leak_body_or_follow_redirects(status, expected):
    async def run():
        async with httpx.AsyncClient(transport=httpx.MockTransport(lambda r: httpx.Response(status, text='secret provider details',headers={'retry-after':'2'}))) as client:
            with pytest.raises(HTTPException) as error:
                await onshape.request_json(client,'GET',onshape.API+'/test')
            assert error.value.status_code == expected
            assert 'secret' not in error.value.detail
            if expected == 429: assert error.value.headers['Retry-After']=='2'
    asyncio.run(run())


def test_provider_response_limit():
    async def run():
        async with httpx.AsyncClient(transport=httpx.MockTransport(lambda r: httpx.Response(200,content=b'x'*(onshape.MAX_SNAPSHOT_BYTES+1)))) as client:
            with pytest.raises(HTTPException) as error: await onshape.request_json(client,'GET',onshape.API+'/test')
            assert error.value.status_code == 413
    asyncio.run(run())


def test_connection_unconfigured_is_truthful(monkeypatch):
    monkeypatch.delenv('ONSHAPE_CLIENT_ID',raising=False)
    assert connections.status('actor') == {'enabled':False,'connected':False}
    with pytest.raises(HTTPException) as error: connections.start('actor')
    assert error.value.status_code == 503


def test_onshape_route_checks_inventory_before_provider(monkeypatch):
    app = FastAPI(); app.include_router(cad_onshape.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='actor')
    def denied(*args): raise HTTPException(403,'Denied')
    monkeypatch.setattr(cad_onshape,'authorize_inventory',denied)
    with TestClient(app) as client:
        response = client.post(f'/inventories/{uuid4()}/cad/onshape/compare',json=ASSEMBLY.model_dump())
    assert response.status_code == 403


def test_document_ids_reject_url_injection():
    for field in ('document_id','element_id','wvm_id'):
        with pytest.raises(ValueError): onshape.Assembly(**{**ASSEMBLY.model_dump(),field:'../../evil.test'})

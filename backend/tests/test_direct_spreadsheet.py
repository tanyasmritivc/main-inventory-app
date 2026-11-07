import io
import json
from datetime import datetime
from unittest.mock import MagicMock, patch
import openpyxl
import pytest
from app.services.connector_tables import parse_source
from app.services.direct_spreadsheet import automatic_rows
from app.api.routes.connectors import import_direct
from app.core.auth import AuthenticatedUser
from app.services import storage

DEST = {'id': 'space-fixed', 'name': 'Garage'}
def rows(raw, filename='items.csv'):
    return automatic_rows(parse_source(raw, filename, direct=True), filename=filename, destination=DEST)

def test_every_row_column_and_repeated_item_is_preserved_in_fixed_space():
    result = rows(b'Product Name,Qty on hand,Barcode,Location,Extra,Extra,\nCable,2,000123,Other,a,b,tail\nCable,3,000123,Else,c,d,last\n')
    assert len(result) == 2
    assert [r['item']['quantity'] for r in result] == [2, 3]
    for r in result:
        assert r['item']['space_id'] == 'space-fixed'
        assert r['item']['location'] == 'Garage'
        assert r['item']['barcode'] == '000123'
        assert len(r['item']['import_data']['fields']) == 7
    assert result[0]['item']['import_data']['fields'][-1] == {'name':'', 'value':'tail'}

@pytest.mark.parametrize('qty', ['1.2', '-1', 'NaN', 'many', '100001'])
def test_invalid_quantity_never_defaults_or_truncates(qty):
    with pytest.raises(ValueError, match='Nothing was saved'):
        rows(f'Name,Qty\nGood,1\nBad,{qty}'.encode())

def test_ambiguous_quantities_and_json_duplicate_keys_are_rejected():
    with pytest.raises(ValueError, match='multiple quantity'):
        rows(b'Name,Qty,Qty\nCable,1,2')
    with pytest.raises(ValueError, match='repeated keys'):
        rows(b'[{"Name":"Cable","Qty":1,"Qty":2}]', 'items.json')

def test_json_keeps_nested_values_and_columns_that_appear_later():
    result = rows(json.dumps([{'Name':'A', 'Qty':2, 'Meta':{'size':3}}, {'Name':'B', 'Other':[1,2]}]).encode(), 'items.json')
    assert len(result) == 2
    assert result[0]['item']['import_data']['fields'][2]['value'] == {'size':3}
    assert result[1]['item']['import_data']['fields'][3]['value'] == [1,2]

def test_workbook_all_sheets_blank_header_rows_and_dates_are_serializable():
    wb = openpyxl.Workbook()
    wb.active.append([]); wb.active.append(['Name','Qty','Date'])
    wb.active.append(['Battery',2,datetime(2026,1,2)])
    wb.create_sheet('Tools').append(['Name','Qty']); wb['Tools'].append(['Drill',1])
    out = io.BytesIO(); wb.save(out)
    tables = parse_source(out.getvalue(), 'items.xlsx', direct=True)
    json.dumps(tables)
    result = automatic_rows(tables, filename='items.xlsx', destination=DEST)
    assert [r['item']['name'] for r in result] == ['Battery','Drill']
    assert result[0]['source_row'] == 3
    assert result[0]['item']['import_data']['fields'][2]['value'].startswith('2026-01-02')

def test_formula_without_cached_result_is_not_silently_lost():
    wb = openpyxl.Workbook(); wb.active.append(['Name','Qty']); wb.active.append(['Cable','=1+2'])
    out = io.BytesIO(); wb.save(out)
    with pytest.raises(ValueError): rows(out.getvalue(), 'items.xlsx')

def test_formula_cache_retains_original_formula_and_uses_result():
    tables = parse_source(b'Name,Qty\nCable,=1+2', 'items.csv')
    tables[0]['computed_rows'] = [['Cable',3]]
    item = automatic_rows(tables, filename='items.xlsx', destination=DEST)[0]['item']
    assert item['quantity'] == 3
    assert item['import_data']['fields'][1] == {'name':'Qty','value':'=1+2','computed_value':3}

def test_direct_import_uses_existing_durable_commit_and_never_skips_rows():
    session = {'id':'session', 'status':'complete', 'kind':'inventory', 'mapping':{'direct':True}, 'revision':1, 'review':[{'index':0},{'index':1}]}
    with patch('app.api.routes.connectors._session', return_value=session), patch('app.api.routes.connectors.commit_import') as commit:
        commit.__wrapped__ = MagicMock(return_value={'status':'complete'})
        assert import_direct.__wrapped__(request=None, session_id='session', user=AuthenticatedUser(user_id='actor')) == {'status':'complete'}
        payload = commit.__wrapped__.call_args.kwargs['payload']
        assert payload.decisions == {'0':'create_duplicate','1':'create_duplicate'}
        assert payload.retry_failed is True

@pytest.mark.parametrize('filename', ['Screenshot 2026-11-07 at 2.21.47\u202fPM.png', '../a%\\b.png', '照相.png', 'x'*300+'.png'])
def test_uploaded_screenshot_key_is_safe_ascii_and_bounded(filename, monkeypatch):
    client = MagicMock(); client.storage.from_.return_value.get_public_url.return_value = 'https://example.com/photo'
    monkeypatch.setattr(storage, 'get_supabase_admin', lambda:client)
    image = storage.upload_image(user_id='actor', filename=filename, content=b'image')
    import re
    assert re.fullmatch(r'actor/[A-Za-z0-9._-]+', image.path)
    assert len(image.path) <= 200
    assert client.storage.from_.return_value.upload.call_args.args[1] == b'image'

import io
import json
from uuid import uuid4
from zipfile import ZipFile, ZIP_DEFLATED

import openpyxl
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.services.cad import tabular
from app.services.cad.comparison import compare
from app.api.routes import cad
from app.core.auth import get_current_user, AuthenticatedUser

CSV = b'Component name,Required quantity,Manufacturer,Part number,Barcode,Unit\nScrew,8,Example,M3-12,00123,each\n'
MAP = {'name': 0, 'quantity': 1, 'manufacturer': 2, 'part_number': 3, 'barcode': 4, 'unit': 5}
STOCK = {'item_id': 'i', 'name': 'Screw', 'quantity': 6, 'brand': 'Example', 'part_number': 'M3-12', 'barcode': '00123'}


def workbook(rows=None, second=False):
    book = openpyxl.Workbook(); sheet = book.active; sheet.title = 'Parts'
    for row in rows or [['Component name', 'Required quantity', 'Manufacturer', 'Part number', 'Barcode', 'Unit'], ['Screw', 8, 'Example', 'M3-12', '00123', 'each']]: sheet.append(row)
    if second:
        sheet = book.create_sheet('Other'); sheet.append(['Name', 'Qty']); sheet.append(['Other part', 99])
    data = io.BytesIO(); book.save(data); book.close(); return data.getvalue()


def snap(raw=CSV, name='bom.csv', sheet='Sheet1', mapping=MAP):
    return tabular.snapshot(raw, name, sheet, mapping, True)


@pytest.mark.parametrize('extension', ['csv', 'xlsx'])
def test_flat_quantities_match_without_occurrence_expansion(extension):
    raw = CSV if extension == 'csv' else workbook(second=True)
    preview = tabular.preview(raw, 'bom.' + extension)
    assert preview['sheets'][0]['suggested_mapping'] == MAP
    result = compare(snap(raw, 'bom.'+extension, preview['sheets'][0]['name']), [STOCK], [], [])
    assert result['summary'] == {'required_units': 8, 'covered_units': 6, 'coverage_percent': 75, 'shortage_lines': 1, 'review_lines': 0}
    assert result['revision']['kind'] == 'tabular_import'
    assert result['completeness'] == 'partial' and result['warnings']


def test_duplicate_rows_share_stock_not_double_availability():
    result = compare(snap(CSV + b'Screw,8,Example,M3-12,00123,each\n'), [STOCK], [], [])
    assert result['summary']['required_units'] == 16
    assert result['summary']['covered_units'] == 6
    assert [r['assigned'] for r in result['items']] == [6, 0]


def test_reservations_and_checkouts_still_deducted():
    result = compare(snap(), [STOCK], [{'inventory_item_id': 'i', 'quantity': 2}], [{'item_id': 'i', 'quantity': 1}])
    assert result['summary']['covered_units'] == 3


@pytest.mark.parametrize('qty', ['0', '-1', '1.5', 'NaN', 'Infinity', '1_000', '1e3', '', '=4+4', '+8', '1000000001'])
def test_invalid_quantities_rejected_with_row_number(qty):
    raw = CSV.replace(b'Screw,8,', ('Screw,'+qty+',').encode())
    with pytest.raises(ValueError, match='Row 2'): snap(raw)


def test_names_alone_remain_reviewable():
    result = compare(snap(b'Name,Qty\nScrew,8\n', mapping={'name': 0, 'quantity': 1}), [STOCK], [], [])
    assert result['items'][0]['status'] == 'needs_review'
    assert result['summary']['covered_units'] == 0


@pytest.mark.parametrize('change', ['numeric_identifier', 'formula', 'unit', 'missing_name'])
def test_xlsx_rejects_lossy_or_unsupported_values(change):
    row = ['Screw', 8, 'Example', 'M3-12', '00123', 'each']
    if change == 'numeric_identifier': row[4] = 123
    if change == 'formula': row[1] = '=4+4'
    if change == 'unit': row[5] = 'kg'
    if change == 'missing_name': row[0] = None
    raw = workbook([['Name', 'Qty', 'Manufacturer', 'Part number', 'Barcode', 'Unit'], row])
    with pytest.raises(ValueError, match='Row 2'): snap(raw, 'bom.xlsx', 'Parts')


def test_rejects_unconfirmed_invalid_sheet_and_duplicate_mapping():
    with pytest.raises(ValueError, match='Confirm'): tabular.snapshot(CSV, 'bom.csv', 'Sheet1', MAP, False)
    with pytest.raises(ValueError, match='worksheet'): snap(sheet='Other')
    with pytest.raises(ValueError, match='different column'): snap(mapping={'name': 0, 'quantity': 0})
    with pytest.raises(ValueError, match='outside'): snap(mapping={'name': 0, 'quantity': 199})


def test_csv_bom_delimiters_quotes_and_unicode():
    raw = '\ufeffName;Qty;Barcode\n"Screw; metric";8;00123\n'.encode()
    preview = tabular.preview(raw, 'BOM.CSV')
    assert preview['sheets'][0]['sample'][0] == ['Screw; metric', '8', '00123']
    assert snap(raw, mapping={'name':0,'quantity':1,'barcode':2}).lines[0].barcode == '00123'


def test_duplicate_headers_need_explicit_mapping():
    data = tabular.preview(b'Name,Qty,Qty\nScrew,8,9\n', 'bom.csv')
    assert 'quantity' not in data['sheets'][0]['suggested_mapping']


@pytest.mark.parametrize('raw,name', [(b'', 'bom.csv'), (b'not a workbook', 'bom.xlsx'), (CSV,'bom.xls'), (b'\xff\x00','bom.csv')])
def test_bad_files_fail_cleanly(raw, name):
    with pytest.raises(ValueError): tabular.preview(raw, name)


def test_workbook_sparse_dimensions_and_xml_entities_rejected():
    book = openpyxl.Workbook(); book.active['XFD1048576'] = 'bad'; buf=io.BytesIO(); book.save(buf)
    with pytest.raises(ValueError): tabular.preview(buf.getvalue(), 'bad.xlsx')
    with ZipFile(io.BytesIO(workbook())) as source:
        for attack in ['entity', 'dimensions']:
            out=io.BytesIO()
            with ZipFile(out,'w',ZIP_DEFLATED) as target:
                for name in source.namelist():
                    raw=source.read(name)
                    if name=='xl/worksheets/sheet1.xml':
                        raw = b'<!DOCTYPE foo [<!ENTITY x "bad">]>' + raw if attack=='entity' else raw.replace(b'A1:F2',b'A1:A1')
                    target.writestr(name,raw)
            with pytest.raises(ValueError): tabular.preview(out.getvalue(),'bad.xlsx')


def test_large_quantity_does_not_expand_rows():
    result = compare(snap(CSV.replace(b'Screw,8,', b'Screw,1000000000,')), [STOCK], [], [])
    assert len(result['items']) == 1 and result['summary']['required_units'] == 1000000000


@pytest.fixture
def client(monkeypatch):
    app=FastAPI();app.include_router(cad.router)
    app.dependency_overrides[get_current_user]=lambda: AuthenticatedUser(user_id='actor')
    monkeypatch.setattr(cad,'authorize_inventory',lambda *a: None)
    monkeypatch.setattr(cad,'read_inventory',lambda *a: ([STOCK],[],[]))
    return TestClient(app)


@pytest.mark.parametrize('name,raw,sheet',[('bom.csv',CSV,'Sheet1'),('bom.xlsx',workbook(),'Parts')])
def test_http_preview_compare(client,name,raw,sheet):
    path=f'/inventories/{uuid4()}/cad/'
    preview=client.post(path+'preview',files={'file':(name,raw)})
    assert preview.status_code==200,preview.text
    result=client.post(path+'compare',files={'file':(name,raw)},data={'mapping':json.dumps(MAP),'sheet':sheet,'flat_bom_confirmed':'true'})
    assert result.status_code==200,result.text
    assert result.json()['summary']['covered_units']==6


def test_http_preview_auth_scope_revocation(client,monkeypatch):
    calls=[]
    def deny(*args):
        calls.append(args)
        if len(calls)==2:raise HTTPException(403,'Revoked')
    monkeypatch.setattr(cad,'authorize_inventory',deny)
    result=client.post(f'/inventories/{uuid4()}/cad/preview',files={'file':('bom.csv',CSV)})
    assert result.status_code==403 and len(calls)==2
    app=FastAPI();app.include_router(cad.router)
    assert TestClient(app).post(f'/inventories/{uuid4()}/cad/preview',files={'file':('bom.csv',CSV)}).status_code==401


def test_http_rejects_mapping_and_unconfirmed(client):
    for mapping in ('{}','null','not-json','{"name":0,"name":1}'):
        response=client.post(f'/inventories/{uuid4()}/cad/compare',files={'file':('bom.csv',CSV)},data={'mapping':mapping,'flat_bom_confirmed':'true','sheet':'Sheet1'})
        assert response.status_code==422
    response=client.post(f'/inventories/{uuid4()}/cad/compare',files={'file':('bom.csv',CSV)})
    assert response.status_code==422

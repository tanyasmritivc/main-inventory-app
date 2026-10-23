import io
import zipfile
import pytest
import openpyxl
from app.services.connector_tables import parse_source, review_table, match_bom, shortage_csv, safe_filename
from app.services.spreadsheet_import import MAX_IMPORT_BYTES


def review(raw, *, inventory=None, bom=False):
    t = parse_source(raw, 'items.csv')[0]
    return review_table(t, filename='items.csv', columns=t['suggested_mapping'],
                        defaults={'category': 'Supplies', 'location': 'Storage', 'quantity': 1},
                        inventory=inventory or [], locations=[{'id':'s', 'name':'Storage'}], bom=bom)


@pytest.mark.parametrize('quantity', ['-1','1.5','many','NaN','Infinity','','100001'])
def test_invalid_quantities_are_not_clamped_or_defaulted(quantity):
    row = review(f'Name,Quantity\nBattery,{quantity}\n'.encode())[0]
    assert any('Quantity' in error for error in row['errors'])


def test_missing_name_is_not_guessed_from_another_cell():
    row = review(b'Name,Quantity,Barcode\n,2,000123\n')[0]
    assert 'Name is required.' in row['errors']
    assert row['item']['barcode'] == '000123'


def test_duplicate_headers_keep_positions_and_need_mapping():
    table = parse_source(b'Name,Name,Qty\nA,B,2\n', 'items.csv')[0]
    assert table['warnings'] and 'name' not in table['suggested_mapping']
    rows = review_table(table, filename='items.csv', columns={'name':1, 'quantity':2},
                        defaults={'category':'Tools', 'location':'Storage'}, inventory=[], locations=[{'id':'s','name':'Storage'}])
    assert rows[0]['item']['name'] == 'B'
    assert rows[0]['item']['import_data']['fields'][:2] == [{'name':'Name','value':'A'},{'name':'Name','value':'B'}]


def test_duplicate_stock_and_in_file_are_reviewed_not_merged():
    rows = review(b'Name,Qty,Barcode\nCable,2,001\nCable,4,001\n', inventory=[{'item_id':'existing','name':'Cable','quantity':8,'barcode':'001'}])
    assert rows[0]['duplicates'][0]['item_id'] == 'existing'
    assert rows[1]['duplicate_rows'] == [0]
    assert rows[1]['item']['quantity'] == 4


def test_malformed_row_is_visible():
    rows = review(b'Name,Qty\nBattery,2,extra\n')
    assert any('number of cells' in e for e in rows[0]['errors'])


def test_unknown_location_is_not_silently_created():
    assert any('existing Space' in e for e in review(b'Name,Qty,Location\nBattery,2,Unknown\n')[0]['errors'])


def test_semicolon_csv_and_utf8_bom():
    assert review(b'\xef\xbb\xbfName;Qty\nBattery;2\n')[0]['item']['quantity'] == 2


@pytest.mark.parametrize('raw,name,mime', [(b'abc','a.xls',None), (b'PK\x00','a.csv',None), (b'Name\nA','a.csv','image/png'), (b'', 'a.csv',None), (b'x'*(MAX_IMPORT_BYTES+1),'a.csv',None), (b'Name,Qty\n"unfinished,2','a.csv',None)])
def test_invalid_files(raw,name,mime):
    with pytest.raises(ValueError): parse_source(raw,name,mime)


def test_row_limit_and_column_limit():
    with pytest.raises(ValueError): parse_source(b'Name\n'+b'A\n'*5001,'a.csv')
    with pytest.raises(ValueError): parse_source((','.join(['h']*201)+'\n'+','.join(['x']*201)).encode(),'a.csv')


def test_excel_multiple_sheets_and_formula_review():
    wb=openpyxl.Workbook(); wb.active.append(['Name','Qty']); wb.active.append(['Battery','=1+2'])
    wb.create_sheet('Other').append(['Name','Qty']); wb['Other'].append(['Cable',3])
    stream=io.BytesIO(); wb.save(stream)
    tables=parse_source(stream.getvalue(),'parts.xlsx')
    assert len(tables)==2
    rows=review_table(tables[0], filename='parts.xlsx', columns={'name':0,'quantity':1}, defaults={'category':'Tools','location':'Storage'}, inventory=[],locations=[{'id':'s','name':'Storage'}])
    assert any('Formula' in e for e in rows[0]['errors'])


def test_archive_expansion_limit():
    stream=io.BytesIO()
    with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED) as archive: archive.writestr('huge.xml', b'0'*(51*1024*1024))
    with pytest.raises(ValueError,match='expanded'): parse_source(stream.getvalue(),'parts.xlsx')


def test_bom_reservations_and_repeated_requirements_do_not_double_count():
    rows=review(b'Name,MPN,Qty\nMotor,M1,4\nMotor,M1,4\n',bom=True)
    inventory=[{'item_id':'m','name':'Motor','part_number':'M1','quantity':10}]
    result=match_bom(rows,inventory,[{'inventory_item_id':'m','quantity':4}])
    assert [r['available_quantity'] for r in result]==[6,2]
    assert [r['missing_quantity'] for r in result]==[0,2]


def test_bom_ambiguous_brands_and_fuzzy_matches_never_supply_stock():
    rows=review(b'Name,MPN,Qty\nMotor,M1,4\n',bom=True)
    inventory=[{'item_id':'a','name':'Motor','part_number':'M1','brand':'A','quantity':10}, {'item_id':'b','name':'Motor','part_number':'M1','brand':'B','quantity':20}]
    result=match_bom(rows,inventory,[])[0]
    assert result['match_status']=='review' and result['available_quantity']==0


def test_kicad_dnp_is_excluded_and_export_is_formula_safe():
    rows=review(b'Value,Qty,DNP\nMotor,2,yes\nCable,3,\n',bom=True)
    assert len(match_bom(rows,[],[]))==1
    result=match_bom(rows,[],[]); result[0]['name']='=HYPERLINK("bad")'
    assert "'=HYPERLINK" in shortage_csv(result)
    assert safe_filename('../../evil.csv')=='evil.csv'

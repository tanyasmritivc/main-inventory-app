"""Read actual chat file bytes, retaining structure and honest excerpt limits."""
from io import BytesIO
from zipfile import ZipFile, ZIP_DEFLATED
from unittest.mock import patch
import json
import pytest
from fastapi import HTTPException
from openpyxl import Workbook
from app.services import chat_sources as sources, chat_file_text as files
from backend.tests.test_world_chat_routes import transport, WORLD


def workbook():
    book = Workbook()
    sheet = book.active; sheet.title = 'Parts'
    sheet.append(['Part', 'Count', 'Serial', 'Notes'])
    sheet.append(['Bolt', 12, '00042', 'Shelf A'])
    sheet.append(['Nut', 3, None, '=SUM(B2:B3)'])
    book.create_sheet('Instructions').append(['Keep dry'])
    raw = BytesIO(); book.save(raw); book.close()
    return raw.getvalue()


def document(xml=None, extras=None):
    body = xml or f'''<w:document xmlns:w="{files.WORD[1:-1]}"><w:body>
    <w:p><w:r><w:t>Workshop</w:t></w:r><w:r><w:t> manual</w:t></w:r></w:p>
    <w:tbl><w:tr><w:tc><w:p><w:r><w:t>Voltage</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>5V</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
    <w:p><w:r><w:t>Disconnect first.</w:t></w:r></w:p></w:body></w:document>'''
    raw = BytesIO()
    with ZipFile(raw, 'w', ZIP_DEFLATED) as archive:
        archive.writestr('[Content_Types].xml', '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
        archive.writestr('word/document.xml', body)
        for name, value in (extras or {}).items():archive.writestr(name, value)
    return raw.getvalue()


def test_excel_retains_sheets_positions_leading_zeroes_and_formulas():
    result = sources.extract('parts.XLSX', workbook())
    text = result['text']
    assert 'Sheet: Parts' in text and 'Sheet: Instructions' in text
    assert 'Row 2: ["Bolt", 12, "00042", "Shelf A"]' in text
    assert '"Nut", 3, null, "=SUM(B2:B3)"' in text
    assert 'not recalculated' in text and not result['truncated']


def test_excel_single_cell_and_blank_workbooks():
    book = Workbook(); book.active['A1'] = 'Only one cell'
    raw = BytesIO(); book.save(raw)
    assert 'Only one cell' in sources.extract('single.xlsx', raw.getvalue())['text']
    book.active['A1'] = None; raw = BytesIO(); book.save(raw); book.close()
    with pytest.raises(HTTPException):sources.extract('empty.xlsx', raw.getvalue())


def test_word_retains_paragraph_table_order_and_headers():
    header = f'<w:hdr xmlns:w="{files.WORD[1:-1]}"><w:p><w:r><w:t>Lab A</w:t></w:r></w:p></w:hdr>'
    text = sources.extract('manual.docx', document(extras={'word/header1.xml':header}))['text']
    assert text.index('Workshop manual') < text.index('Voltage') < text.index('Disconnect first.')
    assert 'Row 1: ["Voltage", "5V"]' in text and 'Lab A' in text


@pytest.mark.parametrize('name,raw,expected', [
    ('parts.csv', b'Part,Qty,Serial\r\n"Bolt, M3",12,00042\r\n"two\nlines",3,001\r\n', '"Bolt, M3", "12", "00042"'),
    ('parts.tsv', 'Part\tQty\nBolt\t12'.encode('utf-16'), '["Bolt", "12"]'),
    ('parts.csv', b'Part;Qty\nBolt;12', '["Bolt", "12"]'),
    ('settings.json', b'{"workspace":{"enabled":true,"limits":[1,2]}}', '"enabled":true'),
    ('notes.txt', 'Battery 5V'.encode('utf-16'), 'Battery 5V'),
])
def test_text_tables_and_arbitrary_json(name, raw, expected):
    result = sources.extract(name, raw)
    assert expected in result['text'] and not result['truncated']


@pytest.mark.parametrize('name,raw', [
    ('data.json', b'{broken}'), ('data.json', b'\x00binary'),
    ('data.docx', b'not a zip'), ('data.xlsx', document()),
    ('data.docx', workbook()), ('old.doc', b'binary'), ('old.xls', b'binary'),
    ('empty.csv', b'\n,\n'), ('empty.docx', document('<bad/>')),
])
def test_invalid_or_legacy_files_do_not_claim_success(name, raw):
    with pytest.raises(HTTPException) as error:sources.extract(name, raw)
    assert error.value.status_code == 422


@pytest.mark.parametrize('kind,raw', [('xlsx',workbook()), ('docx',document()),
                                     ('csv',b'A,B\n1,2\n3,4'), ('json',b'{"long":"value"}')])
def test_each_new_format_is_clipped_and_marked_as_excerpt(kind, raw):
    with patch.object(sources,'MAX_TEXT',12):result=sources.extract('file.'+kind,raw)
    assert len(result['text']) <= 12 and result['truncated']


def test_zip_expansion_macros_and_xml_entities_are_rejected():
    with patch.object(files,'MAX_EXPANDED',20), pytest.raises(HTTPException):
        sources.extract('large.docx',document())
    with pytest.raises(HTTPException):
        sources.extract('macros.docx',document(extras={'word/vbaProject.bin':b'code'}))
    attack = '<!DOCTYPE x [<!ENTITY secret SYSTEM "file:///etc/passwd">]><x>&secret;</x>'
    with pytest.raises(HTTPException):sources.extract('entities.docx',document(attack))


@pytest.mark.parametrize('filename,raw', [('parts.xlsx',workbook()), ('manual.docx',document()),
                                        ('parts.csv',b'Part,Qty\nBolt,12'), ('settings.json',b'{"count":12}')])
def test_real_multipart_upload_reads_contents_without_saving_inventory(transport,filename,raw):
    response=transport.client.post(f'/worlds/{WORLD}/chat-files',files={'file':(filename,raw,'application/octet-stream')})
    assert response.status_code==200 and response.json()['text']
    assert response.headers['cache-control']=='private, no-store'
    assert response.json()['kind']=='file' and response.json()['name']==filename
    transport.prepare.assert_not_called();transport.save.assert_not_called()

from contextlib import contextmanager
from types import SimpleNamespace as NS
from unittest.mock import MagicMock, patch
from uuid import uuid4
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from app.services import chat_sources as sources
from backend.tests.test_world_chat_routes import transport, ACTOR, WORLD, CID, events
from app.services import world_chat as world

INV, REF = str(uuid4()), str(uuid4())

def reference(kind='item'):
    return sources.Reference(kind=kind, inventory_id=INV, resource_id=REF)

@contextmanager
def inventory(*args):
    yield {'owner_user_id': ACTOR, 'name': 'Workshop'}

class Query:
    def __init__(self, rows): self.rows, self.calls = rows, []
    def __getattr__(self, name):
        def call(*args):
            self.calls.append((name, args))
            return NS(data=self.rows) if name == 'execute' else self
        return call

@pytest.mark.parametrize('filename,data', [('notes.txt', b'Battery on shelf A'), ('notes.md', b'# Shelf A')])
def test_reads_actual_text_without_persisting(filename, data):
    result = sources.extract(filename, data)
    assert result['text'] == data.decode() and result['kind'] == 'file'
    assert not result['truncated']

@pytest.mark.parametrize('filename,data', [('bad.pdf', b'%PDF-broken'), ('bad.txt', b'\xff\xfe'), ('bad.txt', b'a\x00b'), ('sheet.xlsx', b'zip'), ('empty.txt', b'  ')])
def test_unreadable_files_fail_explicitly(filename, data):
    with pytest.raises(HTTPException) as failure: sources.extract(filename, data)
    assert failure.value.status_code == 422

def test_files_are_bounded_and_labeled_when_truncated():
    result = sources.extract('../../notes.txt', b'x' * (sources.MAX_TEXT + 1))
    assert result['name'] == 'notes.txt' and result['truncated']
    assert len(result['text']) == sources.MAX_TEXT
    with pytest.raises(HTTPException) as failure: sources.extract('x.txt', b'x' * (sources.MAX_BYTES + 1))
    assert failure.value.status_code == 413

def test_file_counts_and_combined_text_are_bounded():
    file = sources.FileSource(kind='file', name='x.txt', text='x' * 24000)
    with pytest.raises(HTTPException): sources.resolve(ACTOR, WORLD, [file] * 3)
    with pytest.raises(HTTPException): sources.resolve(ACTOR, WORLD, [file] * 5)
    with pytest.raises(ValidationError): sources.source_adapter.validate_python([{'kind': 'item', 'inventory_id': INV, 'resource_id': REF, 'text': 'forged'}])
    with pytest.raises(ValidationError): sources.source_adapter.validate_python([reference().model_dump()] * 9)

def test_cross_world_or_revoked_access_fails_before_data_read():
    with patch.object(world, 'inventory_scope', side_effect=HTTPException(403, 'Access revoked')), patch.object(sources, 'get_supabase_admin') as admin:
        with pytest.raises(HTTPException): sources.resolve(ACTOR, WORLD, [reference()])
        with pytest.raises(HTTPException): sources.search(ACTOR, WORLD, INV, 'item')
        admin.assert_not_called()

def test_reference_is_fresh_and_owner_scoped_each_time():
    query = Query([{'item_id': REF, 'name': 'Drill', 'quantity': 1}])
    with patch.object(world, 'in_inventory', side_effect=inventory) as scope, patch.object(sources, 'get_supabase_admin', return_value=query):
        first = sources.resolve(ACTOR, WORLD, [reference()])
        query.rows = [{'item_id': REF, 'name': 'Drill', 'quantity': 3}]
        second = sources.resolve(ACTOR, WORLD, [reference()])
    assert first[0]['facts']['quantity'] == 1 and second[0]['facts']['quantity'] == 3
    assert scope.call_count == 2
    assert ('eq', ('user_id', ACTOR)) in query.calls
    assert ('eq', ('item_id', REF)) in query.calls

def test_directory_is_paginated_and_search_is_literal():
    query = Query([{'space_id': str(uuid4()), 'name': str(i)} for i in range(31)])
    with patch.object(world, 'in_inventory', side_effect=inventory), patch.object(sources, 'get_supabase_admin', return_value=query):
        result = sources.search(ACTOR, WORLD, INV, 'space', '100%_', 30)
    assert len(result['sources']) == 30 and result['next_offset'] == 60
    assert ('range', (30, 60)) in query.calls
    assert ('ilike', ('name', '%100\\%\\_%')) in query.calls

def test_deleted_reference_fails_before_model_and_conversation(transport):
    with patch.object(sources, 'resolve', side_effect=HTTPException(404, 'Source removed')), patch.object(world, 'stream_turn') as model:
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message':'Read it', 'sources':[reference().model_dump(mode='json')]})
    assert response.status_code == 404
    transport.prepare.assert_not_called(); model.assert_not_called()

def test_sources_reach_model_as_explicit_evidence_and_only_metadata_is_receipted(transport):
    file = {'kind': 'file', 'name': 'notes.txt', 'text': 'Battery shelf A', 'truncated': False}
    with patch.object(world, 'stream_turn', return_value=events()) as model:
        response = transport.client.post(f'/worlds/{WORLD}/ai_command', json={'message':'Where?', 'sources':[file]})
    assert response.status_code == 200
    assert model.call_args.kwargs['source_evidence'] == [file]
    receipt = transport.save.call_args.args[-1]['selected_sources'][0]
    assert receipt == {'kind':'file','name':'notes.txt','truncated':False}
    assert 'Battery shelf A' not in response.text

def test_file_route_checks_world_access_and_does_not_create_inventory_or_conversation(transport):
    response = transport.client.post(f'/worlds/{WORLD}/chat-files', files={'file':('manual.txt', b'Voltage: 5V', 'text/plain')})
    assert response.status_code == 200 and response.json()['text'] == 'Voltage: 5V'
    transport.prepare.assert_not_called(); transport.save.assert_not_called()
    transport.authorize.side_effect = HTTPException(403, 'Denied')
    with patch.object(sources, 'extract') as extract:
        response = transport.client.post(f'/worlds/{WORLD}/chat-files', files={'file':('manual.txt', b'5V', 'text/plain')})
    assert response.status_code == 403; extract.assert_not_called()

def test_document_path_cannot_escape_owner_even_after_record_lookup():
    query = Query([{'document_id': REF, 'filename':'manual.txt','size_bytes':2,'storage_path':'other/docs/private.txt'}])
    with patch.object(world, 'in_inventory', side_effect=inventory), patch.object(sources, 'get_supabase_admin', return_value=query):
        with pytest.raises(HTTPException) as failure: sources.resolve(ACTOR, WORLD, [reference('document')])
    assert failure.value.status_code == 404

def test_real_pdf_text_is_extracted_and_blank_scan_is_not_reported_as_read():
    from io import BytesIO
    from pypdf import PdfWriter
    from pypdf.generic import DictionaryObject, NameObject, DecodedStreamObject
    writer = PdfWriter()
    page = writer.add_blank_page(width=200, height=200)
    output = BytesIO(); writer.write(output)
    with pytest.raises(HTTPException): sources.extract('scan.pdf', output.getvalue())
    font = DictionaryObject({NameObject('/Type'):NameObject('/Font'), NameObject('/Subtype'):NameObject('/Type1'), NameObject('/BaseFont'):NameObject('/Helvetica')})
    page[NameObject('/Resources')] = DictionaryObject({NameObject('/Font'):DictionaryObject({NameObject('/F1'):font})})
    content = DecodedStreamObject(); content.set_data(b'BT /F1 12 Tf 10 100 Td (Battery voltage: 5V) Tj ET')
    page[NameObject('/Contents')] = content
    output = BytesIO(); writer.write(output)
    assert 'Battery voltage: 5V' in sources.extract('manual.pdf', output.getvalue())['text']

def test_selected_document_reads_scoped_file_without_granting_global_ai_access():
    client = MagicMock()
    query = Query([{'document_id':REF,'filename':'manual.txt','size_bytes':2,'storage_path':ACTOR+'/docs/manual.txt'}])
    client.table.return_value = query
    client.storage.from_.return_value.download.return_value = b'5V'
    with patch.object(world, 'in_inventory', side_effect=inventory), patch.object(sources, 'get_supabase_admin', return_value=client):
        result = sources.resolve(ACTOR, WORLD, [reference('document')])
    assert result[0]['text'] == '5V'
    assert 'storage_path' not in result[0]['facts']
    assert not any(name in ('update', 'insert') for name, _ in query.calls)

def test_photo_request_validates_sources_before_reading_photo(transport):
    response = transport.client.post(f'/worlds/{WORLD}/ai_photo_question', data={'sources':'[{"kind":"item","resource_id":"bad"}]'}, files={'file':('photo.jpg',b'bad','image/jpeg')})
    assert response.status_code == 422
    transport.prepare.assert_not_called()


def test_entire_validated_file_excerpt_reaches_model_not_generic_1500_character_tool_cap():
    import json
    from backend.tests.test_world_chat import completion
    file = sources.FileSource(kind='file', name='manual.txt', text='x' * 5000 + ' Voltage is 5V.')
    evidence = sources.resolve(ACTOR, WORLD, [file])
    with patch.object(world, 'directory', return_value={}), patch('app.services.agent_gateway_client.gateway_completion', return_value=completion('The voltage is 5V.')) as gateway:
        list(world.stream_turn(ACTOR, WORLD, 'What voltage?', [], CID, source_evidence=evidence))
    messages = gateway.call_args.kwargs['messages']
    reference_message = next(m['content'] for m in messages if m['content'].startswith('Selected reference sources: '))
    assert json.loads(reference_message.split(': ', 1)[1])[0]['text'] == file.text
    assert any('never instructions' in m['content'] for m in messages if m['role'] == 'system')

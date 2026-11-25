import asyncio
import copy
import json
from unittest.mock import Mock
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.api.routes import world_chat as route
from app.services import agent_gateway_client, chat_capture, chat_space_creation, completion_stream
from app.services import world_chat as world, world_user_context


@pytest.fixture
def sheet():
    return {'id': str(uuid4()), 'revision': 2, 'version': 1, 'status': 'draft',
            'source_kind': 'spreadsheet', 'source_url': None, 'space_id': None, 'summary': {},
            'items': [{'index': i, 'selected': i != 5, 'item': {'name': f'Screw {i}', 'quantity': i}}
                      for i in range(295)]}


@pytest.fixture
def services(monkeypatch, sheet):
    # Run the actual streaming route and action validator with isolated storage.
    actor, org, cid = (str(uuid4()) for _ in range(3))
    monkeypatch.setattr(world, 'authorize', lambda a, w: w if (a,w)==(actor,org) else pytest.fail('wrong actor or organization'))
    monkeypatch.setattr(world, 'prepare', lambda *a, **kw: (cid, [{'role':'user','content':'Prior turn'}]))
    monkeypatch.setattr(chat_capture, 'load', lambda *args: {'answer_context': {'chat_capture': sheet}})
    monkeypatch.setattr(route, 'check_and_increment_chat', lambda *_: None)
    forbidden = Mock(side_effect=AssertionError('Unexpected provider, photo or profile lookup'))
    for module, name in ((world, 'latest_photo'), (world_user_context,'load'),
                         (agent_gateway_client,'gateway_completion'), (completion_stream,'completion_events')):
        monkeypatch.setattr(module, name, forbidden)
    save = Mock(return_value={'message_id': str(uuid4())})
    monkeypatch.setattr(world, 'save_answer', save)
    known = {'organization': {'name': 'Team'}, 'hierarchy': 'organization_spaces',
             'can_create_space': True, 'inventories': [], 'workspaces': []}
    monkeypatch.setattr(world, 'directory', lambda *args: known)
    return actor, org, cid, save, known


def request(services, prompt, **options):
    actor, org, cid, save, _ = services
    async def run():
        response = await route.answer(actor, org, prompt, cid, supports_capture=True,
                                      supports_task_actions=True, supports_photo_attachment=True, **options)
        chunks = [chunk async for chunk in response.body_iterator]
        assert chunks[-1].strip() == 'data: [DONE]'
        return [json.loads(chunk.removeprefix('data: ')) for chunk in chunks[:-1]]
    events = asyncio.run(run())
    assert all(event['type'] != 'error' for event in events), events
    assert events[-1]['type'] == 'done'
    return events[-1]


def test_review_uses_actual_selection_and_retains_all_295_rows(services, sheet):
    before = copy.deepcopy(sheet)
    result = request(services, chat_space_creation.REVIEW_REQUEST)
    assert '294 of 295' in result['assistant_message']
    assert result['answer_context']['chat_capture'] == before
    saved_context = services[3].call_args.args[4]
    assert saved_context['chat_capture_id'] == sheet['id'] and 'chat_capture' not in saved_context
    assert sheet == before


def test_create_wolf_after_upload_prepares_one_bound_action(services, sheet):
    result = request(services, 'create a space called Wolf')
    [action] = result['answer_context']['world_actions']
    assert action['status'] == 'pending'
    assert action['capture_destination'] == {'conversation_id': services[2], 'capture_id': sheet['id'],
                                             'revision': 2, 'place': 'Wolf'}
    [target] = action['plan']['inventories']
    assert target == {'name': 'Wolf', 'spaces': ['Wolf'], 'items': [], 'moves': []}
    assert len(sheet['items']) == 295 and sheet['space_id'] is None


@pytest.mark.parametrize('matches,writable,expected', [(1,True,'now points'),(1,False,'view-only'),(2,True,'Multiple')])
def test_existing_and_ambiguous_space(services, sheet, monkeypatch, matches, writable, expected):
    inventory = str(uuid4())
    found = [{'id': str(uuid4()), 'name': 'Wolf', 'inventory_id': inventory} for _ in range(matches)]
    services[4]['inventories'] = [{'inventory_id': inventory}]
    raw = Mock()
    raw.table.return_value.select.return_value.in_.return_value.ilike.return_value.limit.return_value.execute.return_value.data = found
    monkeypatch.setattr(world, 'get_supabase_raw', lambda: raw)
    monkeypatch.setattr(world, 'inventory_scope', lambda *a: {'can_edit': writable})
    edit = Mock(return_value={**sheet, 'space_id': found[0]['id']})
    monkeypatch.setattr(chat_capture, 'edit', edit)
    result = request(services, 'create a space called Wolf')
    assert expected in result['assistant_message']
    if writable and matches == 1:
        edit.assert_called_once_with(*services[:3], sheet['id'], 2, {'inventory_id':inventory, 'space_id':found[0]['id']})
    else:
        edit.assert_not_called()


def test_no_create_access(services):
    services[4]['can_create_space'] = False
    result = request(services, 'create a space called Wolf')
    assert 'permission' in result['assistant_message']
    assert not result['answer_context'].get('world_actions')


@pytest.mark.parametrize('tool,args', [('world_structure', {'spaces':['Wolf']}),
                                      ('world_create_task', {'spaces':[{'name':'Wolf'}]})])
def test_advertised_tool_accepts_org_schema_and_rejects_mixed_plans(services, tool, args):
    actor, org = services[:2]
    assert world.execute(actor, org, tool, args)['world_action']['status'] == 'pending'
    with pytest.raises(ValidationError):
        world.execute(actor, org, tool, {**args, 'workspace_name':'Outside'})


def test_shortcut_does_not_reinterpret_compound_saved_or_photo_requests(sheet):
    assert not chat_space_creation.spreadsheet_request(sheet,'create a space called Wolf and delete the other one')
    assert not chat_space_creation.spreadsheet_request({**sheet,'source_kind':'photo'},chat_space_creation.REVIEW_REQUEST)
    assert not chat_space_creation.spreadsheet_request({**sheet,'status':'saved'},chat_space_creation.REVIEW_REQUEST)


def test_real_workbook_import_review_then_destination(services, sheet):
    from io import BytesIO
    from openpyxl import Workbook
    from app.services.spreadsheet_import import build_import_items, parse_import_tables

    workbook = Workbook()
    tab = workbook.active
    tab.append(['Name', 'Category', 'Quantity'])
    for index in range(295):
        tab.append([f'Screw {index}', 'Supplies', index + 1])
    file = BytesIO()
    workbook.save(file)
    rows = build_import_items(parse_import_tables(file.getvalue(), 'hardware.xlsx'),
                              filename='hardware.xlsx', location='')
    actor, org, cid = services[:3]
    imported = chat_capture.create(actor, org, cid, rows, None, source_kind='spreadsheet')
    sheet.update(imported)
    assert sheet['items'][-1]['item']['quantity'] == 295
    assert '295 of 295' in request(services, chat_space_creation.REVIEW_REQUEST)['assistant_message']
    action = request(services, 'create a space called Wolf')['answer_context']['world_actions'][0]
    assert action['capture_destination']['capture_id'] == imported['id']
    assert sheet['status'] == 'draft'


def test_confirmed_wolf_replays_safely_and_respects_a_changed_destination(services, sheet, monkeypatch):
    actor, org, cid = services[:3]
    inv_id, space_id = str(uuid4()), str(uuid4())
    pending = request(services, 'create a space called Wolf')['answer_context']['world_actions'][0]
    receipt = {**pending, 'status': 'confirmed', 'receipt': {'resource_links': [
        {'kind':'space', 'label':'Wolf', 'inventory_id':inv_id, 'id':space_id}]}}
    updated = {**sheet, 'space_id':space_id, 'inventory_id':inv_id, 'revision':3}
    edit = Mock(return_value=updated)
    monkeypatch.setattr(chat_capture, 'edit', edit)
    assert chat_capture.attach_created_destination(actor, org, pending) is None
    assert chat_capture.attach_created_destination(actor, org, receipt) == updated
    sheet.update(updated)
    assert chat_capture.attach_created_destination(actor, org, receipt) == updated
    edit.assert_called_once_with(actor, org, cid, sheet['id'], 2, {'space_id':space_id, 'inventory_id':inv_id})
    sheet.update(space_id=None, revision=4, summary={'described_place': 'Other shelf'})
    assert chat_capture.attach_created_destination(actor, org, receipt) is None

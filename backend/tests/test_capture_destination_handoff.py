"""Creation confirmation preserves edited drafts and never chooses over the user."""
from contextlib import contextmanager
from copy import deepcopy
from types import SimpleNamespace as NS
from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.services import chat_capture as c, world_chat as w, spaces_repo

ACTOR, WORLD, CID, CAPTURE, INV, SPACE = [str(uuid4()) for _ in range(6)]


@pytest.fixture
def state(monkeypatch):
    draft = {'id': CAPTURE, 'version': 1, 'revision': 3, 'status': 'draft',
             'inventory_id': None, 'space_id': None, 'destination_label': None,
             'source_kind': 'photo', 'source_url': 'https://example.test/original.jpg',
             'summary': {'described_place': 'Bathroom', 'unknown_quantity_indices': [1]},
             'items': [
                 {'index': 0, 'selected': True, 'item': {'name': 'Soap', 'category': 'Other',
                  'quantity': 4, 'image_url': 'https://example.test/crop.jpg', 'notes': 'Corrected by user'}},
                 {'index': 1, 'selected': False, 'item': {'name': 'Unknown item', 'category': 'Other',
                  'quantity': 1, 'scan_evidence': {'needs_review': True, 'quantity_basis': 'unknown'}}}]}
    action = {'id': str(uuid4()), 'status': 'confirmed', 'version': 2,
              'capture_destination': {'conversation_id': CID, 'capture_id': CAPTURE,
                                      'place': 'Bathroom', 'revision': 2},
              'receipt': {'resource_links': [{'kind': 'space', 'id': SPACE,
                                            'inventory_id': INV, 'label': 'Bathroom'}]}}
    store = NS(draft=draft, action=action, writes=0)

    def load(actor, key, cid, capture_id):
        assert (actor, key, cid, capture_id) == (ACTOR, WORLD, CID, CAPTURE)
        return {'id': CAPTURE, 'answer_context': {'chat_capture': deepcopy(store.draft)}}

    def replace(cid, row, changed):
        assert cid == CID
        if row['answer_context']['chat_capture']['revision'] != store.draft['revision']:
            raise HTTPException(409, 'Concurrent edit')
        store.draft = deepcopy(changed)
        store.writes += 1
        return changed

    inv = {'inventory_id': INV, 'owner_user_id': ACTOR, 'can_edit': True,
           'name': 'Bathroom', 'workspace': {'name': 'Personal'}}
    def scope(actor, world, inventory_id):
        assert (actor, world, inventory_id) == (ACTOR, WORLD, INV)
        return inv

    @contextmanager
    def in_inventory(actor, world, inventory_id):
        yield scope(actor, world, inventory_id)

    monkeypatch.setattr(c, 'load', load)
    monkeypatch.setattr(c, 'replace', replace)
    monkeypatch.setattr(w, 'inventory_scope', scope)
    monkeypatch.setattr(w, 'in_inventory', in_inventory)
    monkeypatch.setattr(spaces_repo, 'list_spaces', lambda **kw: [{'id': SPACE, 'name': 'Bathroom'}])
    # All persistence beyond the draft CAS is forbidden in these handoff checks.
    monkeypatch.setattr(c, 'get_supabase_raw', Mock(side_effect=AssertionError('Unexpected write')))
    return store


def attach(state):
    return c.attach_created_destination(ACTOR, WORLD, state.action)


def test_item_revision_change_keeps_corrections_crops_and_selection(state):
    before = deepcopy(state.draft)
    attached = attach(state)
    assert attached['space_id'] == SPACE and attached['inventory_id'] == INV
    assert attached['location'] == 'Bathroom' and attached['status'] == 'draft'
    assert attached['revision'] == 4
    for key in ('items', 'summary', 'source_url', 'source_kind'):
        assert attached[key] == before[key]
    assert state.writes == 1


def test_edit_can_arrive_after_proposal_without_prior_described_place(state):
    state.draft['summary'].pop('described_place')
    assert attach(state)['space_id'] == SPACE


def test_named_destination_matching_ignores_case_and_outer_spaces(state):
    state.draft['summary']['described_place'] = ' bathroom '
    assert attach(state)['space_id'] == SPACE


def test_same_inventory_selection_does_not_block_handoff(state):
    state.draft['inventory_id'] = INV
    assert attach(state)['space_id'] == SPACE


@pytest.mark.parametrize('case', ['new_place', 'new_inventory', 'new_space', 'saving', 'saved',
                                 'cancelled_action', 'pending_action', 'future_revision',
                                 'missing_receipt', 'ambiguous_receipt', 'wrong_receipt_name'])
def test_never_overrides_changed_destination_or_frozen_draft(state, case):
    if case == 'new_place':
        state.draft['summary']['described_place'] = 'Kitchen'
    elif case == 'new_inventory':
        state.draft['inventory_id'] = str(uuid4())
    elif case == 'new_space':
        state.draft.update(inventory_id=INV, space_id=str(uuid4()))
    elif case in ('saving', 'saved'):
        state.draft['status'] = case
    elif case.endswith('_action'):
        state.action['status'] = case.split('_')[0]
    elif case == 'future_revision':
        state.action['capture_destination']['revision'] = 10
    elif case == 'missing_receipt':
        state.action['receipt']['resource_links'] = []
    elif case == 'ambiguous_receipt':
        state.action['receipt']['resource_links'] *= 2
    else:
        state.action['receipt']['resource_links'][0]['label'] = 'Kitchen'
    before = deepcopy(state.draft)
    assert attach(state) is None
    assert state.draft == before and state.writes == 0


@pytest.mark.parametrize('status', ['draft', 'saving', 'saved'])
def test_same_confirmed_receipt_retry_is_idempotent(state, status):
    attach(state)
    state.draft['status'] = status
    state.draft['processed_count'] = 1
    before = deepcopy(state.draft)
    assert attach(state) == before
    assert state.writes == 1


def test_legacy_binding_still_requires_matching_requested_place(state):
    state.action['capture_destination'].pop('revision')
    assert attach(state)['space_id'] == SPACE


def test_legacy_binding_without_place_is_not_reinterpreted(state):
    state.action['capture_destination'].pop('revision')
    state.draft['summary'].pop('described_place')
    assert attach(state) is None and state.writes == 0


def test_revoked_permission_cannot_attach(state, monkeypatch):
    monkeypatch.setattr(w, 'inventory_scope', Mock(side_effect=HTTPException(403, 'Revoked')))
    with pytest.raises(HTTPException) as exc:
        attach(state)
    assert exc.value.status_code == 403 and state.writes == 0


def test_deleted_space_cannot_attach(state, monkeypatch):
    monkeypatch.setattr(spaces_repo, 'list_spaces', lambda **kw: [])
    with pytest.raises(HTTPException) as exc:
        attach(state)
    assert exc.value.status_code == 403 and state.writes == 0


def test_concurrent_destination_edit_between_reads_is_preserved(state, monkeypatch):
    original_load = c.load
    calls = 0
    def race(*args):
        nonlocal calls
        calls += 1
        if calls == 2:
            state.draft['revision'] += 1
            state.draft['summary']['described_place'] = 'Kitchen'
        return original_load(*args)
    monkeypatch.setattr(c, 'load', race)
    with pytest.raises(HTTPException) as exc:
        attach(state)
    assert exc.value.status_code == 409 and state.writes == 0
    assert state.draft['summary']['described_place'] == 'Kitchen'


def test_concurrent_edit_at_cas_does_not_lose_item_changes(state, monkeypatch):
    original_replace = c.replace
    def race(*args):
        state.draft['revision'] += 1
        state.draft['items'][0]['item']['quantity'] = 7
        return original_replace(*args)
    monkeypatch.setattr(c, 'replace', race)
    with pytest.raises(HTTPException) as exc:
        attach(state)
    assert exc.value.status_code == 409 and state.writes == 0
    assert state.draft['items'][0]['item']['quantity'] == 7

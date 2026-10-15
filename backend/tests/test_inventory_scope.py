from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from app.services.inventory_scope import InventoryClient, InventoryScope, current_inventory, inventory_cache_key
from app.services.capture_previews import InvalidCapturePreview, preview_uncertain_items, verify_capture_preview


def client(role='member'):
    raw = MagicMock()
    query = MagicMock()
    for method in ('select', 'eq', 'or_', 'limit', 'insert', 'update', 'delete', 'in_', 'upsert', 'order'):
        getattr(query, method).return_value = query
    raw.table.return_value = query
    query.execute.return_value = SimpleNamespace(data=[])
    return InventoryClient(raw, InventoryScope('inventory-a', 'actor', 'owner', 'team', role)), query


@pytest.mark.parametrize('table', ['items', 'spaces', 'activity_log', 'documents', 'capture_reviews', 'checkouts', 'project_kits'])
def test_every_read_and_update_keeps_inventory_filter_even_when_owner_filters_are_replaced(table):
    scope, query = client()
    scope.table(table).select('*').eq('user_id', 'owner').execute()
    query.eq.assert_any_call('inventory_id', 'inventory-a')
    assert ('user_id', 'owner') not in [call.args for call in query.eq.call_args_list]
    query.reset_mock()
    scope.table(table).update({'name': 'Updated'}).eq('user_id', 'owner').eq('item_id', 'foreign-item').execute()
    query.eq.assert_any_call('inventory_id', 'inventory-a')
    query.eq.assert_any_call('item_id', 'foreign-item')


@pytest.mark.parametrize('operation', ['insert', 'update', 'delete', 'upsert'])
def test_viewers_cannot_write_inventory_even_through_an_assist_tool(operation):
    scoped, query = client('viewer')
    with pytest.raises(HTTPException) as exc:
        method = getattr(scoped.table('items'), operation)
        method() if operation == 'delete' else method({'name': 'Changed'})
    assert exc.value.status_code == 403
    query.execute.assert_not_called()


def test_forged_inventory_and_cross_inventory_parent_are_rejected_before_insert():
    scoped, query = client()
    with pytest.raises(HTTPException):
        scoped.table('items').insert({'inventory_id': 'inventory-b', 'name': 'Forged'})
    with pytest.raises(HTTPException) as exc:
        scoped.table('items').insert({'space_id': 'foreign-space', 'name': 'Forged'})
    assert exc.value.status_code == 404
    query.insert.assert_not_called()


def test_private_chats_and_legacy_private_files_do_not_become_team_shared():
    scoped, query = client()
    scoped.table('conversations').select('*').eq('user_id', 'owner').execute()
    query.eq.assert_any_call('user_id', 'actor')
    scoped.table('documents').select('*').execute()
    query.or_.assert_any_call('inventory_visibility.eq.inventory,user_id.eq.actor')
    query.reset_mock()
    scoped.table('documents').insert({'user_id': 'owner', 'filename': 'New team upload'}).execute()
    assert query.insert.call_args.args[0]['inventory_visibility'] == 'inventory'


def test_private_state_uses_separate_tables_and_inventory_actor_keys():
    scoped, query = client()
    scoped.table('conversation_sessions').upsert({'user_id': 'owner', 'history': []}, on_conflict='user_id').execute()
    scoped.raw.table.assert_called_with('inventory_conversation_sessions')
    assert query.upsert.call_args.args[0]['user_id'] == 'actor'
    assert query.upsert.call_args.kwargs['on_conflict'] == 'inventory_id,user_id'
    assert inventory_cache_key('owner') == 'owner'
    token = current_inventory.set(scoped.scope)
    try:
        assert inventory_cache_key('owner') == 'inventory-a:actor:owner'
    finally:
        current_inventory.reset(token)


def test_foreign_review_and_reservation_ids_never_reach_rpc():
    scoped, _ = client()
    for name, params in [('resolve_capture_review', {'p_review_id': 'other'}),
                         ('replace_project_kit_reservations', {'p_kit_id': 'other', 'p_allocations': []})]:
        with pytest.raises(HTTPException):
            scoped.rpc(name, params)
    scoped.raw.rpc.assert_not_called()


def test_photo_proof_is_bound_to_the_inventory_not_only_the_account():
    settings = SimpleNamespace(supabase_service_role_key='test-signing-secret')
    scope = InventoryScope('a', 'actor', 'owner', None, 'owner')
    token = current_inventory.set(scope)
    try:
        with patch('app.services.capture_previews.get_settings', return_value=settings):
            preview = preview_uncertain_items(user_id='owner', source_digest='photo', items=[{
                'name': 'Unknown part', 'category': 'Hardware', 'quantity': 1,
                'scan_evidence': {'needs_review': True},
            }])[0]
            assert verify_capture_preview(user_id='owner', preview_id=preview['review_id'], token=preview['review_token'])['inventory_id'] == 'a'
            second = current_inventory.set(InventoryScope('b', 'actor', 'owner', None, 'owner'))
            try:
                with pytest.raises(InvalidCapturePreview):
                    verify_capture_preview(user_id='owner', preview_id=preview['review_id'], token=preview['review_token'])
            finally:
                current_inventory.reset(second)
    finally:
        current_inventory.reset(token)

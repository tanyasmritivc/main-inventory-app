from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from app.services import deletion_cleanup as cleanup


def fake(files, referenced=False, failure=False):
    client=MagicMock()
    def table(name):
        q=MagicMock()
        q.select.return_value=q; q.eq.return_value=q; q.range.return_value=q; q.order.return_value=q; q.update.return_value=q
        if name=='app_inventory_deletions': data=[{'files':files,'completed':False}]
        elif name=='items' and referenced: data=[{'image_url':'https://host/storage/v1/object/sign/item-images/actor/photo.jpg?token=other'}]
        else: data=[]
        q.execute.return_value=SimpleNamespace(data=data)
        return q
    client.table.side_effect=table
    client.storage.from_.return_value.list.return_value=[]
    if failure: client.storage.from_.return_value.remove.side_effect=RuntimeError('private path')
    return client


def test_cleanup_keeps_shared_objects_and_only_removes_recorded_owner_paths():
    files=[{'kind':'image','url':'https://host/storage/v1/object/public/item-images/actor/photo.jpg','owner':'actor'},
           {'kind':'document','path':'actor/docs/manual.pdf','owner':'actor'}]
    client=fake(files,referenced=True)
    with patch.object(cleanup,'get_supabase_raw',return_value=client),patch.object(cleanup,'get_settings',return_value=SimpleNamespace(supabase_storage_bucket='item-images')):
        assert cleanup.clean_inventory_files('inventory')
    client.storage.from_.assert_called_once_with('documents')
    client.storage.from_.return_value.remove.assert_called_once_with(['actor/docs/manual.pdf'])


def test_failed_storage_cleanup_is_durable_and_retryable():
    file={'kind':'document','path':'actor/docs/manual.pdf','owner':'actor'}
    client=fake([file],failure=True)
    with patch.object(cleanup,'get_supabase_raw',return_value=client):
        assert not cleanup.clean_inventory_files('inventory')
        client.storage.from_.return_value.remove.side_effect=None
        assert cleanup.clean_inventory_files('inventory')


def test_foreign_path_and_incomplete_reference_scan_fail_closed():
    client=fake([{'kind':'document','path':'other/docs/manual.pdf','owner':'actor'}])
    with patch.object(cleanup,'get_supabase_raw',return_value=client):
        assert not cleanup.clean_inventory_files('inventory')
    client.storage.from_.assert_not_called()
    query=MagicMock();query.select.return_value=query;query.order.return_value=query;query.range.return_value=query;query.execute.return_value=SimpleNamespace(data=None)
    with patch.object(cleanup,'MAX_REFERENCE_ROWS',1):
        client.table.side_effect=lambda _:query
        try: cleanup._references(client)
        except ValueError: pass
        else: raise AssertionError('Unknown reference set accepted')


def test_signed_public_and_embedded_reference_urls_resolve_to_same_path():
    client=fake([])
    original=client.table.side_effect
    def table(name):
        q=original(name)
        if name=='messages': q.execute.return_value=SimpleNamespace(data=[{'content':'Look at https://host/storage/v1/object/public/item-images/actor/photo.jpg'}])
        return q
    client.table.side_effect=table
    with patch.object(cleanup,'get_settings',return_value=SimpleNamespace(supabase_storage_bucket='item-images')):
        assert 'actor/photo.jpg' in cleanup._references(client)[0]


def test_account_cleanup_waits_for_identity_removal_and_resumes_from_receipt():
    client=fake([{'kind':'profile','path':'actor/avatar.jpg','owner':'actor'}])
    original=client.table.side_effect
    client.table.side_effect=lambda name: original('app_inventory_deletions' if name=='app_account_deletions' else name)
    client.rpc.return_value.execute.return_value=SimpleNamespace(data=False)
    with patch.object(cleanup,'get_supabase_raw',return_value=client):
        assert not cleanup.clean_account_files('actor')
        client.storage.from_.assert_not_called()
        client.rpc.return_value.execute.return_value=SimpleNamespace(data=True)
        assert cleanup.clean_account_files('actor')
    client.storage.from_.assert_any_call('profile-photos')
    client.storage.from_.return_value.remove.assert_called_once_with(['actor/avatar.jpg'])

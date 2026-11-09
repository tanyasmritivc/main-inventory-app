"""Timeout recovery must prove receipts and keep stable item identities."""
from copy import deepcopy
from types import SimpleNamespace as NS

import pytest

from app.services import capture_save as save, chat_capture as chat, recognition_learning


class StatementTimeout(Exception):
    code = '57014'


class Store:
    def __init__(self):
        self.rows, self.calls, self.modes = {}, [], {}
        self.reads_fail = False
        self.fail_read_after_timeout = False

    def table(self, name):
        assert name == 'items'
        return Query(self)


class Query:
    def __init__(self, store):
        self.store, self.filters, self.payload = store, [], None

    def select(self, *args):
        return self

    def eq(self, key, value):
        self.filters.append(lambda row: row.get(key) == value)
        return self

    def in_(self, key, values):
        self.filters.append(lambda row: row.get(key) in values)
        return self

    def insert(self, payload):
        self.payload = deepcopy(payload)
        return self

    def execute(self):
        if self.payload is None:
            if self.store.reads_fail:
                raise ConnectionError('Receipt lookup unavailable')
            return NS(data=deepcopy([r for r in self.store.rows.values() if all(f(r) for f in self.filters)]))
        self.store.calls.append(deepcopy(self.payload))
        mode = self.store.modes.get(len(self.store.calls))
        if mode == 'timeout_before':
            self.store.reads_fail = self.store.fail_read_after_timeout
            raise StatementTimeout()
        if mode == 'connection_before':
            raise ConnectionError()
        if any(r['item_id'] in self.store.rows for r in self.payload):
            raise ValueError('Existing identity')
        for row in self.payload:
            self.store.rows[row['item_id']] = deepcopy(row)
        if mode == 'timeout_after':
            raise StatementTimeout()
        if mode == 'connection_after':
            raise ConnectionError()
        return NS(data=deepcopy(self.payload))


@pytest.fixture
def store(monkeypatch):
    db = Store()
    monkeypatch.setattr(save, 'get_supabase_admin', lambda: db)
    monkeypatch.setattr(save, '_resolve_space_id', lambda **kw: 'space-one')
    monkeypatch.setattr(save, 'verified_catalog_id_for_identity', lambda **kw: None)
    monkeypatch.setattr(save, 'invalidate_inventory_cache', lambda *args: None)
    monkeypatch.setattr(save, 'retain_capture_original', lambda **kw: None)
    monkeypatch.setattr(recognition_learning, 'record_reviewed_items', lambda rows: None)
    return db


def items(count=27):
    return [dict(name=f'Part {i}', category='Other', quantity=i + 1, location='Shelf',
                 client_request_id=f'original-capture-{i}') for i in range(count)]


def run(values=None):
    return save.save_capture_items(user_id='owner', items=items() if values is None else values)


def test_large_capture_uses_bounded_statements_and_preserves_order(store):
    rows, failures = run()
    assert not failures and len(rows) == len(store.rows) == 27
    assert [len(c) for c in store.calls] == [8, 8, 8, 3]
    assert [r['name'] for r in rows] == [r['name'] for r in items()]


def test_timeout_recovers_once_after_receipt_read_without_duplicate_ids(store):
    store.modes[1] = 'timeout_before'
    rows, failures = run()
    assert not failures and len(rows) == len(store.rows) == 27
    assert len(store.calls) == 5
    assert store.calls[0] == store.calls[1]
    before = deepcopy(store.rows)
    assert run() == (rows, [])
    assert store.rows == before and len(store.calls) == 5


@pytest.mark.parametrize('mode', ['timeout_after', 'connection_after'])
def test_lost_success_response_reads_receipt_instead_of_reinserting(store, mode):
    store.modes[1] = mode
    rows, failures = run()
    assert not failures and len(rows) == 27
    assert len(store.calls) == 4 and len(store.rows) == 27


def test_unavailable_receipt_never_authorizes_automatic_retry(store):
    store.modes[1] = 'timeout_before'
    store.fail_read_after_timeout = True
    rows, failures = run()
    assert not rows and len(failures) == 27
    assert len(store.calls) == 1 and not store.rows


def test_initial_receipt_read_failure_aborts_before_any_write(store):
    store.reads_fail = True
    with pytest.raises(ConnectionError):
        run()
    assert not store.calls


def test_repeated_timeout_stops_work_and_keeps_all_failed_indices(store):
    store.modes = {1: 'timeout_before', 2: 'timeout_before'}
    rows, failures = run()
    assert not rows and len(store.calls) == 2
    assert [f['index'] for f in failures] == list(range(27))
    store.modes = {}
    rows, failures = run()
    assert not failures and len(rows) == len(store.rows) == 27


def test_partial_success_survives_retry_without_changing_quantities(store):
    store.modes = {2: 'timeout_before', 3: 'timeout_before'}
    rows, failures = run()
    assert len(rows) == 8 and len(failures) == 19 and len(store.calls) == 3
    before = deepcopy(store.rows)
    store.modes = {}
    rows, failures = run()
    assert not failures and len(rows) == len(store.rows) == 27
    assert all(store.rows[key] == value for key, value in before.items())


def test_non_timeout_errors_are_not_retried_automatically(store):
    store.modes[1] = 'connection_before'
    rows, failures = run()
    assert not rows and len(failures) == 27 and len(store.calls) == 1


def test_only_one_timeout_retry_is_available_across_all_batches(store):
    store.modes = {1: 'timeout_before', 3: 'timeout_before'}
    rows, failures = run()
    assert len(rows) == 8 and len(failures) == 19 and len(store.calls) == 3


def test_saved_identity_with_changed_details_is_never_overwritten(store):
    rows, _ = run(items(1))
    original = deepcopy(store.rows)
    changed = items(1)
    changed[0]['quantity'] = 99
    rows, failures = run(changed)
    assert not rows and 'different details' in failures[0]['reason']
    assert store.rows == original and len(store.calls) == 1


def test_capture_error_groups_keep_all_indices_and_correct_failure_count():
    failures = [{'index': i, 'reason': 'Saving could not be confirmed.'} for i in range(27)]
    grouped = chat._group_save_failures(failures)
    assert grouped == [{'index': 0, 'indices': list(range(27)),
                        'reason': 'Saving could not be confirmed. (27 items.)'}]
    draft = {'status': 'saved', 'items': [], 'receipt': {'failures': grouped}}
    assert chat.facts(draft)['receipt']['failure_count'] == 27


def test_distinct_errors_stay_distinct_and_single_error_keeps_legacy_shape():
    failures = [{'index': 0, 'reason': 'Timeout'}, {'index': 1, 'reason': 'Timeout'},
                {'index': 2, 'reason': 'Photo unavailable'}]
    grouped = chat._group_save_failures(failures)
    assert len(grouped) == 2
    assert grouped[0]['indices'] == [0, 1]
    assert grouped[1] == failures[2]
    assert chat._group_save_failures([]) == []

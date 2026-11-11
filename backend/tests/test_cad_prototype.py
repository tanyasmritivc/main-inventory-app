"""Synthetic CAD fixtures only. No host, account, network or inventory writes."""

from copy import deepcopy
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace as NS
from uuid import uuid4

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.cad.snapshot import Snapshot, requirements
from app.services.cad.comparison import compare
from app.services.cad import repository
from app.api.routes import cad

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('fusion_exporter', ROOT / 'integrations/findez-fusion/FindEZ/exporter.py')
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


class Collection:
    def __init__(self, values=()): self.values = list(values)
    @property
    def count(self): return len(self.values)
    def item(self, i): return self.values[i]


class Attributes:
    def __init__(self, **values): self.values = values
    def itemByName(self, group, name):
        assert group == 'FindEZ'
        return NS(value=self.values[name]) if name in self.values else None


def component(key, *, name='Screw', part='M3-12', manufacturer='Example', policy='', children=(), bodies=1):
    attrs = {'manufacturer': manufacturer}
    if policy: attrs['procurement_policy'] = policy
    return NS(id=key, name=name, partNumber=part, entityToken='opaque:' + key,
              attributes=Attributes(**attrs), occurrences=Collection(children),
              bRepBodies=Collection([object()] * bodies), meshBodies=Collection())


def occurrence(comp, path, *, children=(), suppressed=False, visible=True, reference=None):
    return NS(component=comp, fullPathName=path, entityToken='occ:' + path,
              childOccurrences=Collection(children), timelineObject=NS(isSuppressed=suppressed),
              isVisible=visible, documentReference=reference, configurationRow=None)


def design(children, *, dirty=False):
    root = component('root', name='Synthetic robot', part='', manufacturer='', policy='assembly', children=children, bodies=0)
    return NS(rootComponent=root, parentDocument=NS(name='Synthetic robot', isModified=dirty,
              dataFile=NS(id='synthetic-file', versionId='v7')), isConfiguredDesign=False)


def nested_design():
    screw = component('screw')
    module = component('module', name='Module', part='', manufacturer='', policy='assembly', bodies=0)
    return design([occurrence(module, f'Module:{n}', children=[
        occurrence(screw, f'Module:{n}+Screw:{i}') for i in range(4)]) for n in range(2)])


def snapshot(): return Snapshot.model_validate(exporter.extract(nested_design(), 'synthetic-host'))


def stock(quantity=6, **values):
    return {'item_id': 'stock-1', 'name': 'Screw', 'brand': 'Example', 'part_number': 'M3-12',
            'barcode': '', 'quantity': quantity, 'location': 'Synthetic bin', **values}


def test_nested_occurrences_count_eight_not_four_or_ten():
    snap = snapshot()
    rows, warnings = requirements(snap)
    assert len(snap.occurrences) == 11
    assert len(snap.definitions) == 3
    assert [(r['name'], r['required']) for r in rows] == [('Screw', 8)]
    assert not warnings
    result = compare(snap, [stock()], [], [])
    assert result['summary']['coverage_percent'] == 75
    assert result['items'][0]['missing'] == 2


def test_purchased_subassembly_blocks_descendants():
    model = nested_design()
    model.rootComponent.occurrences.item(0).component.attributes.values['procurement_policy'] = 'purchase'
    rows, _ = requirements(Snapshot.model_validate(exporter.extract(model, 'fake')))
    assert [(r['name'], r['required']) for r in rows] == [('Module', 2)]


def test_hidden_is_counted_suppressed_subtree_is_not():
    model = nested_design()
    model.rootComponent.occurrences.item(0).isVisible = False
    model.rootComponent.occurrences.item(1).timelineObject.isSuppressed = True
    rows, _ = requirements(Snapshot.model_validate(exporter.extract(model, 'fake')))
    assert rows[0]['required'] == 4


def test_unknown_suppression_is_partial_never_silently_counted():
    model = nested_design()
    model.rootComponent.occurrences.item(0).timelineObject = None
    snap = Snapshot.model_validate(exporter.extract(model, 'fake'))
    result = compare(snap, [stock(100)], [], [])
    assert result['completeness'] == 'partial'
    assert result['summary']['required_units'] == 4
    assert result['warnings']


def test_dirty_revision_and_no_design_mutation():
    model = design([occurrence(component('part'), 'part:1')], dirty=True)
    before = repr(model)
    snap = Snapshot.model_validate(exporter.extract(model, 'fake'))
    assert snap.revision.kind == 'unsaved_session'
    assert snap.revision.id.startswith('session:')
    assert repr(model) == before


def test_ids_are_scoped_to_source_file_version_and_config():
    comp = component('copied-id')
    a = occurrence(comp, 'a', reference=NS(dataFile=NS(id='file-a', versionId='v1')))
    b = occurrence(comp, 'b', reference=NS(dataFile=NS(id='file-b', versionId='v1')))
    snap = Snapshot.model_validate(exporter.extract(design([a, b]), 'fake'))
    assert len(snap.definitions) == 3
    result = compare(snap, [stock(1)], [], [])
    assert [row['assigned'] for row in result['items']] == [1, 0]


def test_token_strings_are_not_definition_identity():
    a, b = component('same'), component('same')
    b.entityToken = 'different-but-equivalent-token'
    snap = Snapshot.model_validate(exporter.extract(design([occurrence(a, 'a'), occurrence(b, 'b')]), 'fake'))
    assert len(snap.definitions) == 2
    assert requirements(snap)[0][0]['required'] == 2


@pytest.mark.parametrize('change', ['duplicate_definition', 'duplicate_occurrence', 'cycle', 'missing_parent', 'missing_definition', 'dirty_saved', 'extra_field'])
def test_untrusted_graph_rejected(change):
    data = snapshot().model_dump(mode='json')
    if change == 'duplicate_definition': data['definitions'].append(deepcopy(data['definitions'][-1]))
    if change == 'duplicate_occurrence': data['occurrences'].append(deepcopy(data['occurrences'][-1]))
    if change == 'cycle': data['occurrences'][1]['parent_key'] = data['occurrences'][1]['key']
    if change == 'missing_parent': data['occurrences'][1]['parent_key'] = 'no-parent'
    if change == 'missing_definition': data['occurrences'][1]['definition_key'] = 'no-definition'
    if change == 'dirty_saved': data['revision']['dirty'] = True
    if change == 'extra_field': data['quantity_override'] = 9000
    with pytest.raises(ValidationError): Snapshot.model_validate(data)


def test_reservations_checkouts_are_deducted_without_mutation():
    items = [stock(15)]
    reserved = [{'inventory_item_id': 'stock-1', 'quantity': 4}]
    checked = [{'item_id': 'stock-1', 'quantity': 5}]
    before = deepcopy((items, reserved, checked))
    result = compare(snapshot(), items, reserved, checked)
    assert result['items'][0]['assigned'] == 6
    assert (items, reserved, checked) == before
    assert result['consistency'] == 'read_only_nontransactional_preview'


@pytest.mark.parametrize('quantity', [None, -1, True, '8', 1.5, float('nan')])
def test_unusable_counts_never_become_available(quantity):
    assert compare(snapshot(), [stock(quantity)], [], [])['summary']['covered_units'] == 0


@pytest.mark.parametrize('values', [{'brand': 'Other'}, {'part_number': 'M312'}, {'part_number': 'M3-10'}, {'brand': ''}])
def test_conflicts_or_missing_manufacturer_do_not_count(values):
    assert compare(snapshot(), [stock(100, **values)], [], [])['summary']['covered_units'] == 0


def test_default_part_number_and_name_match_need_review():
    model = design([occurrence(component('s', name='Screw', part='Screw'), 's')])
    result = compare(Snapshot.model_validate(exporter.extract(model, 'fake')), [stock(10, part_number='Screw')], [], [])
    assert result['items'][0]['status'] == 'needs_review'
    assert result['summary']['covered_units'] == 0


def test_exact_barcode_preserves_leading_zero_and_conflicting_brand():
    model = design([occurrence(component('s', manufacturer='', part=''), 's')])
    model.rootComponent.occurrences.item(0).component.attributes.values['barcode'] = '00123'
    snap = Snapshot.model_validate(exporter.extract(model, 'fake'))
    assert compare(snap, [stock(3, barcode='00123')], [], [])['summary']['covered_units'] == 1
    assert compare(snap, [stock(3, barcode='123')], [], [])['summary']['covered_units'] == 0


def test_large_candidate_set_is_reviewable_not_truncated_coverage():
    result = compare(snapshot(), [stock(100, item_id=str(i)) for i in range(101)], [], [])
    assert result['items'][0]['status'] == 'needs_review'
    assert result['summary']['covered_units'] == 0
    assert result['completeness'] == 'partial'


def test_no_geometry_or_arbitrary_custom_metadata_exported():
    model = nested_design()
    model.rootComponent.attributes.values['private_secret'] = 'never-export'
    raw = json.dumps(exporter.extract(model, 'fake'))
    assert 'never-export' not in raw
    assert 'bRepBodies' not in raw


def test_repository_filters_every_table_and_rechecks_membership(monkeypatch):
    authorization = []
    reads = []
    class Query:
        def __init__(self, table): self.table, self.filters = table, {}
        def select(self, fields): return self
        def eq(self, field, value): self.filters[field] = value; return self
        def order(self, field): return self
        def range(self, start, end): return self
        def execute(self): reads.append((self.table, self.filters)); return NS(data=[])
    monkeypatch.setattr(repository, '_inventory', lambda inventory, actor: authorization.append((inventory, actor)))
    monkeypatch.setattr(repository, 'get_supabase_raw', lambda: NS(table=Query))
    assert repository.read_inventory('inventory-a', 'actor-a') == ([], [], [])
    assert authorization == [('inventory-a', 'actor-a')] * 2
    assert all(filters['inventory_id'] == 'inventory-a' for _, filters in reads)
    assert reads[-1][1]['is_active'] is True


def test_revocation_or_other_inventory_denies_before_data_reads(monkeypatch):
    def deny(*args): raise HTTPException(403, 'No access')
    monkeypatch.setattr(repository, '_inventory', deny)
    monkeypatch.setattr(repository, 'get_supabase_raw', lambda: pytest.fail('No read allowed'))
    with pytest.raises(HTTPException) as exc: repository.read_inventory('other', 'actor')
    assert exc.value.status_code == 403


def test_revocation_after_reads_cannot_publish(monkeypatch):
    calls = []
    def authorize(*args):
        calls.append(1)
        if len(calls) == 2: raise HTTPException(403, 'Revoked')
    class Query:
        def __getattr__(self, name):
            if name == 'execute': return lambda: NS(data=[])
            return lambda *args: self
    monkeypatch.setattr(repository, '_inventory', authorize)
    monkeypatch.setattr(repository, 'get_supabase_raw', lambda: NS(table=lambda name: Query()))
    with pytest.raises(HTTPException): repository.read_inventory('inv', 'actor')


@pytest.fixture
def client(monkeypatch):
    app = FastAPI()
    app.include_router(cad.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='actor-a')
    monkeypatch.setattr(cad, 'read_inventory', lambda inv, actor: ([stock()], [], []))
    return TestClient(app)


def test_http_round_trip(client):
    inv = str(uuid4())
    response = client.post(f'/inventories/{inv}/cad/compare', files={'file': ('bom.json', snapshot().model_dump_json(), 'application/json')})
    assert response.status_code == 200, response.text
    assert response.json()['inventory_id'] == inv
    assert response.json()['summary']['covered_units'] == 6


@pytest.mark.parametrize('raw', [b'', b'{}', b'{"schema_version":1,"schema_version":1}', b'[[[', b'\xff'])
def test_http_bad_inputs_are_safe(client, raw):
    response = client.post(f'/inventories/{uuid4()}/cad/compare', files={'file': ('bad.json', raw)})
    assert response.status_code == 422
    assert 'traceback' not in response.text.lower()


def test_http_size_limit(client):
    response = client.post(f'/inventories/{uuid4()}/cad/compare', files={'file': ('big.json', b' ' * (cad.MAX_SNAPSHOT_BYTES + 1))})
    assert response.status_code == 413


def test_http_auth_is_required(monkeypatch):
    app = FastAPI(); app.include_router(cad.router)
    monkeypatch.setattr(cad, 'read_inventory', lambda *args: pytest.fail('Unauthenticated read'))
    response = TestClient(app).post(f'/inventories/{uuid4()}/cad/compare', files={'file': ('bom.json', '{}')})
    assert response.status_code == 401


def test_space_chat_and_wrong_actor_scope_cannot_expand_to_inventory(monkeypatch):
    from app.services.inventory_scope import current_inventory
    monkeypatch.setattr(repository, '_inventory', lambda *args: pytest.fail('Scope must be rejected first'))
    for scope in (NS(actor_id='other', inventory_id='inv'), NS(actor_id='actor', inventory_id='other'),
                  NS(actor_id='actor', inventory_id='inv', chat_space_id='space')):
        token = current_inventory.set(scope)
        try:
            with pytest.raises(HTTPException) as exc: repository.read_inventory('inv', 'actor')
            assert exc.value.status_code == 403
        finally:
            current_inventory.reset(token)


def test_download_package_matches_reviewed_sources_exactly():
    from zipfile import ZipFile
    with ZipFile(ROOT / 'frontend/public/downloads/findez-fusion-preview.zip') as archive:
        assert set(archive.namelist()) == {'README.md', 'FindEZ/FindEZ.py', 'FindEZ/FindEZ.manifest', 'FindEZ/exporter.py'}
        for name in archive.namelist():
            assert archive.read(name) == (ROOT / 'integrations/findez-fusion' / name).read_bytes()

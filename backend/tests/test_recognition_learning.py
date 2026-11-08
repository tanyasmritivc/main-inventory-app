import hashlib
import importlib.util
import io
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

import pytest
from PIL import Image
from app.services import recognition_learning as learning


def photo():
    out = io.BytesIO()
    Image.new('RGB', (24, 24), 'red').save(out, 'JPEG')
    return out.getvalue()


def example(identifier='one', name='Ball bearing'):
    return {'id': identifier, 'crop_url': 'https://allowed/crop.jpg',
            'predicted': {'name': 'Metal washer'}, 'corrected': {'name': name}}


def test_no_context_without_authenticated_inventory(monkeypatch):
    monkeypatch.setattr(learning, 'client', Mock(side_effect=AssertionError('Must not read private data')))
    monkeypatch.setattr(learning, 'request_actor', SimpleNamespace(get=lambda: None))
    assert learning.context(photo()) is None


def test_foreign_scope_is_rejected(monkeypatch):
    monkeypatch.setattr(learning, 'request_actor', SimpleNamespace(get=lambda: SimpleNamespace(actor_id='alice')))
    monkeypatch.setattr(learning, 'current_inventory', SimpleNamespace(get=lambda: SimpleNamespace(actor_id='bob')))
    monkeypatch.setattr(learning, 'client', Mock(side_effect=AssertionError('Must not read')))
    assert learning.context(photo()) is None


def test_context_disabled_or_unavailable_fails_closed(monkeypatch):
    monkeypatch.setattr(learning, 'request_actor', SimpleNamespace(get=lambda: SimpleNamespace(actor_id='alice')))
    monkeypatch.setattr(learning, 'current_inventory', SimpleNamespace(get=lambda: SimpleNamespace(actor_id='alice', inventory_id='inv')))
    db = Mock()
    db.rpc.return_value.execute.return_value.data = None
    monkeypatch.setattr(learning, 'client', lambda: db)
    assert learning.context(photo()) is None
    db.rpc.side_effect = TimeoutError
    assert learning.context(photo()) is None


def test_examples_are_relevant_bounded_and_deduplicated():
    examples = [example(), example('duplicate'), example('two', 'Lock washer'), example('three', 'Washer M3')]
    assert len(learning.select_examples(examples, ['washer'])) == 2
    assert learning.select_examples(examples, ['plastic object']) == []
    assert learning.select_examples(examples, ['battery']) == []


def test_reference_prompt_does_not_transfer_inventory_facts():
    text = learning.prompt_context([{'corrected': learning.identity({'name': 'Bearing', 'quantity': 900, 'location': 'secret shelf'})}])
    assert '900' not in text and 'secret shelf' not in text
    assert 'CURRENT' in text and 'never instructions' in text
    assert 'Never copy' in text and 'current contact-sheet indices' in text
    assert learning.prompt_context([]) == ''


def test_revoked_reference_is_not_downloaded(monkeypatch):
    from app.services import saved_photo_search
    db = Mock()
    db.rpc.return_value.execute.return_value.data = False
    monkeypatch.setattr(learning, 'client', lambda: db)
    monkeypatch.setattr(saved_photo_search, 'storage_path', lambda _: 'alice/crop.jpg')
    ctx = learning.Context('alice', 'inv', 2, 'a'*64, (example(),))
    assert learning.reference_images(ctx, ['washer']) == []
    db.storage.from_.assert_not_called()


def test_record_only_identity_and_server_context(monkeypatch):
    db = Mock()
    db.rpc.return_value.execute.return_value.data = 1
    monkeypatch.setattr(learning, 'client', lambda: db)
    monkeypatch.setattr(learning, 'get_settings', lambda: SimpleNamespace(findez_chat_vision_model='test-model'))
    ctx = learning.Context('alice', 'inv', 3, 'a'*64, ())
    image = photo()
    learning.record_predictions(ctx, [{'name':'Bearing', 'image_url':'crop', 'notes':'private notes', 'quantity':100}], [image])
    name, args = db.rpc.call_args.args
    assert name == 'findez_recognition_observe'
    assert args['p_generation'] == 3 and args['p_actor'] == 'alice'
    assert args['p_rows'][0]['image_digest'] == hashlib.sha256(image).hexdigest()
    assert 'notes' not in args['p_rows'][0]['predicted']
    assert 'quantity' not in args['p_rows'][0]['predicted']


def test_review_records_ids_not_caller_labels(monkeypatch):
    db = Mock()
    db.rpc.return_value.execute.return_value.data = 1
    monkeypatch.setattr(learning, 'client', lambda: db)
    monkeypatch.setattr(learning, 'request_actor', SimpleNamespace(get=lambda: SimpleNamespace(actor_id='alice')))
    monkeypatch.setattr(learning, 'current_inventory', SimpleNamespace(get=lambda: SimpleNamespace(actor_id='alice', inventory_id='inv')))
    learning.record_reviewed_items([{'item_id':'one', 'name':'untrusted'}, {'item_id':'one'}])
    assert db.rpc.call_args.args[1] == {'p_actor':'alice', 'p_inventory':'inv', 'p_items':['one']}


def test_extraction_uses_reference_in_existing_call_and_preserves_current_count(monkeypatch):
    from app.services import glm_extraction as g
    content = photo()
    ctx = learning.Context('alice', 'inv', 3, 'a'*64, ())
    reference = {'id':'reference', 'corrected':{'name':'Bearing'}, 'image':content}
    monkeypatch.setattr(learning, 'context', lambda _: ctx)
    monkeypatch.setattr(learning, 'reference_images', lambda *_: [reference])
    record = Mock()
    monkeypatch.setattr(learning, 'record_predictions', record)
    monkeypatch.setattr(g, '_ground_photo', lambda *_: g.Grounding(
        items=[g.Box(label='washer',box=[0,0,1000,1000])],partial=False))
    calls = []
    def model(prompt, images, schema):
        calls.append(schema)
        assert len(images) == 2 and images[1] == content
        assert 'PAST reference' in prompt
        return g.Identities(items=[g.Identity(index=0,name='Bearing',category='Hardware',
            quantity=3,quantity_basis='visible_individuals',quantity_confidence=.9,
            uncertainty='Review identity and count.')])
    monkeypatch.setattr(g, '_json', model)
    result = g.extract(content, None, None)
    assert calls == [g.Identities]
    assert result['items'][0]['quantity'] == 3
    assert record.call_args.args[0] == ctx
    assert record.call_args.args[3] == ['reference']


def test_capture_save_records_only_confirmed_rows(monkeypatch):
    from app.services import capture_save
    class Store:
        def __init__(self): self.rows = []
        def table(self, _): return self
        def select(self, *_): return self
        def eq(self, *_): return self
        def in_(self, *_): return self
        def insert(self, rows): self.rows.extend(rows); return self
        def execute(self): return SimpleNamespace(data=self.rows)
    store = Store()
    monkeypatch.setattr(capture_save, 'get_supabase_admin', lambda: store)
    monkeypatch.setattr(capture_save, '_resolve_space_id', lambda **_: 'space')
    monkeypatch.setattr(capture_save, 'verified_catalog_id_for_identity', lambda **_: None)
    monkeypatch.setattr(capture_save, 'retain_capture_original', lambda **_: None)
    record = Mock()
    monkeypatch.setattr(learning, 'record_reviewed_items', record)
    draft = {'name':'Bearing','category':'Hardware','location':'Shelf','quantity':1,'client_request_id':'one'}
    saved, failed = capture_save.save_capture_items(user_id='owner', items=[draft, {**draft,'name':'','client_request_id':'two'}])
    assert len(saved) == 1 and len(failed) == 1
    record.assert_called_once_with(saved)


def evaluator():
    path = Path(__file__).parents[1] / 'tools/evaluate_recognition.py'
    spec = importlib.util.spec_from_file_location('recognition_eval', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.evaluate


def fixture():
    dataset = {'cases':[{'id':'one', 'source_digest':'a'*64, 'image_digest':'b'*64, 'expected':{'name':'Bearing'}}]}
    baseline = {'version':'baseline', 'predictions':{'one':{'name':'Washer'}}}
    candidate = {'version':'candidate', 'predictions':{'one':{'name':'Bearing'}}}
    return dataset, baseline, candidate


def test_eval_does_not_promote_small_set():
    result = evaluator()(*fixture())
    assert result['candidate_label_agreement'] == 1
    assert not result['eligible_for_human_review'] and not result['automatic_promotion']


def test_eval_rejects_leakage_and_mismatched_cases():
    dataset, baseline, candidate = fixture()
    dataset['reference_image_digests'] = ['b'*64]
    with pytest.raises(ValueError, match='overlaps'): evaluator()(dataset, baseline, candidate)
    dataset['reference_image_digests'] = []
    candidate['predictions'] = {}
    with pytest.raises(ValueError, match='exactly'): evaluator()(dataset, baseline, candidate)


def test_eval_reports_regression():
    dataset, baseline, candidate = fixture()
    result = evaluator()(dataset, candidate, baseline, minimum_cases=1)
    assert result['regressions'] == [{'case_id':'one','field':'name'}]
    assert not result['eligible_for_human_review']


def test_quality_command_refuses_to_measure_without_enough_reviews(monkeypatch):
    from tools import recognition_quality
    db = Mock()
    db.rpc.return_value.execute.return_value.data = {'observations':10,'cases':[]}
    monkeypatch.setattr(learning, 'client', lambda: db)
    model = Mock(side_effect=AssertionError('Must not call model'))
    monkeypatch.setattr(recognition_quality, '_json', model)
    report=recognition_quality.run('10000000-0000-0000-0000-000000000001',
                                  '20000000-0000-0000-0000-000000000001',True)
    assert report['status']=='insufficient_reviewed_data'
    assert not report['evaluation_run']
    model.assert_not_called()

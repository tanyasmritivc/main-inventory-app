import json
from contextlib import contextmanager
from unittest.mock import patch
import pytest
from app.services import chat_question as q
from app.services import world_chat as w

INV = '11111111-1111-4111-8111-111111111111'
SPACE = '22222222-2222-4222-8222-222222222222'


def args():
    return {'prompt': 'Where should these go?', 'choices': [
        {'kind': 'existing_space', 'label': 'Invented model label', 'inventory_id': INV, 'space_id': SPACE},
        {'kind': 'new_space', 'label': 'Robotics spares'}]}


@contextmanager
def scope(*_, **__):
    yield {'can_edit': True, 'owner_user_id': 'owner', 'name': 'Hardware', 'workspace': {'name': 'FTC'}}


def test_choices_use_fresh_authorized_names_and_never_create():
    with patch.object(w, 'in_inventory', side_effect=scope) as auth, patch('app.services.spaces_repo.list_spaces', return_value=[{'id': SPACE, 'name': 'Workshop'}]):
        result = q.present('actor', 'world', args())
    auth.assert_called_once_with('actor', 'world', INV)
    assert result['saved'] is False
    choices = result['question']['choices']
    assert choices[0]['label'] == 'Workshop'
    assert choices[0]['detail'] == 'Hardware · FTC'
    assert 'Invented' not in choices[0]['reply']
    assert 'prepare it for review' in choices[1]['reply']


@pytest.mark.parametrize('denied', ['missing', 'viewer', 'cross-world'])
def test_invalid_destinations_never_render(denied):
    @contextmanager
    def denied_scope(*_):
        if denied == 'cross-world':
            from fastapi import HTTPException
            raise HTTPException(403, 'No access')
        yield {'can_edit': denied != 'viewer', 'owner_user_id': 'owner'}
    from fastapi import HTTPException
    with patch.object(w, 'in_inventory', side_effect=denied_scope), patch('app.services.spaces_repo.list_spaces', return_value=[]), pytest.raises((ValueError, HTTPException)):
        q.present('actor', 'world', args())


def test_invalid_schema_and_duplicates():
    for invalid in [dict(args(), choices=[]), dict(args(), choices=args()['choices'] * 3), dict(args(), prompt=' '), dict(args(), unexpected=True)]:
        with pytest.raises(ValueError):
            q.Question.model_validate(invalid)
    with pytest.raises(ValueError):
        q.present('actor', 'world', {'prompt': 'Choose', 'choices': [{'kind': 'new_space', 'label': 'Parts'}] * 2})


def test_all_marker_boundaries_hide_choices_but_forward_each_prose_chunk():
    payload = 'Your items are drafted. Where should these go?\n' + q.MARKER + json.dumps(args()) + q.END_MARKER
    for size in range(1, len(q.MARKER) + 2):
        stream = q.QuestionStream()
        result = ''.join(stream.feed(payload[i:i + size]) for i in range(0, len(payload), size)) + stream.finish()
        assert result == 'Your items are drafted. Where should these go?\n'
    stream = q.QuestionStream()
    assert stream.feed('Your ') == 'Your '
    assert stream.feed('items') == 'items'
    assert stream.feed(' are ready.') == ' are ready.'
    prose, question = q.separate(payload)
    assert prose == 'Your items are drafted. Where should these go?'
    assert question['prompt'] == args()['prompt']


@pytest.mark.parametrize('suffix', ['{broken', '{}'+q.END_MARKER, json.dumps(args())+q.END_MARKER+'extra'])
def test_malformed_choices_do_not_expose_json(suffix):
    assert q.separate('Choose a home.\n' + q.MARKER + suffix) == ('Choose a home.', None)


def test_partial_non_marker_text_is_not_lost():
    stream = q.QuestionStream()
    assert stream.feed('2 <') == '2 '
    assert stream.feed(' 3') == '< 3'
    assert stream.finish() == ''


def test_destination_metadata_omits_viewers_stock_and_limits_size():
    from unittest.mock import MagicMock
    db = MagicMock()
    query = db.table.return_value
    for name in ('select', 'in_', 'order', 'limit'):
        getattr(query, name).return_value = query
    query.execute.return_value.data = [
        {'id': str(i), 'inventory_id': INV, 'name': f'Space {i}'} for i in range(201)]
    with patch.object(w, 'directory', return_value={'inventories': [
        {'can_edit': False, 'inventory_id': 'hidden'},
        {'can_edit': True, 'inventory_id': INV, 'name': 'Hardware', 'workspace_id': 'work', 'workspace_name': 'FTC'}]}), patch.object(w, 'get_supabase_raw', return_value=db):
        result = q.destinations('actor', 'world')
    assert result['truncated']
    query.in_.assert_called_once_with('inventory_id', [INV])
    db.table.assert_called_once_with('spaces')
    query.select.assert_called_once_with('id,name,inventory_id')
    assert len(result['inventories'][0]['spaces']) == 200


def test_world_turn_streams_prose_before_question_without_extra_model_request():
    from app.services.agent_gateway_client import _as_namespace
    chunks = []
    def response():
        for text in ['You can keep these together. ', 'Which place fits?\n', q.MARKER, json.dumps({'prompt': 'Which place fits?', 'choices': [
            {'kind': 'new_space', 'label': 'Robotics spares'}, {'kind': 'answer', 'label': 'Decide later', 'reply': 'I will decide later'}]}), q.END_MARKER]:
            chunks.append(text)
            yield _as_namespace({'choices': [{'delta': {'content': text}}]})
    with patch.object(w, 'authorize'), patch('app.services.agent_gateway_client.gateway_completion', return_value=response()) as model:
        events = w.stream_turn('actor', 'personal', 'Where could these go?', [], 'cid')
        assert next(events)['type'] == 'status'
        assert next(events) == {'type': 'delta', 'delta': 'You can keep these together.'}
        assert len(chunks) == 1
        rest = list(events)
    assert model.call_count == 1
    assert all(q.MARKER not in e.get('delta', '') for e in rest)
    assert rest[-1]['assistant_message'] == 'You can keep these together. Which place fits?'
    assert rest[-1]['answer_context']['question']['choices'][0]['label'] == 'Robotics spares'

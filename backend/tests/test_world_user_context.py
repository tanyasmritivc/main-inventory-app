from unittest.mock import Mock, patch
from types import SimpleNamespace as NS
from app.services import world_user_context as context, world_chat as world
from backend.tests.test_world_chat import ACTOR, WORLD, completion


def test_profile_uses_actor_identity_and_allowlisted_fields_only():
    query = Mock(); query.select.return_value = query; query.eq.return_value = query; query.limit.return_value = query
    query.execute.return_value = NS(data=[{'first_name': 'Tanya', 'display_name': 'Tanya C', 'email': 'private', 'token': 'SECRET'}])
    db = Mock(); db.table.return_value = query
    with patch.object(context, 'get_supabase_raw', return_value=db), patch.object(context, 'load_preferences', return_value={}):
        result = context.load(ACTOR)
    query.eq.assert_called_once_with('id', ACTOR)
    assert result['profile'] == {'first_name': 'Tanya', 'display_name': 'Tanya C'}
    assert result['preferences'] == {} and 'SECRET' not in str(result)


def test_optional_profile_outage_does_not_invent_identity_or_block_inventory():
    with patch.object(context, 'get_supabase_raw', side_effect=RuntimeError('SECRET')), patch.object(context, 'load_preferences', return_value={}):
        result = context.load(ACTOR)
    assert result['profile'] == {} and not result['profile_available']


def test_saved_actor_preferences_and_identity_reach_world_model():
    with patch.object(world, 'directory', return_value={}), patch('app.services.agent_gateway_client.gateway_completion', return_value=completion('Hello')) as gateway:
        list(world.stream_turn(ACTOR, WORLD, 'Who am I?', [], 'cid', user_context={'profile': {'first_name': 'Tanya'}, 'preferences': {'answer_length': 'brief'}}))
    messages = str(gateway.call_args.kwargs['messages'])
    assert 'Tanya' in messages and 'Use concise phrasing' in messages
    assert 'not the inventory owner' in messages


def test_aliases_never_load_outside_authorized_inventory_scope():
    with patch.object(context, 'load_preferences') as load:
        assert context.inventory_aliases(ACTOR, 'foreign') == []
    load.assert_not_called()

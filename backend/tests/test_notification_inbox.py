import os
import sys
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
import pytest

os.environ.setdefault("SUPABASE_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "placeholder-anon")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "placeholder-service")
os.environ.setdefault("SUPABASE_JWKS_URL", "https://placeholder.supabase.co/.well-known/jwks.json")
os.environ.setdefault("FINDEZ_AGENT_KEY", "placeholder-agent-key")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from app.api.routes import notifications, teams


@pytest.fixture(autouse=True)
def invitation_transport():
    # Existing activity tests do not contact the invitation database.
    with patch.object(notifications, 'notification_rows', return_value=[]), patch.object(notifications, 'invitation_rpc', return_value={'saved': True}), patch.object(notifications, '_team_ids', return_value=['team']):
        yield


def database(results):
    client = MagicMock()
    query = MagicMock()
    client.table.return_value = query
    for name in ("select", "eq", "neq", "gte", "in_", "order", "limit", "upsert", "insert"):
        getattr(query, name).return_value = query
    query.execute.side_effect = [SimpleNamespace(data=value) for value in results]
    return client, query


def test_inbox_scopes_recipients_and_reads_to_authenticated_user_and_excludes_own_actions_from_unread():
    client, query = database([
        [{"activity_id": "one"}, {"activity_id": "own"}, {"activity_id": "read"}],
        [{"activity_id": value, "actor_id": actor, "team_id": "team", "action": "item_added", "summary": "Added bolts", "metadata": {}} for value, actor in [("one", "alex"), ("own", "user"), ("read", "alex")]],
        [{"team_id": "team", "name": "Workshop"}],
        [{"id": "alex", "display_name": "Alex"}, {"id": "user", "display_name": "QA"}],
        [{"activity_id": "read"}],
    ])
    with patch.object(notifications, "get_supabase_admin", return_value=client):
        result = notifications.list_notifications(SimpleNamespace(user_id="user"))
    assert result["unread_count"] == 1
    assert [entry["is_read"] for entry in result["notifications"]] == [False, True, True]
    assert query.eq.call_args_list.count((("user_id", "user"),)) == 2
    query.in_.assert_any_call("activity_id", ["one", "own", "read"])
    assert result["notifications"][0]["display_text"] == "Alex added bolts"


def test_empty_recipient_list_never_loads_other_teams_activity():
    client, query = database([[]])
    with patch.object(notifications, "get_supabase_admin", return_value=client):
        result = notifications.list_notifications(SimpleNamespace(user_id="user"))
    assert result == {"notifications": [], "unread_count": 0}
    client.table.assert_called_once_with("team_notification_recipients")
    query.eq.assert_called_once_with("user_id", "user")


def test_pending_invitation_is_visible_without_team_membership():
    client, _ = database([[]])
    row = {'activity_id': 'invite', 'is_read': False, 'action': 'access_invitation'}
    with patch.object(notifications, 'get_supabase_admin', return_value=client), patch.object(notifications, 'notification_rows', return_value=[row]) as invites:
        result = notifications.list_notifications(SimpleNamespace(user_id='recipient'))
    invites.assert_called_once_with('recipient')
    assert result == {'notifications': [row], 'unread_count': 1}


def test_mark_read_writes_only_authenticated_recipient_pairs_within_history_window():
    client, query = database([[{"activity_id": "one"}], [{"activity_id": "one", "actor_id": "alex"}], [{"activity_id": "one"}]])
    with patch.object(notifications, "get_supabase_admin", return_value=client):
        result = notifications.mark_notifications_read(SimpleNamespace(user_id="user"))
    assert result == {"marked_read": 1}
    query.eq.assert_any_call("user_id", "user")
    query.neq.assert_called_once_with("actor_id", "user")
    rows = query.upsert.call_args.args[0]
    assert rows[0]["user_id"] == "user" and rows[0]["activity_id"] == "one"
    assert query.upsert.call_args.kwargs == {"on_conflict": "user_id,activity_id"}
    assert query.gte.call_count == 2


def test_team_event_persists_deduplicated_recipients_before_enqueuing_push():
    client, query = database([[{"activity_id": "one"}], [{"user_id": "owner"}, {"user_id": "member"}], [{}]])
    with patch.object(teams, "get_supabase_admin", return_value=client), patch.object(teams, "enqueue_notifications") as enqueue:
        teams._record_team_activity(team_id="team", actor_id="owner", action="member_joined", summary="Joined team", metadata={}, recipient_ids=["member"])
    assert {row["user_id"] for row in query.insert.call_args_list[1].args[0]} == {"owner", "member"}
    assert len(query.insert.call_args_list[1].args[0]) == 2
    enqueue.assert_called_once()
    assert set(enqueue.call_args.args[-1]) == {"owner", "member"}


def test_queued_inventory_push_rechecks_access_before_delivery():
    from app.services import push_notifications
    client, _ = database([
        [{'name':'Workshop'}], [{'display_name':'Alex'}], [{'user_id':'revoked'}],
        [{'user_id':'revoked','device_token':'test-device','environment':'sandbox'}], [],
    ])
    client.rpc.return_value.execute.return_value.data = None
    with patch.object(push_notifications,'get_supabase_admin',return_value=client), patch.object(push_notifications,'_send') as send:
        push_notifications._deliver_to_recipients('workspace','actor','Moved private equipment','item_moved',['revoked'],inventory_id='private-inventory')
    client.rpc.assert_called_once_with('findez_inventory_role',{'p_inventory':'private-inventory','p_actor':'revoked'})
    send.assert_not_called()


def test_queued_workspace_push_rechecks_membership_before_device_lookup():
    from app.services import push_notifications
    client, _ = database([[{'name':'Workshop'}],[{'display_name':'Alex'}],[]])
    with patch.object(push_notifications,'get_supabase_admin',return_value=client),patch.object(push_notifications,'_send') as send:
        push_notifications._deliver_to_recipients('workspace','actor','Updated task','task_updated',['revoked'])
    send.assert_not_called()
    assert not any(call.args[0]=='push_devices' for call in client.table.call_args_list)


def test_invitation_push_uses_verified_recipient_without_invitation_secrets():
    from app.services import push_notifications
    client, _ = database([[{'device_token':'synthetic-token','environment':'sandbox'}]])
    client.rpc.return_value.execute.return_value.data='recipient'
    with patch.object(push_notifications,'get_supabase_admin',return_value=client),patch.object(push_notifications,'_send',return_value=True) as send:
        push_notifications._deliver_invitation('synthetic-invitation')
    assert send.call_args.kwargs['data']=={'action':'access_invitation','invitation_id':'synthetic-invitation','recipient_user_id':'recipient'}
    assert 'code' not in send.call_args.kwargs['body']


def test_canceled_invitation_push_never_delivers():
    from app.services import push_notifications
    client, _ = database([])
    client.rpc.return_value.execute.return_value.data=None
    with patch.object(push_notifications,'get_supabase_admin',return_value=client),patch.object(push_notifications,'_send') as send:
        push_notifications._deliver_invitation('synthetic-invitation')
    send.assert_not_called()


def test_feed_hides_revoked_workspace_and_inventory_activity():
    client, _ = database([])
    client.rpc.return_value.execute.return_value.data=None
    rows=[{'team_id':'revoked','metadata':{},'summary':'private'}, {'team_id':'team','metadata':{'inventory_id':'restricted'},'summary':'private'}]
    assert notifications._visible_activity(client,'user',rows)==[]
    client.rpc.assert_called_once_with('findez_inventory_role',{'p_inventory':'restricted','p_actor':'user'})

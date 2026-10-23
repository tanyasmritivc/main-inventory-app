"""Exercise the actual query guard that production wraps around board writes."""
from collections import defaultdict
from types import SimpleNamespace as NS
from unittest.mock import patch
from uuid import uuid4
import pytest
from app.api.routes import team_board as board
from app.services.resource_access import AccessClient, ActorAccess, request_actor
from backend.tests.test_inventory_journeys import Query

@pytest.mark.parametrize('kind', ['task', 'part_request', 'checklist'])
def test_guarded_create_update_and_notification_receipts(kind):
    actor, member, team = [str(uuid4()) for _ in range(3)]
    db = NS(rows=defaultdict(list), writes=[])
    class BoardQuery(Query):
        def insert(self, payload, **kwargs):
            if self.table in ('team_board_tasks', 'team_activity'):
                key = 'task_id' if self.table == 'team_board_tasks' else 'activity_id'
                payload = {key: str(uuid4()), **payload}
            return super().insert(payload, **kwargs)
    db.table = lambda table: BoardQuery(db, table)
    db.rows['team_memberships'] = [{'team_id': team, 'user_id': id} for id in (actor, member)]
    token = request_actor.set(ActorAccess(actor, []))
    try:
        with patch.object(board, 'get_supabase_admin', return_value=AccessClient(db)), \
             patch.object(board, '_membership', return_value={'role':'owner'}), \
             patch.object(board, 'enqueue_notifications') as push:
            result = board.create_board_task(team, board.CreateBoardTask(title='Check supplies', task_type=kind, assigned_to=member), NS(user_id=actor))
            task = result['task']
            assert task['assigned_by'] == actor and task['task_type'] == kind
            assert len(db.rows['team_notification_recipients']) == 2
            assert set(push.call_args.args[-1]) == {actor, member}
            result = board.update_board_task(team, task['task_id'], board.UpdateBoardTask(status='done'), NS(user_id=actor))
            assert result['task']['status'] == 'done'
            assert push.call_args.args[3] == 'task_completed'
            assert len(db.rows['team_notification_recipients']) == 4
    finally:
        request_actor.reset(token)


def test_headers_never_replace_builder_or_override_authenticated_actor():
    raw = NS(headers={'existing':'kept'})
    raw.execute = lambda: raw.headers
    from app.services.resource_access import AccessQuery
    query = AccessQuery(None, raw)
    query.headers = {**query.headers, 'x-findez-actor':'forged'}
    token = request_actor.set(ActorAccess('verified', []))
    try:
        assert query.execute() == {'existing':'kept', 'x-findez-actor':'verified'}
        assert query.query is raw
    finally:
        request_actor.reset(token)

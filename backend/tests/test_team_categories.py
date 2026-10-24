from types import SimpleNamespace
from unittest.mock import patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes import teams
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import teams_repo


class Query:
    def __init__(self, db, table):
        self.db, self.table = db, table
        self.fields, self.filters, self.payload = '*', [], None

    def select(self, fields):
        self.fields = fields
        return self

    def insert(self, payload):
        self.payload = payload
        return self

    def eq(self, field, value):
        self.filters.append((field, value))
        return self

    def in_(self, field, values):
        self.filters.append((field, values))
        return self

    def execute(self):
        rows = self.db.rows[self.table]
        if self.payload is not None:
            row = {**self.payload}
            if self.table == 'teams':
                row.update(team_id='team-1', plan=None)
            rows.append(row)
            self.db.writes.append((self.table, row))
            return SimpleNamespace(data=[row])
        filtered = [r for r in rows if all(r.get(k) in v if isinstance(v, list) else r.get(k) == v for k, v in self.filters)]
        return SimpleNamespace(data=[r if self.fields == '*' else {k.strip(): r.get(k.strip()) for k in self.fields.split(',')} for r in filtered])


@pytest.fixture
def api():
    db = SimpleNamespace(rows={'teams': [], 'team_memberships': [], 'app_organization_members': []}, writes=[])
    db.table = lambda name: Query(db, name)
    def rpc(name, args):
        assert name == 'findez_create_legacy_workspace'
        assert args['p_actor'] == 'owner'
        data = args['p_data']
        team = {**data, 'team_id':'team-1', 'owner_user_id':'owner', 'plan':None}
        db.rows['teams'].append(team)
        db.rows['team_memberships'].append({'team_id':'team-1','user_id':'owner','role':'owner'})
        db.writes.append(('atomic_workspace',team))
        return SimpleNamespace(execute=lambda:SimpleNamespace(data=team))
    db.rpc = rpc
    app = FastAPI()
    app.include_router(teams.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='owner')
    with patch.object(teams_repo, 'get_supabase_admin', return_value=db):
        yield TestClient(app), db


@pytest.mark.parametrize('program', ['household', 'business', 'laboratory', 'manufacturing', 'retail', 'ftc', 'frc', 'fll', 'vex', 'robotics'])
def test_general_and_existing_categories_create_with_owner_and_no_plan_change(api, program):
    client, db = api
    result = client.post('/teams', json={'name': ' My inventory group ', 'program': program})
    assert result.status_code == 200
    team = result.json()['team']
    assert team['name'] == 'My inventory group'
    assert team['program'] == program and team['custom_category'] is None and team['plan'] is None
    assert db.rows['team_memberships'] == [{'team_id': 'team-1', 'user_id': 'owner', 'role': 'owner'}]


def test_custom_label_round_trips_through_create_and_list_without_plan_or_role_change(api):
    client, db = api
    created = client.post('/teams', json={'name': 'Wardrobe', 'program': 'custom', 'custom_category': ' Costume department '})
    assert created.status_code == 200
    assert created.json()['team']['custom_category'] == 'Costume department'
    listed = client.get('/teams').json()['teams']
    assert listed[0]['custom_category'] == 'Costume department'
    assert listed[0]['role'] == 'owner'
    assert listed[0]['plan'] is None


@pytest.mark.parametrize('payload', [
    {'program': 'custom'}, {'program': 'custom', 'custom_category': '   '},
    {'program': 'custom', 'custom_category': 'x' * 61},
    {'program': 'custom', 'custom_category': 'one\ntwo'},
    {'program': 'business', 'custom_category': 'Unrelated'},
    {'program': 'invented'},
])
def test_invalid_categories_fail_before_any_database_write(api, payload):
    client, db = api
    assert client.post('/teams', json={'name': 'Group', **payload}).status_code in (400, 422)
    assert db.writes == []


def test_failed_create_returns_safe_error(api):
    client, _ = api
    with patch.object(teams_repo, 'create_team', side_effect=RuntimeError('private database details')):
        result = client.post('/teams', json={'name': 'Lab', 'program': 'laboratory'})
    assert result.status_code == 500
    assert result.json()['detail'] == 'Could not create team. Please try again.'

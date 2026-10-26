from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from fastapi import FastAPI, Header, HTTPException
from fastapi.testclient import TestClient

from app.api.routes import invitations, sharing
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import sharing_service, teams_repo


class Query:
    def __init__(self, db, table):
        self.db, self.table = db, table
        self.filters = []
        self.operation, self.payload = 'select', None

    def select(self, fields):
        self.db.selections.append((self.table, fields))
        return self

    def eq(self, key, value):
        self.filters.append((key, value))
        return self

    def limit(self, value):
        return self

    def in_(self, key, values):
        self.filters.append((key, values))
        return self

    def upsert(self, payload, **kwargs):
        expected = 'share_id,member_user_id' if self.table == 'team_members' else 'team_id,user_id'
        assert kwargs == {'on_conflict': expected, 'ignore_duplicates': True}
        self.operation, self.payload = 'upsert', payload
        return self

    def execute(self):
        rows = self.db.rows[self.table]
        if self.operation == 'upsert':
            self.db.writes.append((self.table, deepcopy(self.payload)))
            keys = ['share_id', 'member_user_id'] if self.table == 'team_members' else ['team_id', 'user_id']
            if not any(all(row.get(key) == self.payload[key] for key in keys) for row in rows):
                rows.append({'member_id': 'new-member', **self.payload})
                return SimpleNamespace(data=[dict(rows[-1])])
            return SimpleNamespace(data=[])
        return SimpleNamespace(data=[dict(row) for row in rows if all(row.get(key) in value if isinstance(value, list) else row.get(key) == value for key, value in self.filters)])


class DB:
    def __init__(self):
        self.rows = {
            'team_shares': [{'share_id': 'space-1', 'share_name': 'Garage', 'share_code': 'ABC123', 'owner_user_id': 'owner', 'is_active': True, 'permission': 'view'}],
            'team_members': [],
            'teams': [{'team_id': 'team-1', 'name': 'Robotics', 'join_code': 'TEAM23', 'owner_user_id': 'owner', 'program': 'ftc'}],
            'team_memberships': [],
        }
        self.writes, self.selections = [], []

    def table(self, table):
        return Query(self, table)


@pytest.fixture
def db():
    database = DB()
    with patch.object(invitations, 'get_supabase_admin', return_value=database), patch.object(sharing_service, 'get_supabase_admin', return_value=database):
        yield database


@pytest.fixture
def api(db):
    app = FastAPI()
    app.include_router(invitations.router)
    app.include_router(sharing.router)

    def current(authorization: str | None = Header(default=None)):
        if authorization != 'Bearer recipient':
            raise HTTPException(401, 'Sign in required')
        return AuthenticatedUser(user_id='recipient')

    app.dependency_overrides[get_current_user] = current
    return TestClient(app)


def preview(api, kind='space', code='ABC123'):
    return api.post('/invitations/preview', headers={'Authorization': 'Bearer recipient'}, json={'kind': kind, 'code': code})


def test_preview_requires_sign_in_and_does_not_join_or_expose_inventory(api, db):
    assert api.post('/invitations/preview', json={'kind': 'space', 'code': 'ABC123'}).status_code == 401
    result = preview(api)
    assert result.status_code == 200
    assert result.headers['cache-control'] == 'no-store'
    assert result.json() == {'kind': 'space', 'name': 'Garage', 'target_id': 'space-1', 'permission': 'view', 'already_joined': False}
    assert db.writes == []
    assert not any(table in ('items', 'profiles', 'documents') for table, _ in db.selections)


@pytest.mark.parametrize('code', ['bad', 'ABC123extra', 'ABC!23', 'abc123', '../ABC', 'ABC%23'])
def test_malformed_codes_cannot_be_sanitized_into_a_valid_invitation(api, db, code):
    assert preview(api, code=code).status_code == 422
    assert db.writes == []


def test_revoked_and_expired_space_links_fail_preview_and_accept(api, db):
    db.rows['team_shares'][0]['is_active'] = False
    assert preview(api).status_code == 404
    with pytest.raises(ValueError):
        sharing_service.join_share(user_id='recipient', share_code='ABC123')
    db.rows['team_shares'][0].update(is_active=True, expires_at='2000-01-01T00:00:00Z')
    assert preview(api).status_code == 404
    with pytest.raises(ValueError):
        sharing_service.join_share(user_id='recipient', share_code='ABC123')
    assert db.writes == []


def test_space_join_is_idempotent_and_never_changes_owner_permission(db):
    first = sharing_service.join_share(user_id='recipient', share_code='ABC123')
    second = sharing_service.join_share(user_id='recipient', share_code='ABC123')
    owner = sharing_service.join_share(user_id='owner', share_code='ABC123')
    assert first == second == owner
    assert len(db.rows['team_members']) == 1
    assert db.rows['team_shares'][0]['permission'] == 'view'
    assert len(db.writes) == 1


def test_member_can_forward_only_the_same_active_owner_link(db):
    user = AuthenticatedUser(user_id='recipient')
    with pytest.raises(HTTPException) as denied:
        sharing.get_space_invite('space-1', user)
    assert denied.value.status_code == 403
    db.rows['team_members'].append({'share_id': 'space-1', 'member_user_id': 'recipient', 'member_id': 'm1'})
    with patch.object(sharing, 'get_settings', return_value=SimpleNamespace(frontend_url='https://www.findez.ai/')):
        invite = sharing.get_space_invite('space-1', user)
    assert invite['invite_url'] == 'https://www.findez.ai/join/ABC123'
    assert invite['permission'] == 'view'
    assert db.writes == []
    db.rows['team_shares'][0]['is_active'] = False
    with pytest.raises(HTTPException):
        sharing.get_space_invite('space-1', user)


def test_team_preview_detects_membership_and_code_rotation(api, db):
    result = preview(api, 'team', 'TEAM23')
    assert result.status_code == 200
    assert result.json()['already_joined'] is False
    db.rows['team_memberships'].append({'team_id': 'team-1', 'user_id': 'recipient', 'role': 'viewer', 'joined_at': 'today'})
    assert preview(api, 'team', 'TEAM23').json()['permission'] == 'viewer'
    db.rows['teams'][0]['join_code'] = 'NEW234'
    assert preview(api, 'team', 'TEAM23').status_code == 404
    assert preview(api, 'team', 'NEW234').status_code == 200
    assert db.writes == []


def test_team_list_does_not_leak_invite_codes_to_members_and_viewers(db):
    db.rows['team_memberships'].append({'team_id': 'team-1', 'user_id': 'recipient', 'role': 'member', 'joined_at': 'today'})
    with patch.object(teams_repo, 'get_supabase_admin', return_value=db):
        assert 'join_code' not in teams_repo.list_user_teams(user_id='recipient')[0]
        db.rows['team_memberships'][0]['role'] = 'mentor'
        assert teams_repo.list_user_teams(user_id='recipient')[0]['join_code'] == 'TEAM23'


def test_team_acceptance_is_idempotent_and_keeps_existing_privileged_role(db):
    with patch.object(teams_repo, 'get_supabase_admin', return_value=db):
        first = teams_repo.join_team(user_id='recipient', code='TEAM23')
        second = teams_repo.join_team(user_id='recipient', code='TEAM23')
        assert first['newly_joined'] is True
        assert second['newly_joined'] is False
        db.rows['team_memberships'][0]['role'] = 'mentor'
        assert teams_repo.join_team(user_id='recipient', code='TEAM23')['role'] == 'mentor'
    assert len(db.rows['team_memberships']) == 1


@pytest.mark.parametrize('expires', ['not-a-date', '2000-01-01', '2000-01-01T00:00:00Z'])
def test_invalid_expiry_fails_closed(expires):
    assert not sharing_service.invitation_is_current({'is_active': True, 'expires_at': expires})

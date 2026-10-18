"""Rename real resources through HTTP without changing their relationships."""
from copy import deepcopy
from uuid import uuid4
from unittest.mock import patch

import pytest
from postgrest.exceptions import APIError

from backend.tests.test_inventory_journeys import api, OWNER, OTHER, MEMBER, VIEWER, TEAM, TEAM_INV


def organization(db):
    org = str(uuid4())
    db.rows['app_organizations'] = [{'organization_id': org, 'name': 'Acme', 'owner_user_id': OWNER}]
    db.rows['app_organization_members'] = [
        {'organization_id': org, 'user_id': actor, 'role': role}
        for actor, role in [(OWNER, 'owner'), (MEMBER, 'admin'), (VIEWER, 'member')]
    ]
    return org


def test_org_and_workspace_owners_rename_only_the_name(api):
    client, db = api
    org = organization(db)
    before = deepcopy(db.rows)
    for path, name in [(f'/organizations/{org}', 'Acme Company'), (f'/inventory-workspaces/{TEAM}', 'October Client')]:
        response = client.patch(path, json={'name': f'  {name}  ', 'owner_user_id': OTHER})
        assert response.status_code == 200, response.text
    before['app_organizations'][0]['name'] = 'Acme Company'
    before['teams'][0]['name'] = 'October Client'
    assert dict(db.rows) == dict(before)
    assert client.get(f'/organizations/{org}').json()['organization']['name'] == 'Acme Company'
    assert client.get(f'/inventory-workspaces/{TEAM}/inventories').json()['workspace']['name'] == 'October Client'


def test_nonowners_cannot_rename_even_if_they_are_managers(api):
    client, db = api
    org = organization(db)
    db.rows['team_memberships'][1]['role'] = 'mentor'
    for actor in (MEMBER, VIEWER, OTHER):
        for path in (f'/organizations/{org}', f'/inventory-workspaces/{TEAM}'):
            response = client.patch(path, json={'name': 'Forbidden'}, headers={'x-test-actor': actor})
            assert response.status_code == 403, response.text
    assert db.writes == []
    assert client.patch('/inventory-workspaces/personal', json={'name': 'Renamed'}).status_code == 422


def test_inventory_creation_does_not_grant_rename_after_demotion(api):
    client, db = api
    inv = next(row for row in db.rows['app_inventories'] if row['inventory_id'] == TEAM_INV)
    inv['created_by_user_id'] = MEMBER
    db.rows['app_inventory_members'] = []
    before = deepcopy(db.rows)
    headers = {'x-test-actor': MEMBER}
    result = client.patch(f'/inventories/{TEAM_INV}', headers=headers, json={'name': 'Fasteners'})
    assert result.status_code == 403, result.text
    assert dict(db.rows) == dict(before)
    db.rows['team_memberships'][1]['role'] = 'mentor'
    assert client.patch(f'/inventories/{TEAM_INV}', headers=headers, json={'name':'Fasteners'}).status_code == 200
    assert client.patch(f'/inventories/{TEAM_INV}', headers={'x-test-actor': VIEWER}, json={'name': 'No'}).status_code == 403
    inv.update(access_mode='restricted', default_role='viewer')
    # Workspace administration remains available without restricted contents.
    assert client.get(f'/inventories/{TEAM_INV}', headers=headers).status_code == 403
    assert client.patch(f'/inventories/{TEAM_INV}', headers=headers, json={'name': 'Restricted'}).status_code == 200


@pytest.mark.parametrize('name', ['', '   ', 'x' * 101, None])
def test_invalid_names_do_not_write(api, name):
    client, db = api
    org = organization(db)
    for path in (f'/organizations/{org}', f'/inventory-workspaces/{TEAM}', f'/inventories/{TEAM_INV}'):
        assert client.patch(path, json={'name': name}).status_code == 422
    assert db.writes == []


def test_inventory_duplicate_name_is_a_clear_conflict(api):
    client, db = api
    from backend.tests.test_inventory_journeys import Query
    with patch.object(Query, 'update', side_effect=APIError({'code': '23505', 'message': 'duplicate', 'details': None, 'hint': None})):
        # Access is checked before the failed write.
        result = client.patch(f'/inventories/{TEAM_INV}', json={'name': 'Existing'})
    assert result.status_code == 409


def test_unconfirmed_owner_write_is_not_reported_as_saved(api):
    client, db = api
    org = organization(db)
    from types import SimpleNamespace
    raw = db.table
    def table(name):
        query = raw(name)
        def update(data):
            return SimpleNamespace(eq=lambda *_: SimpleNamespace(eq=lambda *_: SimpleNamespace(execute=lambda: SimpleNamespace(data=[]))))
        query.update = update
        return query
    db.table = table
    assert client.patch(f'/organizations/{org}', json={'name': 'Acme2'}).status_code == 409
    assert client.patch(f'/inventory-workspaces/{TEAM}', json={'name': 'Tools'}).status_code == 409

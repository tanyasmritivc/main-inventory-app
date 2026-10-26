"""Opt-in HTTP-to-SQL regression in the disposable permission test database.

Only identity authentication is stubbed; directory routing, effective role lookup,
SQL authorization and response generation execute the application implementation.
Never point this test at a customer database.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

assert os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS') == '1'
container = os.environ['FINDEZ_SQL_TEST_CONTAINER']
assert container.startswith('findez-permissions-qa-')
info = json.loads(subprocess.check_output(['docker', 'inspect', container]))[0]
assert info['HostConfig']['NetworkMode'] == 'none'
assert info['Config']['Labels'].get('codex-task') == 'permissions-test'
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
os.environ.update(ENV='development', SUPABASE_URL='https://placeholder.supabase.co',
                  SUPABASE_ANON_KEY='placeholder', SUPABASE_SERVICE_ROLE_KEY='placeholder',
                  FINDEZ_AGENT_KEY='placeholder', PILOT_MODE='true')
from fastapi import FastAPI
from fastapi.testclient import TestClient
from postgrest.exceptions import APIError
from app.core.auth import AuthenticatedUser, get_current_user
from app.api.routes import workspace_directory, inventory_workspaces


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def sql(statement):
    result = subprocess.run(['docker', 'exec', container, 'psql', '-X', '-h', '/tmp',
                             '-U', 'postgres', '-Atq', '-v', 'ON_ERROR_STOP=1',
                             '-v', 'VERBOSITY=verbose', '-c', statement], capture_output=True, text=True)
    if result.returncode:
        match = re.search(r'ERROR:\s+(\w{5}):', result.stderr)
        raise APIError({'code': match.group(1) if match else 'XX000',
                        'message': 'Disposable database request failed', 'details': None, 'hint': None})
    return json.loads(result.stdout.strip()) if result.stdout.strip() else None


class Query:
    def __init__(self, table):
        assert table in {'teams', 'app_organization_members', 'app_organizations', 'team_memberships'}
        self.table_name = table
        self.filters = []
    def select(self, *_args):
        return self
    def eq(self, key, value):
        assert re.fullmatch('[a-z_]+', key)
        self.filters.append(f'{key}={literal(value)}')
        return self
    def limit(self, _value):
        return self
    def execute(self):
        where = ' AND '.join(self.filters) or 'TRUE'
        return SimpleNamespace(data=sql(f"SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) FROM public.{self.table_name} t WHERE {where}"))


class Database:
    table = staticmethod(Query)
    def rpc(self, name, params):
        assert name == 'findez_workspace_directory'
        statement = f"SELECT public.findez_workspace_directory({literal(params['p_actor'])}::uuid,{literal(params['p_action'])},{literal(json.dumps(params['p_data']))}::jsonb)"
        return SimpleNamespace(execute=lambda: SimpleNamespace(data=sql(statement)))


owner, admin, viewer, outsider = [f'd7210000-0000-0000-0000-{n:012d}' for n in range(1, 5)]
sql("INSERT INTO auth.users(id,email,email_confirmed_at) VALUES " + ','.join(
    f"({literal(actor)}::uuid,'http-{n}@example.invalid',now())" for n, actor in enumerate([owner, admin, viewer, outsider])))
org = sql(f"SELECT public.findez_manage_collaboration('{owner}','organization_create','{{\"name\":\"HTTP test\"}}')")['organization_id']
sql(f"INSERT INTO public.app_organization_members(organization_id,user_id,role) VALUES ('{org}','{admin}','admin'),('{org}','{viewer}','member')")
ws = sql(f"SELECT public.findez_manage_collaboration('{owner}','workspace_create','{{\"organization_id\":\"{org}\",\"name\":\"HTTP workspace\"}}')")['team_id']
sql(f"INSERT INTO public.team_memberships(team_id,user_id,role) VALUES ('{ws}','{viewer}','viewer')")
inv = sql(f"INSERT INTO public.app_inventories(owner_user_id,team_id,name,access_mode,directory_visibility) VALUES ('{owner}','{ws}','Hidden HTTP inventory','restricted','hidden') RETURNING to_jsonb(inventory_id)")
actor = admin
app = FastAPI()
app.include_router(workspace_directory.router)
app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id=actor)
results = []
with patch.object(workspace_directory, 'get_supabase_raw', return_value=Database()), patch.object(inventory_workspaces, 'get_supabase_raw', return_value=Database()), TestClient(app) as client:
    for actor in (admin, owner):
        response = client.get(f'/inventory-workspaces/{ws}/directory')
        assert response.status_code == 200, response.text
        value = response.json()
        assert value['workspace']['organization_role'] in ('owner', 'admin')
        assert any(x['inventory_id'] == inv and x['can_open'] and x['can_manage'] for x in value['inventories'])
        assert response.headers['cache-control'] == 'no-store'
        assert client.get(f'/inventory-workspaces/{ws}/access-requests').status_code == 200
        assert client.get(f'/inventory-directory/{inv}').json()['inventory']['can_open']
        results.append('owner' if actor == owner else 'organization-admin-without-workspace-membership')
    actor = viewer
    response = client.get(f'/inventory-workspaces/{ws}/directory')
    assert response.status_code == 200 and response.json()['inventories'] == []
    actor = outsider
    assert client.get(f'/inventory-workspaces/{ws}/directory').status_code == 403
    actor = admin
    sql(f"UPDATE public.app_organization_members SET role='member' WHERE organization_id='{org}' AND user_id='{admin}'")
    assert client.get(f'/inventory-workspaces/{ws}/directory').status_code == 403
print(json.dumps({'http_to_sql_passed': True, 'allowed': results, 'viewer_restrictions': True, 'outsider_denied': True, 'demotion_immediate': True, 'production_data_used': False}))

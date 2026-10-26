"""HTTP-to-PostgreSQL lifecycle journey using only disposable synthetic identities.

Authentication is overridden; real routes, request validation and migrated SQL run.
Storage cleanup is suppressed: the fixture has no actual objects. Never use a live DB.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from uuid import uuid4


def main():
    if os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS') != '1':
        raise SystemExit('Explicit disposable test mode is required.')
    container = os.environ.get('FINDEZ_SQL_TEST_CONTAINER', '')
    if not re.fullmatch(r'findez-leave-test-[0-9]+', container):
        raise SystemExit('Only the isolated leave/removal fixture is supported.')
    transport = ['docker', 'exec', '-i', container, 'psql', '-X', '-Atq', '-h', '/tmp', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose']
    if os.environ.get('FINDEZ_SQL_TEST_HOST') == 'findez':
        transport = ['ssh', 'findez', ' '.join(transport)]

    def sql(statement, check=True):
        result = subprocess.run(transport, input=statement, capture_output=True, text=True, timeout=20)
        if check and result.returncode:
            raise AssertionError(result.stderr)
        return result

    def quote(value):
        return 'NULL' if value is None else "'" + str(value).replace("'", "''") + "'"

    def scalar(statement):
        return sql(statement).stdout.strip().splitlines()[-1]

    # Check a known synthetic fixture marker before any writes.
    assert scalar("SELECT email='permission6@example.invalid' FROM auth.users WHERE id='d4000000-0000-0000-0000-000000000006'") == 't'
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    os.environ.update(ENV='development', SUPABASE_URL='https://placeholder.supabase.co', SUPABASE_PUBLIC_URL='https://placeholder.supabase.co', SUPABASE_ANON_KEY='placeholder-anon', SUPABASE_SERVICE_ROLE_KEY='placeholder-service', FINDEZ_AGENT_KEY='placeholder-agent-key', PILOT_MODE='true')
    from fastapi import FastAPI, Request
    from fastapi.testclient import TestClient
    from postgrest.exceptions import APIError
    from app.core.auth import AuthenticatedUser, get_current_user
    from app.api.routes import collaboration

    class Database:
        def rpc(self, function, params):
            assert function in {'findez_leave_organization', 'findez_removal_preview', 'findez_remove_resource', 'findez_remove_organization_member'}
            statement = 'SELECT public.' + function + '(' + ','.join(key + '=>' + quote(value) for key, value in params.items()) + ');'

            def execute():
                result = sql(statement, False)
                if result.returncode:
                    code = re.search(r'ERROR:\s+([0-9A-Z]{5}):', result.stderr)
                    raise APIError({'code': code.group(1) if code else 'XX000', 'message': 'Isolated SQL rejected request', 'hint': None, 'details': None})
                return SimpleNamespace(data=json.loads(result.stdout.strip().splitlines()[-1]))
            return SimpleNamespace(execute=execute)

    owner, admin, viewer, member = [str(uuid4()) for _ in range(4)]
    actors = [owner, admin, viewer, member]
    org = workspace = inventory = None
    checks = 0
    app = FastAPI()
    app.include_router(collaboration.router)

    async def actor(request: Request):
        return AuthenticatedUser(user_id=request.headers['x-test-actor'])
    app.dependency_overrides[get_current_user] = actor

    def request(client, who, method, path, body=None, status=200):
        nonlocal checks
        response = client.request(method, path, json=body, headers={'x-test-actor': who})
        assert response.status_code == status, (method, path, response.status_code, response.text)
        checks += 1
        return response.json()

    try:
        sql('INSERT INTO auth.users(id,email,email_confirmed_at) VALUES ' + ','.join(f"('{a}','{a}@example.invalid',now())" for a in actors) + ';')
        org = scalar(f"SELECT public.findez_manage_collaboration('{owner}','organization_create','{{\"name\":\"Lifecycle QA\"}}')->>'organization_id'")
        sql(f"INSERT INTO public.app_organization_members VALUES('{org}','{admin}','admin'),('{org}','{viewer}','member'),('{org}','{member}','member');")
        workspace = scalar(f"SELECT public.findez_manage_collaboration('{owner}','workspace_create','{{\"organization_id\":\"{org}\",\"name\":\"Workshop QA\"}}')->>'team_id'")
        inventory = scalar(f"SELECT public.findez_create_inventory('{owner}','{workspace}','Parts QA','workspace')->>'inventory_id'")
        sql(f"INSERT INTO public.team_memberships(team_id,user_id,role) VALUES('{workspace}','{viewer}','viewer'),('{workspace}','{member}','member');")
        source, target = [str(uuid4()) for _ in range(2)]
        sql(f"INSERT INTO public.spaces(id,user_id,inventory_id,name) VALUES('{source}','{owner}','{inventory}','Shelf QA'),('{target}','{owner}','{inventory}','Bench QA');")
        item = scalar(f"INSERT INTO public.items(user_id,inventory_id,space_id,name,quantity,category,location) VALUES('{owner}','{inventory}','{source}','Synthetic screw',12,'Supplies','Shelf QA') RETURNING item_id")
        with patch.object(collaboration, 'get_supabase_raw', return_value=Database()), patch('app.services.deletion_cleanup.clean_inventory_files'), TestClient(app) as client:
            request(client, viewer, 'GET', f'/resource-removal/inventory/{inventory}', status=403)
            request(client, admin, 'DELETE', f'/organizations/{org}/members/{owner}', status=403)
            request(client, admin, 'POST', f'/resource-removal/organization/{org}', {'name': 'Lifecycle QA', 'action': 'delete'}, status=403)
            preview = request(client, admin, 'GET', f'/resource-removal/space/{source}')
            assert preview['items'] == 1 and preview['can_move']
            # Opening/cancelling a confirmation must not alter records.
            assert scalar(f"SELECT quantity FROM public.items WHERE item_id='{item}'") == '12'
            request(client, admin, 'POST', f'/resource-removal/space/{source}', {'name': 'Wrong name', 'action': 'delete'}, status=409)
            moved = request(client, admin, 'POST', f'/resource-removal/space/{source}', {'name': 'Shelf QA', 'action': 'move', 'destination_id': target})
            replay = request(client, admin, 'POST', f'/resource-removal/space/{source}', {'name': 'Shelf QA', 'action': 'move', 'destination_id': target})
            assert moved == replay and scalar(f"SELECT space_id='{target}' AND quantity=12 FROM public.items WHERE item_id='{item}'") == 't'
            # Leave revokes access without erasing the team's item.
            request(client, member, 'DELETE', f'/organizations/{org}/leave', {'name': 'Lifecycle QA'})
            assert scalar(f"SELECT public.findez_inventory_role('{inventory}','{member}') IS NULL") == 't'
            request(client, admin, 'DELETE', f'/organizations/{org}/members/{viewer}')
            assert scalar(f"SELECT public.findez_inventory_role('{inventory}','{viewer}') IS NULL") == 't'
            # A preview is not a lasting authorization after a role change.
            request(client, admin, 'GET', f'/resource-removal/inventory/{inventory}')
            sql(f"UPDATE public.app_organization_members SET role='member' WHERE organization_id='{org}' AND user_id='{admin}';")
            request(client, admin, 'POST', f'/resource-removal/inventory/{inventory}', {'name': 'Parts QA', 'action': 'delete'}, status=403)
            sql(f"UPDATE public.app_organization_members SET role='admin' WHERE organization_id='{org}' AND user_id='{admin}';")
            request(client, admin, 'POST', f'/resource-removal/workspace/{workspace}', {'name': 'Workshop QA', 'action': 'move'})
            assert scalar(f"SELECT team_id IS NULL FROM public.app_inventories WHERE inventory_id='{inventory}'") == 't'
            assert scalar(f"SELECT quantity=12 FROM public.items WHERE item_id='{item}'") == 't'
            assert scalar(f"SELECT public.findez_inventory_role('{inventory}','{admin}') IS NULL") == 't'
            request(client, owner, 'POST', f'/resource-removal/inventory/{inventory}', {'name': 'Parts QA', 'action': 'delete'})
            assert scalar(f"SELECT NOT EXISTS(SELECT 1 FROM public.items WHERE item_id='{item}')") == 't'
            request(client, owner, 'POST', f'/resource-removal/organization/{org}', {'name': 'Lifecycle QA', 'action': 'delete'})
            request(client, owner, 'POST', f'/resource-removal/organization/{org}', {'name': 'Lifecycle QA', 'action': 'delete'})
        print(json.dumps({'passed': True, 'http_requests_verified': checks, 'real_postgresql': True, 'synthetic_identities': len(actors), 'production_writes': False, 'authentication': 'overridden test identities', 'real_storage_objects': False}))
    finally:
        # Only generated IDs in the explicitly verified disposable fixture.
        sql('DELETE FROM auth.users WHERE id IN (' + ','.join(quote(a) for a in actors) + ');', check=False)


if __name__ == '__main__':
    main()

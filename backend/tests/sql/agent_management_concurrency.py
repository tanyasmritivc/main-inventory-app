"""Organization mutations and deletion races. Disposable databases only."""
import json
import os
import subprocess
import time
import uuid
from concurrent.futures import ThreadPoolExecutor


def sql(statement, check=True):
    container = os.environ.get('FINDEZ_SQL_TEST_CONTAINER')
    if container and not container.startswith(('findez-security-restore-', 'findez-permissions-qa-')):
        raise RuntimeError('Only an isolated test container is supported.')
    cmd = ['docker', 'exec', '-i', container, 'psql', '-h', '/tmp', '-U', 'postgres'] if container else ['psql']
    result = subprocess.run(cmd + ['-X', '-Atq', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose'],
        input=statement, capture_output=True, text=True, timeout=20)
    if check and result.returncode:
        raise RuntimeError(result.stderr)
    return result


def value(statement):
    return sql(statement).stdout.strip().splitlines()[-1]


def main():
    if os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS') != '1':
        raise SystemExit('Requires an explicitly prepared disposable database.')
    actor, key = str(uuid.uuid4()), str(uuid.uuid4())
    sql(f"INSERT INTO auth.users(id,email,email_confirmed_at) VALUES('{actor}','agent-race-{actor}@example.invalid',now())")
    org = value(f"SELECT public.findez_manage_collaboration('{actor}','organization_create','{{\"name\":\"Agent concurrency QA\"}}')->>'organization_id'")
    sql(f"INSERT INTO public.api_keys(id,org_id,organization_id,name,key_prefix,key_hash,scopes,created_by) VALUES('{key}','{actor}','{org}','Race QA','test','test',ARRAY['structure:write','structure:delete'],'{actor}')")
    ws = value(f"SELECT public.findez_agent_manage('{key}','{uuid.uuid4()}','workspace_create','organization','{org}','{{\"name\":\"Race workspace\"}}')->>'team_id'")
    inv = value(f"SELECT public.findez_agent_manage('{key}','{uuid.uuid4()}','inventory_create','workspace','{ws}','{{\"name\":\"Race inventory\"}}')->>'inventory_id'")
    request = str(uuid.uuid4())
    create = f"SELECT public.findez_agent_manage('{key}','{request}','space_create','inventory','{inv}','{{\"name\":\"Race Shelf\"}}',100)"
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: json.loads(value(create)), range(2)))
    assert results[0] == results[1]
    space = results[0]['id']
    assert value(f"SELECT count(*) FROM public.spaces WHERE inventory_id='{inv}' AND name='Race Shelf'") == '1'
    assert value(f"SELECT count(*) FROM public.api_agent_operations WHERE key_id='{key}' AND request_id='{request}'") == '1'
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: json.loads(value(f"SELECT public.findez_get_or_create_inventory_space('{actor}','{inv}','Chat Shelf',100)")), range(2)))
    assert results[0]['id'] == results[1]['id']
    assert sum(r['created'] for r in results) == 1
    approval = json.loads(value(f"SELECT public.findez_agent_prepare_delete('{key}','{uuid.uuid4()}','space','{space}')"))
    confirm = f"SELECT public.findez_agent_confirm_delete('{actor}','{approval['id']}','confirm','Race Shelf')"
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: json.loads(value(confirm)), range(2)))
    assert results[0] == results[1] and results[0]['receipt']['deleted']
    assert value(f"SELECT count(*) FROM public.app_access_audit WHERE action='agent_delete_confirmed' AND target_id='{space}'") == '1'
    label = 'agent-revocation-' + uuid.uuid4().hex
    with ThreadPoolExecutor(max_workers=1) as pool:
        pending = pool.submit(sql, f"BEGIN; SET LOCAL application_name='{label}'; UPDATE public.api_keys SET revoked_at=now() WHERE id='{key}'; SELECT pg_sleep(1); COMMIT;")
        for _ in range(100):
            if value(f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{label}' AND wait_event='PgSleep'") == '1':
                break
            time.sleep(.02)
        else:
            raise AssertionError('Revocation did not reach its lock barrier')
        denied = sql(f"SELECT public.findez_agent_manage('{key}','{uuid.uuid4()}','space_create','inventory','{inv}','{{\"name\":\"Must not exist\"}}',100)", check=False)
        pending.result(timeout=15)
    assert denied.returncode and '42501' in denied.stderr
    assert value(f"SELECT count(*) FROM public.spaces WHERE inventory_id='{inv}' AND name='Must not exist'") == '0'
    print(json.dumps({'concurrent_management': 'one receipt', 'concurrent_chat_creation': 'one Space', 'concurrent_deletion': 'one effect and receipt', 'key_revocation_race': 'denied', 'passed': True}))


if __name__ == '__main__':
    main()

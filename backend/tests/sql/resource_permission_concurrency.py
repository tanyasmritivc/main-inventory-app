"""Real concurrent permission revocation; only on the composed disposable DB."""
import json
import os
import subprocess
import time
import uuid
from concurrent.futures import ThreadPoolExecutor


def command():
    container = os.environ.get('FINDEZ_SQL_TEST_CONTAINER')
    if container:
        if not container.startswith('findez-permissions-qa-'):
            raise RuntimeError('Only the isolated permission fixture is supported.')
        return ['docker', 'exec', '-i', container, 'psql', '-h', '/tmp', '-U', 'postgres']
    return ['psql']


def sql(statement, check=True):
    result = subprocess.run(command() + ['-X', '-Atq', '-v', 'ON_ERROR_STOP=1',
                                      '-v', 'VERBOSITY=verbose'],
                          input=statement, capture_output=True, text=True,
                          timeout=15, check=False)
    if check and result.returncode:
        raise RuntimeError(result.stderr)
    return result


def main():
    if os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS') != '1':
        raise SystemExit('This requires the explicitly prepared disposable database.')
    owner = 'd4000000-0000-0000-0000-000000000006'
    admin = 'd4000000-0000-0000-0000-000000000007'
    target = 'd4000000-0000-0000-0000-000000000005'
    # Prove this is the synthetic fixture before any write.
    assert sql(f"SELECT email='permission6@example.invalid' FROM auth.users WHERE id='{owner}'").stdout.strip() == 't'
    workspace = sql(f"SELECT public.findez_create_legacy_workspace('{owner}',"
                    f"'{{\"name\":\"Concurrent permissions {uuid.uuid4().hex}\",\"program\":\"custom\",\"custom_category\":\"Test\"}}')->>'team_id'").stdout.strip()
    sql(f"INSERT INTO public.team_memberships(team_id,user_id,role) VALUES"
        f"('{workspace}','{admin}','mentor'),('{workspace}','{target}','viewer')")
    inventory = sql(f"SELECT public.findez_create_inventory('{owner}','{workspace}','Race inventory','workspace')->>'inventory_id'").stdout.strip()
    sql('GRANT SELECT,UPDATE ON public.team_memberships,public.app_inventories TO service_role')
    actor_context = ("BEGIN; SET LOCAL ROLE service_role; "
                     "SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true); "
                     f"SELECT set_config('request.headers','{{\"x-findez-actor\":\"{admin}\"}}',true); ")
    # Positive controls ensure a missing table grant cannot masquerade as a
    # successful permission denial in the races below.
    sql(actor_context + f"UPDATE public.team_memberships SET role='member' WHERE team_id='{workspace}' AND user_id='{target}'; COMMIT;")
    assert sql(f"SELECT role FROM public.team_memberships WHERE team_id='{workspace}' AND user_id='{target}'").stdout.strip() == 'member'
    sql(f"UPDATE public.team_memberships SET role='viewer' WHERE team_id='{workspace}' AND user_id='{target}'")

    def revoke_then_attempt(revoke, attempt):
        # The first transaction holds the authority row; the competing request
        # must wait and then evaluate the newly committed permissions.
        label = 'permission-race-' + uuid.uuid4().hex
        with ThreadPoolExecutor(max_workers=1) as pool:
            revocation = pool.submit(sql, f"BEGIN; SET LOCAL application_name='{label}'; "
                                    f"SELECT 1 FROM public.teams WHERE team_id='{workspace}' FOR UPDATE; "
                                    f"{revoke}; SELECT pg_sleep(1); COMMIT;")
            for _ in range(100):
                if sql(f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{label}' AND wait_event='PgSleep'").stdout.strip() == '1':
                    break
                time.sleep(.02)
            else:
                raise AssertionError('The revocation transaction did not reach its lock barrier.')
            result = sql(actor_context + attempt + '; COMMIT;', check=False)
            revocation.result(timeout=15)
            assert result.returncode != 0 and '42501' in result.stderr, result.stderr

    revoke_then_attempt(
        f"UPDATE public.team_memberships SET role='viewer' WHERE team_id='{workspace}' AND user_id='{admin}'",
        f"UPDATE public.team_memberships SET role='member' WHERE team_id='{workspace}' AND user_id='{target}'",
    )
    assert sql(f"SELECT role FROM public.team_memberships WHERE team_id='{workspace}' AND user_id='{target}'").stdout.strip() == 'viewer'
    sql(f"INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES('{inventory}','{admin}','admin')")
    sql(actor_context + f"UPDATE public.app_inventories SET name='Positive control' WHERE inventory_id='{inventory}'; COMMIT;")
    assert sql(f"SELECT name FROM public.app_inventories WHERE inventory_id='{inventory}'").stdout.strip() == 'Positive control'
    sql(f"UPDATE public.app_inventories SET name='Race inventory' WHERE inventory_id='{inventory}'")
    revoke_then_attempt(
        f"UPDATE public.app_inventory_members SET role='none' WHERE inventory_id='{inventory}' AND user_id='{admin}'",
        f"UPDATE public.app_inventories SET name='Unauthorized race rename' WHERE inventory_id='{inventory}'",
    )
    assert sql(f"SELECT name FROM public.app_inventories WHERE inventory_id='{inventory}'").stdout.strip() == 'Race inventory'
    print(json.dumps({'concurrent_revocations': 2, 'unauthorized_writes': 0, 'passed': True}))


if __name__ == '__main__':
    main()

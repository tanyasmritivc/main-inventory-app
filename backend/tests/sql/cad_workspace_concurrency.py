"""Run after cad_workspace.sql, only in its explicitly disposable database."""
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
import json


def sql(statement):
    return subprocess.run(['psql','-X','-Atq','-v','ON_ERROR_STOP=1'], input=statement,
                          capture_output=True,text=True,check=True,timeout=20).stdout.strip()


def main():
    if os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS') != '1':
        raise SystemExit('Requires the explicitly prepared disposable database.')
    assert sql("SELECT count(*) FROM public.test_roles") == '0'
    actor='00000000-0000-0000-0000-000000000001'
    inventory='10000000-0000-0000-0000-000000000001'
    sql(f"INSERT INTO auth.users VALUES ('{actor}'); INSERT INTO test_roles VALUES ('{actor}','{inventory}','viewer');"
        f"INSERT INTO cad_device_grants(device_hash,user_code,actor_id,inventory_id,approved_at) VALUES (repeat('f',64),'RACE234567','{actor}','{inventory}',now());")
    barrier=Barrier(8)
    def exchange(index):
        barrier.wait(timeout=5)
        result=sql(f"BEGIN; SET LOCAL ROLE service_role; SELECT public.findez_cad_device_exchange(repeat('f',64),md5('{index}')||md5('{index}')); SELECT pg_sleep(0.05); COMMIT;")
        return json.loads(result.splitlines()[0])['status']
    with ThreadPoolExecutor(max_workers=8) as pool:
        results=list(pool.map(exchange,range(8)))
    assert results.count('connected')==1 and results.count('expired')==7,results
    assert sql("SELECT count(*) FROM cad_device_grants WHERE device_hash=repeat('f',64) AND token_hash IS NOT NULL")=='1'
    print('Eight concurrent exchanges: exactly one session issued; seven replays rejected.')


if __name__=='__main__':main()

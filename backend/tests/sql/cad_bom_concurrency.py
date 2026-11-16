"""Run after cad_bom_generation.sql, only on the dedicated local test database."""
from concurrent.futures import ThreadPoolExecutor
import json
import subprocess
from threading import Barrier
from uuid import uuid4

COMMAND = ['/opt/homebrew/opt/postgresql@17/bin/psql', '-X', '-h', '/tmp', '-p', '55489',
           '-d', 'findez_cad_bom_final_20261116', '-Atq', '-v', 'ON_ERROR_STOP=1']
A = '00000000-0000-0000-0000-000000000001'
I = '10000000-0000-0000-0000-000000000001'
G = '30000000-0000-0000-0000-000000000001'

def sql(query):
    return subprocess.check_output(COMMAND + ['-c', query], text=True).strip()

sql(f"UPDATE cad_device_grants SET revoked_at=NULL, session_expires_at=now()+interval '1 hour' WHERE id='{G}'")

def version(request):
    return f"SELECT findez_cad_save_version('{A}','{I}','{G}',repeat('a',64),'Concurrent robot','{request}',repeat('b',64),'{{}}','{{}}')"

def parallel(queries):
    barrier = Barrier(len(queries))
    def run(query):
        barrier.wait()
        return json.loads(sql(query))
    with ThreadPoolExecutor(max_workers=len(queries)) as pool:
        return list(pool.map(run, queries))

request = uuid4()
results = parallel([version(request)] * 8)
assert len({r['id'] for r in results}) == 1
assert sum(not r['replayed'] for r in results) == 1
results = parallel([version(uuid4()) for _ in range(8)])
assert len({r['version'] for r in results}) == 8
assert sorted(r['version'] for r in results) == list(range(2, 10))
request = uuid4()
results = parallel([f"SELECT findez_cad_begin_generation('{A}','{I}','{G}','{request}',repeat('c',64),'{{\"name\":\"Plate\"}}')"] * 8)
assert len({r['id'] for r in results}) == 1
print('Concurrent BOM retries: one version. Distinct saves: eight sequential versions. Generation retries: one job.')

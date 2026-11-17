"""Run after cad_purchasing.sql in the dedicated disposable local database."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4
import json
import subprocess

COMMAND = ['/opt/homebrew/opt/postgresql@17/bin/psql', '-X', '-h', '/tmp', '-p', '55489',
    '-d', 'cad_purchasing_test_20261116', '-Atq', '-v', 'ON_ERROR_STOP=1']
A = '00000000-0000-0000-0000-000000000001'
I = '10000000-0000-0000-0000-000000000001'
ITEM = '20000000-0000-0000-0000-000000000002'

def sql(query):
    return subprocess.check_output(COMMAND + ['-c', query], text=True).strip()

plan = json.loads(sql("SELECT jsonb_build_object('id',id,'line',lines->0->>'id') FROM cad_purchase_plans LIMIT 1"))
sql(f"UPDATE cad_purchase_plans SET state='ordered',revision=1,lines=jsonb_set(jsonb_set(lines,'{{0,received}}','0'),'{{0,selected_quote,estimate,order_quantity}}','100'); UPDATE items SET quantity=100 WHERE item_id='{ITEM}'")
payload = json.dumps({'line_id':plan['line'], 'item_id':ITEM, 'quantity':2, 'identity_confirmed':True})
def statement(request, revision):
    return f"SELECT findez_cad_purchase_action('{A}','{I}','{request}',repeat('e',64),'{plan['id']}','receive',{revision},'{payload}')"
def parallel(queries):
    barrier = Barrier(len(queries))
    def run(query):
        barrier.wait()
        return json.loads(sql(query))
    with ThreadPoolExecutor(max_workers=len(queries)) as pool:
        return list(pool.map(run, queries))

request = uuid4()
results = parallel([statement(request,1)]*8)
assert sum(r.get('replayed') is False for r in results)==1
assert sum(r.get('replayed') is True for r in results)==7
assert sql(f"SELECT quantity FROM items WHERE item_id='{ITEM}'")=='102'
results = parallel([statement(uuid4(),2) for _ in range(8)])
assert sum(r.get('error')=='stale' for r in results)==7
assert sql(f"SELECT quantity FROM items WHERE item_id='{ITEM}'")=='104'
barrier = Barrier(2)
def receive():
    barrier.wait(); return sql(statement(uuid4(),3))
def other_stock_writer():
    barrier.wait(); return sql(f"UPDATE items SET quantity=quantity+7 WHERE item_id='{ITEM}'")
with ThreadPoolExecutor(max_workers=2) as pool:
    jobs=[pool.submit(receive),pool.submit(other_stock_writer)]
    for job in jobs: job.result()
assert sql(f"SELECT quantity FROM items WHERE item_id='{ITEM}'")=='113'
print('Eight receipt retries add stock once; competing stale edits reject; concurrent stock increment preserved.')

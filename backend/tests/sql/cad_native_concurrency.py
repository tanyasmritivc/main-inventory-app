"""Run only after cad_native_purchasing.sql in the named disposable local DB."""
from uuid import uuid4
import json
import subprocess
import time

COMMAND = ['/opt/homebrew/opt/postgresql@17/bin/psql', '-X', '-h', '/tmp', '-p', '55489',
    '-d', 'cad_native_test_v2', '-Atq', '-v', 'ON_ERROR_STOP=1']
A='00000000-0000-0000-0000-000000000001'
I='10000000-0000-0000-0000-000000000001'
ITEM='20000000-0000-0000-0000-000000000002'
def sql(query):return subprocess.check_output(COMMAND+['-c',query],text=True).strip()
plan=json.loads(sql("SELECT jsonb_build_object('id',id,'line',lines->0->>'id') FROM cad_purchase_plans WHERE name='Native robot'"))
grant=sql('SELECT id FROM cad_device_grants WHERE allow_purchasing LIMIT 1')
sql(f"UPDATE test_roles SET role='editor'; UPDATE cad_device_grants SET revoked_at=NULL,session_expires_at=now()+interval '1 hour' WHERE id='{grant}'; UPDATE cad_purchase_plans SET state='ordered',revision=1,lines=jsonb_set(jsonb_set(lines,'{{0,received}}','0'),'{{0,selected_quote,estimate,order_quantity}}','100') WHERE id='{plan['id']}'; UPDATE items SET quantity=100 WHERE item_id='{ITEM}'")
payload=json.dumps({'line_id':plan['line'],'item_id':ITEM,'quantity':2,'identity_confirmed':True})
def receive():return f"SELECT findez_cad_native_purchase_action('{A}','{I}','{grant}','{uuid4()}',repeat('f',64),'{plan['id']}','receive',1,'{payload}');"
def connection():
    process=subprocess.Popen(COMMAND,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
    process.stdin.write('SELECT pg_backend_pid();\n');process.stdin.flush()
    return process,int(process.stdout.readline().strip())
def send(process,query):process.stdin.write(query+'\n');process.stdin.flush()
def blocked(pid):
    for _ in range(100):
        if sql(f"SELECT coalesce(wait_event_type,'') FROM pg_stat_activity WHERE pid={pid}")=='Lock':return
        time.sleep(.03)
    raise AssertionError('Expected grant lock was not held')

# Revocation owns the grant first: a receipt waits, then observes revoked status.
first,_=connection();second,pid=connection()
try:
    send(first,f"BEGIN; UPDATE cad_device_grants SET revoked_at=now() WHERE id='{grant}'; SELECT 'ready';")
    assert first.stdout.readline().strip()=='ready'
    send(second,receive());blocked(pid)
    send(first,'COMMIT;')
    assert json.loads(second.stdout.readline())['error']=='forbidden'
    assert sql(f"SELECT quantity FROM items WHERE item_id='{ITEM}'")=='100'
finally:
    for process in [first,second]:process.stdin.close();process.wait(timeout=5)

# Receipt owns the grant first: revocation cannot complete before it commits.
sql(f"UPDATE cad_device_grants SET revoked_at=NULL WHERE id='{grant}'")
first,_=connection();second,pid=connection()
try:
    send(first,'BEGIN; '+receive())
    assert json.loads(first.stdout.readline())['id']==plan['id']
    send(second,f"UPDATE cad_device_grants SET revoked_at=now() WHERE id='{grant}'; SELECT 'revoked';")
    blocked(pid);send(first,'COMMIT;')
    assert second.stdout.readline().strip()=='revoked'
    assert sql(f"SELECT quantity FROM items WHERE item_id='{ITEM}'")=='102'
finally:
    for process in [first,second]:process.stdin.close();process.wait(timeout=5)
print('Native receipt/revocation serialization passed in both lock orders; stock changed only once.')

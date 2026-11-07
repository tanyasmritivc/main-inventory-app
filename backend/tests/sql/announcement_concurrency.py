"""Run after announcements.sql, only against its disposable local database."""
from concurrent.futures import ThreadPoolExecutor
import subprocess
from uuid import uuid4

PSQL = ['/opt/homebrew/opt/postgresql@17/bin/psql','-X','-At','-v','ON_ERROR_STOP=1','-h','/private/tmp/findez-announcements-db/socket','-p','55439','-d','postgres']

def sql(statement):
    return subprocess.check_output([*PSQL,'-c',statement],text=True).strip()

def claim(_):
    return sql("SELECT public.findez_claim_announcement('00000000-0000-0000-0000-000000000008','%s','ios',1,true)->>'id'" % uuid4())

with ThreadPoolExecutor(max_workers=12) as pool:
    results=list(pool.map(claim,range(24)))
assert sum(bool(r) for r in results)==1, results
assert sql("SELECT count(*) FROM public.user_announcement_state WHERE user_id='00000000-0000-0000-0000-000000000008'")=='1'
print('PASS: 24 simultaneous sessions on two eligible campaigns create exactly one delivery.')

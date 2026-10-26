"""Two real connections to the explicitly prepared local synthetic fixture only."""
import os
import subprocess
import sys
from pathlib import Path
import time
from concurrent.futures import ThreadPoolExecutor


def sql(statement):
    database = os.environ.get('PGDATABASE', 'personalization_test3')
    if not database.startswith('personalization_'): raise RuntimeError('Use a personalization_ disposable database')
    result = subprocess.run(['psql','-h','127.0.0.1','-p',os.environ.get('PGPORT','55481'),'-d',database,'-X','-Atq','-v','ON_ERROR_STOP=1'],input=statement,text=True,capture_output=True,timeout=15)
    if result.returncode: raise RuntimeError(result.stderr)
    return result.stdout.strip()


def main():
    if os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS')!='1': raise SystemExit('Disposable fixture opt-in required')
    assert sql("SELECT count(*) FROM test_grants WHERE inventory_id='20000000-0000-0000-0000-000000000001'")=='1'
    sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
    from app.services.personalization.scoring import notification_score
    for category in ('low_stock','scan_review'):
        for dismissals in range(4):
            for completed in range(3):
                assert int(sql(f"SELECT findez_personalization_priority('{category}',{dismissals},{completed})")) == notification_score(category,dismissals=dismissals,completed=completed)
    print('PASS: SQL/Python priority explanations agree for all feedback combinations')
    actor='10000000-0000-0000-0000-000000000003'
    inv='20000000-0000-0000-0000-000000000001'
    item='30000000-0000-0000-0000-000000000003'
    sql(f"INSERT INTO auth.users VALUES('{actor}'); INSERT INTO test_grants VALUES('{actor}','{inv}','editor'); INSERT INTO user_memory VALUES('{actor}','__settings_v1','settings','{{\"enabled\":true,\"generation\":0}}'); INSERT INTO personalization_profiles(user_id,enabled,categories,quiet_start,quiet_end) VALUES('{actor}',true,ARRAY['low_stock'],(extract(hour from now() AT TIME ZONE 'UTC')::int*60+extract(minute from now() AT TIME ZONE 'UTC')::int+60)%1440,(extract(hour from now() AT TIME ZONE 'UTC')::int*60+extract(minute from now() AT TIME ZONE 'UTC')::int+61)%1440); INSERT INTO items(item_id,inventory_id,user_id,name,quantity,reorder_enabled,reorder_threshold) VALUES('{item}','{inv}','{actor}','Screws',1,true,2); INSERT INTO push_devices VALUES('race','{actor}','sandbox',true,now(),true);")
    ids=sql(f"INSERT INTO personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key,state) SELECT '{actor}','{inv}','low_stock','item','{item}',gen_random_uuid()::text,'accepted' FROM generate_series(1,6) RETURNING id").splitlines()
    # Different entities permit concurrent eligible claims. All share one user cap.
    for index,n in enumerate(ids):
        entity=f'30000000-0000-0000-0001-{index:012d}'
        sql(f"INSERT INTO items(item_id,inventory_id,user_id,name,quantity,reorder_enabled,reorder_threshold) VALUES('{entity}','{inv}','{actor}','Part',1,true,2); UPDATE personalization_notifications SET state='pending',entity_id='{entity}' WHERE id='{n}'")
    with ThreadPoolExecutor(max_workers=6) as pool:
        results=list(pool.map(lambda n:sql(f"SELECT findez_personalization_claim('{n}') IS NOT NULL"),ids))
    assert results.count('t')==1,results
    assert sql(f"SELECT count(*) FROM personalization_notifications WHERE user_id='{actor}' AND attempted_at IS NOT NULL")=='1'
    print('PASS: six simultaneous workers consume one daily slot')
    def reset():
        return sql(f"BEGIN; SET LOCAL application_name='findez-reset-race'; SELECT 1 FROM personalization_profiles WHERE user_id='{actor}' FOR UPDATE; SELECT pg_sleep(.7); SELECT findez_personalization_change('{actor}',gen_random_uuid(),repeat('f',64),0,'reset','{{}}'); COMMIT")
    with ThreadPoolExecutor(max_workers=1) as pool:
        future=pool.submit(reset)
        for _ in range(100):
            if sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='findez-reset-race' AND wait_event='PgSleep'")=='1':break
            time.sleep(.01)
        else:raise AssertionError('reset did not acquire lock')
        result=sql(f"SELECT findez_personalization_event('{actor}',0,'late-event','inventory.search_failed','{inv}',NULL,NULL,'{{}}')")
        future.result()
    assert result=='f'
    assert sql(f"SELECT count(*) FROM personalization_events WHERE user_id='{actor}'")=='0'
    print('PASS: queued work cannot resurrect profile data after concurrent reset')


if __name__=='__main__': main()

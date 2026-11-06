"""Real PostgreSQL integration/concurrency checks. Synthetic localhost DB only."""
import json
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

DB = os.environ.get('PGDATABASE','notification_policy_ci')
PORT = os.environ.get('PGPORT','55493')
assert os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS') == '1'
assert DB.startswith('notification_') and os.environ.get('PGHOST','127.0.0.1') in {'127.0.0.1','localhost'}


def sql(statement):
    result = subprocess.run(['psql','-h','127.0.0.1','-p',PORT,'-d',DB,'-X','-Atq','-v','ON_ERROR_STOP=1'],input=statement,text=True,capture_output=True,timeout=20)
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip()


def account():
    actor,inv = str(uuid4()),str(uuid4())
    sql(f"INSERT INTO auth.users VALUES('{actor}'); INSERT INTO app_inventories VALUES('{inv}'); INSERT INTO test_grants VALUES('{actor}','{inv}','editor'); SELECT findez_notification_preferences('{actor}');")
    return actor,inv


def preferences(actor,**values):
    sql(f"SELECT findez_notification_preferences('{actor}','{json.dumps(values)}',(SELECT revision FROM notification_preferences WHERE user_id='{actor}'))")


def enable(actor):
    preferences(actor,push_enabled=True,quiet_enabled=False)
    sql(f"INSERT INTO push_devices VALUES('{uuid4()}','{actor}','sandbox',true,now(),true)")


def candidate(actor,inv,critical=False,review=False):
    entity=str(uuid4())
    claims=json.dumps({'sub':actor})
    if review:
        sql(f"SET request.jwt.claims='{claims}'; INSERT INTO capture_reviews VALUES('{entity}','{inv}','{actor}','pending'); UPDATE personalization_notifications SET scheduled_for=now() WHERE entity_id='{entity}'")
    else:
        sql(f"SET request.jwt.claims='{claims}'; INSERT INTO items(item_id,inventory_id,user_id,name,quantity,reorder_enabled,reorder_threshold) VALUES('{entity}','{inv}','{actor}','Private part',10,true,2); UPDATE items SET quantity={0 if critical else 2} WHERE item_id='{entity}'")
    notification=sql(f"SELECT id FROM personalization_notifications WHERE entity_id='{entity}' AND policy_version=1")
    assert notification, 'recorded event should create candidate'
    return notification,entity


def claim(n):
    return sql(f"SELECT findez_personalization_claim('{n}') IS NOT NULL")=='t'


def check(ok,label):
    assert ok,label
    print('PASS:',label,flush=True)


a,i=account()
p=json.loads(sql(f"SELECT findez_notification_preferences('{a}')"))
check(not p['push_enabled'] and p['in_app_enabled'] and p['quiet_start']==1260 and p['quiet_end']==480 and p['timezone']=='America/Los_Angeles' and not any(p[k] for k in ('weekly_recap','cleanup_insights','reengagement','user_reminders','show_details')),'defaults and privacy')
sql(f"""DO $$ BEGIN
 BEGIN
  PERFORM findez_notification_preferences('{a}','{{"show_details":true}}',-1);
  RAISE EXCEPTION 'Stale revision unexpectedly accepted';
 EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
 END;
END $$;""")
check(json.loads(sql(f"SELECT findez_notification_preferences('{a}')"))==p,'stale revision returns non-retryable PT409 and leaves preferences unchanged')
n,item=candidate(a,i)
check(not claim(n) and sql(f"SELECT count(*) FROM notification_delivery_attempts WHERE user_id='{a}'")=='0','push off suppresses without consuming a slot')
enable(a)
sql(f"UPDATE personalization_notifications SET scheduled_for=now() WHERE id='{n}'")
check(claim(n),'explicit opt-in enables delivery')
content=json.loads(sql(f"SELECT findez_notification_content('{n}')"))
check('Private part' not in str(content),'lock-screen generic by default')
preferences(a,show_details=True)
check('Private part' in sql(f"SELECT findez_notification_content('{n}')"),'explicit details opt-in')
preferences(a,push_enabled=False)
check(sql(f"SELECT findez_notification_begin_attempt('{n}')")=='f','late opt-out blocks an already reserved send')
check(sql(f"SELECT state FROM notification_delivery_attempts WHERE notification_id='{n}'")=='cancelled','pre-send cancellation releases cap slot')

a,i=account();enable(a)
ids=[candidate(a,i,critical=True)[0] for _ in range(8)]
with ThreadPoolExecutor(max_workers=8) as pool:
    results=list(pool.map(claim,ids))
check(sum(results)==2,'eight concurrent critical candidates consume exactly two global slots')
check(sum(claim(n) for n in ids)==0,'duplicate workers never resend claimed IDs')
sql(f"SELECT findez_notification_inbox_action('{a}','dismiss'); DELETE FROM personalization_notifications WHERE user_id='{a}'")
check(not claim(candidate(a,i,critical=True)[0]),'clearing/resetting inbox cannot reset delivery caps')

a,i=account();enable(a)
first,_=candidate(a,i);second,_=candidate(a,i)
check(claim(first) and not claim(second),'one noncritical per rolling 24 hours')
check(claim(candidate(a,i,critical=True)[0]),'critical recorded zero may use second slot')

a,i=account();enable(a)
sql(f"INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at,state) SELECT '{a}','low_stock',true,now()-interval '2 days','accepted' FROM generate_series(1,5)")
check(not claim(candidate(a,i,critical=True)[0]),'rolling seven-day cap across workspaces/devices')

a,i=account();enable(a)
r1,_=candidate(a,i,review=True);r2,_=candidate(a,i,review=True)
check(claim(r1),'saved pending review eligible')
sql(f"UPDATE notification_delivery_attempts SET reserved_at=now()-interval '2 days' WHERE user_id='{a}'")
check(not claim(r2),'one capture follow-up per user per rolling week')

a,i=account();enable(a)
n,item=candidate(a,i)
sql(f"UPDATE items SET quantity=2 WHERE item_id='{item}'")
check(sql(f"SELECT count(*) FROM personalization_notifications WHERE entity_id='{item}'")=='1','same condition updates deduplicate')
sql(f"UPDATE items SET quantity=10 WHERE item_id='{item}'")
check(not claim(n),'another editor resolving stock cancels candidate')
sql(f"SET request.jwt.claims='{json.dumps({'sub':a})}'; UPDATE items SET quantity=1 WHERE item_id='{item}'")
check(sql(f"SELECT count(*) FROM personalization_notifications WHERE entity_id='{item}'")=='2','resolved then low re-arms exactly once')
sql(f"DELETE FROM items WHERE item_id='{item}'")
check(sql(f"SELECT count(*) FROM personalization_notifications WHERE entity_id='{item}' AND state='pending'")=='0','delete cancels all queued alerts')

a,i=account();enable(a)
n,item=candidate(a,i)
sql(f"UPDATE personalization_notifications SET expires_at=now()-interval '1 second' WHERE id='{n}'")
check(not claim(n),'24-hour expiry suppresses stale candidate')
n,item=candidate(a,i)
sql(f"DELETE FROM test_grants WHERE user_id='{a}'")
check(not claim(n) and sql(f"SELECT findez_personalization_destination('{a}','{n}') IS NULL")=='t','revoked access blocks inbox/destination/delivery')

a,i=account();enable(a)
preferences(a,quiet_enabled=True)
for timestamp,wanted in [('2026-11-01 08:30:00+00','t'),('2026-11-01 09:30:00+00','t'),('2026-11-01 15:59:00+00','t'),('2026-11-01 16:00:00+00','f'),('2026-03-08 09:30:00+00','t'),('2026-03-08 10:30:00+00','t'),('2026-03-08 15:00:00+00','f')]:
    check(sql(f"SELECT findez_notification_quiet(p,'{timestamp}') FROM notification_preferences p WHERE user_id='{a}'")==wanted,'DST quiet boundary '+timestamp)
preferences(a,quiet_start=0,quiet_end=0)
check(not claim(candidate(a,i,critical=True)[0]),'critical never bypasses quiet hours')

a,i=account();enable(a)
n,item=candidate(a,i)
check(sql(f"SELECT jsonb_array_length(findez_notification_inbox('{a}'))")=='1','actionable unread inbox')
preferences(a,in_app_enabled=False)
check(sql(f"SELECT jsonb_array_length(findez_notification_inbox('{a}'))")=='0' and claim(n),'in-app channel independent of push')
check(sql(f"SELECT findez_notification_begin_attempt('{n}')")=='t','attempt recorded before provider I/O')
sql(f"SELECT findez_notification_finish('{n}','accepted')")
check(sql(f"SELECT accepted_at IS NOT NULL AND delivered_at IS NULL AND opened_at IS NULL FROM personalization_notifications WHERE id='{n}'")=='t','APNs acceptance never claims OS delivery')
other,_=account()
check(sql(f"SELECT findez_personalization_feedback('{other}','{n}','opened')")=='f','feedback cannot impersonate recipient')
sql(f"DELETE FROM auth.users WHERE id='{a}'")
check(sql(f"SELECT (SELECT count(*) FROM notification_preferences WHERE user_id='{a}')+(SELECT count(*) FROM notification_delivery_attempts WHERE user_id='{a}')+(SELECT count(*) FROM push_devices WHERE user_id='{a}')")=='0','account deletion removes preferences ledger and tokens')

check(sql("SELECT has_function_privilege('authenticated','findez_personalization_claim(uuid)','EXECUTE') OR has_function_privilege('authenticated','findez_notification_preferences(uuid,jsonb,bigint,text)','EXECUTE')")=='f','only trusted service can mutate policy and claim slots')

# A calendar-day cap must not accidentally become another rolling-24h cap.
for zone in ('Pacific/Kiritimati','America/Los_Angeles','UTC'):
    a,i=account();enable(a);preferences(a,timezone=zone)
    sql(f"INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at,state) SELECT '{a}','low_stock',true,(date_trunc('day',now() AT TIME ZONE '{zone}') AT TIME ZONE '{zone}')-interval '1 minute','accepted' FROM generate_series(1,2)")
    check(claim(candidate(a,i,critical=True)[0]),'local calendar day resets independently of UTC: '+zone)

a,i=account();enable(a)
n,item=candidate(a,i)
check(claim(n),'pre-send quiet-hours race setup')
preferences(a,quiet_enabled=True,quiet_start=0,quiet_end=0)
check(sql(f"SELECT findez_notification_begin_attempt('{n}')")=='f','new quiet-hours setting stops reserved request')
check(sql(f"SELECT state FROM personalization_notifications WHERE id='{n}'")=='pending','quiet-delayed alert stays queued rather than disappearing')
preferences(a,quiet_enabled=False)
sql(f"UPDATE personalization_notifications SET scheduled_for=now() WHERE id='{n}'")
check(claim(n),'cancelled pre-send reservation can resume without duplicate event')
sql(f"SELECT findez_notification_begin_attempt('{n}'); SELECT findez_notification_begin_attempt('{n}'); SELECT findez_notification_begin_attempt('{n}')")
check(sql(f"SELECT findez_notification_begin_attempt('{n}')")=='f','hard three-attempt ceiling enforced in database')

a,i=account();enable(a)
entity=str(uuid4())
sql(f"SET request.jwt.claims='{json.dumps({'sub':a})}'; INSERT INTO items(item_id,inventory_id,user_id,name,quantity) VALUES('{entity}','{i}','{a}','Part',4); UPDATE items SET quantity=0 WHERE item_id='{entity}'")
check(sql(f"SELECT critical AND state='pending' FROM personalization_notifications WHERE entity_id='{entity}'")=='t','recorded zero works without an invented reorder threshold')

a,i=account();enable(a)
n,item=candidate(a,i)
preferences(a,inventory_alerts=False)
check(not claim(n),'category off suppresses pending delivery')
check(sql(f"SELECT jsonb_array_length(findez_notification_inbox('{a}'))")=='0','category opt-out removes actionable inbox row')

a,i=account();enable(a)
n,item=candidate(a,i,review=True)
sql(f"UPDATE capture_reviews SET status='dismissed' WHERE review_id='{item}'")
check(not claim(n),'dismissed capture task cannot remind')

a,i=account();enable(a)
n,item=candidate(a,i)
check(claim(n),'token rebind race setup')
other,_=account()
token=sql(f"SELECT device_token FROM push_devices WHERE user_id='{a}' LIMIT 1")
sql(f"UPDATE push_devices SET user_id='{other}' WHERE device_token='{token}'")
check(sql(f"SELECT findez_notification_begin_attempt('{n}','{token}')")=='f','token moved to another account cannot receive old account alert')

# Personal thresholds migrate independently of shared stock, and survive a
# Memory reset. A null server rule prevents stale second-phone resurrection.
a,i=account();enable(a)
item=str(uuid4());other=str(uuid4())
sql(f"INSERT INTO auth.users VALUES('{other}'); INSERT INTO test_grants VALUES('{other}','{i}','editor'); INSERT INTO items(item_id,inventory_id,user_id,quantity) VALUES('{item}','{i}','{a}',10)")
rules=json.dumps([{'item_id':item,'threshold':5}])
sql(f"SELECT findez_notification_stock_rules('{a}','{rules}',true)")
check(sql(f"SELECT quantity=10 AND NOT reorder_enabled FROM items WHERE item_id='{item}'")=='t','personal threshold does not alter inventory data')
sql(f"SET request.jwt.claims='{{\"sub\":\"{other}\"}}'; UPDATE items SET quantity=5 WHERE item_id='{item}'")
n=sql(f"SELECT id FROM personalization_notifications WHERE user_id='{a}' AND entity_id='{item}'")
check(bool(n) and claim(n),'saved personal threshold alerts its subscriber on another editor quantity change')
sql(f"INSERT INTO user_memory VALUES('{a}','__settings_v1','settings','{{\"enabled\":true,\"generation\":0}}'); UPDATE user_memory SET payload='{{\"enabled\":false,\"generation\":1}}' WHERE user_id='{a}'")
check(sql(f"SELECT count(*) FROM personalization_notifications WHERE id='{n}'")=='1','Memory reset preserves independent notification policy rows')
rules=json.dumps([{'item_id':item,'threshold':None}]);sql(f"SELECT findez_notification_stock_rules('{a}','{rules}',false)")
rules=json.dumps([{'item_id':item,'threshold':5}]);result=json.loads(sql(f"SELECT findez_notification_stock_rules('{a}','{rules}',true)"))
check(result[item] is None,'old device import cannot resurrect cleared threshold')
check(sql(f"SELECT findez_notification_begin_attempt('{n}')")=='f','cleared personal threshold stops a reserved alert')
outsider,_=account()
check(sql(f"SELECT findez_notification_stock_rules('{outsider}','{rules}',true)")=='{}','migration skips inaccessible items without disclosing their rules')
sql(f"DELETE FROM items WHERE item_id='{item}'")
check(sql(f"SELECT count(*) FROM notification_stock_rules WHERE item_id='{item}'")=='0','item deletion removes personal threshold subscriptions')

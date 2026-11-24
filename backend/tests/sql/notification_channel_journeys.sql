-- All times, records and provider responses below are synthetic. No network calls.
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); it uuid:=gen_random_uuid(); review uuid:=gen_random_uuid();
 d uuid; s uuid; photo uuid; req uuid; today date:=(now() AT TIME ZONE 'UTC')::date; policy notification_preferences;
BEGIN
 INSERT INTO auth.users VALUES(u);
 INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(v,u);
 INSERT INTO test_grants VALUES(u,v,'owner');
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations,inventory_push_actions)
 VALUES('journey',u,'sandbox',true,now(),true,true);
 UPDATE notification_preferences SET quiet_enabled=false,timezone='UTC',reengagement=true WHERE user_id=u RETURNING * INTO policy;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u)::text,true);
 INSERT INTO items(item_id,user_id,inventory_id,quantity,reorder_enabled,reorder_threshold,created_at)
 VALUES(it,u,v,20,true,3,now()-interval '7 days');
 INSERT INTO personalization_notifications(user_id,category,entity_type,entity_id,condition_key,policy_version)
 VALUES(u,'daily_inventory','account',gen_random_uuid(),'daily-inventory/'||today,1) RETURNING id INTO d;
 ASSERT findez_personalization_claim(d) IS NOT NULL;
 ASSERT findez_notification_begin_attempt(d,'journey',policy.revision);
 PERFORM findez_notification_finish(d,'accepted',NULL);
 UPDATE items SET quantity=3 WHERE item_id=it;
 SELECT id INTO STRICT s FROM personalization_notifications WHERE user_id=u AND category='low_stock';
 ASSERT findez_personalization_claim(s) IS NULL; -- spaced behind the noncritical daily push
 UPDATE notification_delivery_attempts SET reserved_at=now()-interval '3 hours' WHERE notification_id=d;
 UPDATE personalization_notifications SET scheduled_for=now() WHERE id=s;
 ASSERT findez_personalization_claim(s)->>'entity_id'=it::text;
 ASSERT findez_notification_begin_attempt(s,'journey',policy.revision);
 PERFORM findez_notification_finish(s,'accepted',NULL);
 UPDATE items SET quantity=2 WHERE item_id=it;
 ASSERT (SELECT count(*)=1 FROM personalization_notifications WHERE user_id=u AND category='low_stock');
 INSERT INTO capture_reviews VALUES(review,v,u,'pending');
 SELECT id INTO STRICT photo FROM personalization_notifications WHERE user_id=u AND category='scan_review';
 ASSERT (SELECT scheduled_for<=now() FROM personalization_notifications WHERE id=photo);
 -- A different account-day scenario with the daily send but no prior inventory event.
 UPDATE notification_delivery_attempts SET reserved_at=now()-interval '2 days' WHERE notification_id=s;
 ASSERT findez_personalization_claim(photo)->>'entity_id'=review::text;
 ASSERT findez_notification_begin_attempt(photo,'journey',policy.revision);
 PERFORM findez_notification_finish(photo,'accepted',NULL);
 ASSERT findez_personalization_claim(photo) IS NULL;
 -- A replenishment followed by a second crossing is a new event, but repeat-target cooldown protects the phone.
 INSERT INTO personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key,policy_version)
 VALUES(u,v,'low_stock','item',it,'second-crossing',1) RETURNING id INTO req;
 UPDATE notification_delivery_attempts SET reserved_at=now()-interval '3 hours' WHERE notification_id=s;
 UPDATE notification_channel_policy SET event_daily=5,event_gap=interval '0',spacing=interval '0';
 ASSERT findez_personalization_claim(req) IS NULL;
 ASSERT (SELECT suppression_reason='stock_cooldown' FROM personalization_notifications WHERE id=req);
 ASSERT (SELECT count(*)=3 FROM notification_delivery_attempts WHERE user_id=u AND state='accepted');
 UPDATE notification_preferences SET inventory_alerts=false WHERE user_id=u;
 ASSERT (SELECT daily_enabled FROM notification_preferences WHERE user_id=u);
 ASSERT findez_personalization_destination(u,d) IS NOT NULL;
 -- Apple's acceptance alone is never a tap or an action.
 ASSERT (SELECT bool_and(push_tapped_at IS NULL AND destination_at IS NULL AND workflow_finished_at IS NULL)
   FROM personalization_notifications WHERE user_id=u);
 PERFORM findez_seed_inventory_pushes(100);
 SELECT id INTO STRICT req FROM personalization_notifications WHERE user_id=u AND category='snap';
 PERFORM findez_notification_activity(u);
 ASSERT findez_notification_eligible(req,now())='active_session';
 INSERT INTO items(item_id,user_id,inventory_id) VALUES(gen_random_uuid(),u,v);
 ASSERT findez_notification_content(req) IS NULL;
END $$;
ROLLBACK;

-- Morning keeps the legacy date key. Evening is independent and never catches up
-- the morning push across the slot boundary. Exercise both US DST transitions.
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); local_day date; morning timestamptz; evening timestamptz;
 p notification_preferences; n personalization_notifications; test_day text;
BEGIN
 INSERT INTO auth.users VALUES(u);
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations)
 VALUES(u::text,u,'sandbox',true,now(),true);
 UPDATE notification_preferences SET timezone='America/New_York',quiet_enabled=false WHERE user_id=u RETURNING * INTO p;
 FOREACH local_day IN ARRAY ARRAY[date '2027-03-14',date '2027-11-07'] LOOP
  test_day:='daily-inventory/'||local_day;
  morning:=(local_day+time '10:00') AT TIME ZONE p.timezone;
  evening:=(local_day+time '18:00') AT TIME ZONE p.timezone;
  UPDATE push_devices SET updated_at=morning WHERE user_id=u;
  PERFORM findez_seed_daily_inventory(100,morning-interval '1 minute');
  ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key=test_day);
  PERFORM findez_seed_daily_inventory(100,morning);
  PERFORM findez_seed_daily_inventory(100,evening-interval '1 minute');
  ASSERT (SELECT expires_at=evening FROM personalization_notifications WHERE user_id=u AND condition_key=test_day);
  ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key=test_day||'/evening');
  PERFORM findez_seed_daily_inventory(100,evening);
  PERFORM findez_seed_daily_inventory(100,evening+interval '5 minutes');
  ASSERT (SELECT count(*)=2 FROM personalization_notifications WHERE user_id=u AND condition_key IN (test_day,test_day||'/evening'));
 END LOOP;
 local_day:=date '2027-11-08'; evening:=(local_day+time '18:00') AT TIME ZONE p.timezone;
 UPDATE notification_preferences SET quiet_enabled=true,quiet_start=17*60,quiet_end=19*60 WHERE user_id=u;
 PERFORM findez_seed_daily_inventory(100,evening);
 ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND scheduled_for=evening);
 PERFORM findez_seed_daily_inventory(100,evening+interval '1 hour');
 ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/2027-11-08');
 ASSERT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/2027-11-08/evening');
 UPDATE notification_preferences SET daily_enabled=false WHERE user_id=u;
 PERFORM findez_seed_daily_inventory(100,evening+interval '25 hours');
 ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/2027-11-09/evening');

 -- With two engagement slots already used before morning, both check-ins fit
 -- and a third engagement suggestion must wait. Independent event budget survives.
 n.user_id:=u; n.id:=gen_random_uuid(); n.critical:=false; n.category:='weekly_insight';
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at)
 VALUES(u,'add_item',false,morning-interval '4 hours'),(u,'discovery',false,morning-interval '3 hours');
 ASSERT findez_notification_budget(n,p,morning)='engagement_cap';
 n.category:='daily_inventory'; ASSERT findez_notification_budget(n,p,morning) IS NULL;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at) VALUES(u,'daily_inventory',false,morning);
 evening:=morning+interval '8 hours';
 ASSERT findez_notification_budget(n,p,evening) IS NULL;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at) VALUES(u,'daily_inventory',false,evening);
 n.category:='weekly_insight'; ASSERT findez_notification_budget(n,p,evening+interval '3 hours')='engagement_cap';
 n.category:='low_stock'; ASSERT findez_notification_budget(n,p,evening+interval '3 hours') IS NULL;
 ASSERT findez_notification_public_policy()->>'evening_inventory_hour'='18';
END $$;
ROLLBACK;

-- Rehearse the evening delivery entry points on an account whose clock shows evening.
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); inv uuid:=gen_random_uuid(); zone text; day date;
 am uuid; pm uuid; first_item uuid; second_item uuid; result jsonb; prefs notification_preferences;
BEGIN
 SELECT name INTO STRICT zone FROM pg_timezone_names WHERE name LIKE 'Etc/GMT%'
  AND (now() AT TIME ZONE name)::time BETWEEN time '18:05' AND time '20:59' LIMIT 1;
 day:=(now() AT TIME ZONE zone)::date;
 INSERT INTO auth.users VALUES(u);
 INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(inv,u);
 INSERT INTO test_grants VALUES(u,inv,'owner');
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations)
 VALUES(u::text,u,'sandbox',true,now(),true);
 UPDATE notification_preferences SET timezone=zone,quiet_enabled=false,show_details=false WHERE user_id=u RETURNING * INTO prefs;
 INSERT INTO items(item_id,inventory_id,user_id,quantity,location,name,created_at)
 SELECT gen_random_uuid(),inv,u,2,'Cabinet','Private component',now()-interval '7 days' FROM generate_series(1,2);
 PERFORM findez_seed_daily_inventory(100,(day+time '10:00') AT TIME ZONE zone);
 SELECT id,(daily_focus->>'id')::uuid INTO STRICT am,first_item FROM personalization_notifications
 WHERE user_id=u AND condition_key='daily-inventory/'||day;
 UPDATE personalization_notifications SET attempted_at=scheduled_for,accepted_at=scheduled_for WHERE id=am;
 INSERT INTO notification_delivery_attempts(notification_id,user_id,category,critical,reserved_at,state)
 SELECT id,u,'daily_inventory',false,scheduled_for,'accepted' FROM personalization_notifications WHERE id=am;
 PERFORM findez_seed_daily_inventory(100,now());
 SELECT id,(daily_focus->>'id')::uuid INTO STRICT pm,second_item FROM personalization_notifications
 WHERE user_id=u AND condition_key='daily-inventory/'||day||'/evening';
 ASSERT first_item<>second_item;
 ASSERT findez_personalization_claim(pm)->>'entity_id'=second_item::text;
 ASSERT findez_notification_content(pm)->>'body' NOT LIKE '%Private component%';
 ASSERT findez_notification_begin_attempt(pm,u::text,prefs.revision);
 PERFORM findez_notification_finish(pm,'accepted',NULL);
 ASSERT findez_personalization_destination(u,pm)->>'entity_id'=second_item::text;
 ASSERT findez_personalization_destination(gen_random_uuid(),pm) IS NULL;
 ASSERT findez_personalization_claim(pm) IS NULL;
 DELETE FROM items WHERE item_id=second_item;
 result:=findez_personalization_destination(u,pm);
 ASSERT result->>'entity_type'='account';
 ASSERT findez_daily_focus_view((SELECT n FROM personalization_notifications n WHERE id=pm),prefs,false)->>'title'='Your evening inventory check-in';
END $$;
ROLLBACK;

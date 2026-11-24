\ir ../../supabase/migrations/20261124_daily_inventory_update.sql
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); inv uuid:=gen_random_uuid(); n uuid; day date; t timestamptz; result jsonb;
BEGIN
 INSERT INTO auth.users VALUES(u);
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations)
 VALUES('daily-fixture',u,'sandbox',true,now(),true);
 UPDATE notification_preferences SET timezone='America/Los_Angeles' WHERE user_id=u;
 -- Includes the spring-forward Sunday (23-hour local date). Ignore other fixture accounts.
 FOR day IN SELECT generate_series(date '2027-03-10',date '2027-03-18',interval '1 day')::date LOOP
  t:=(day+time '10:00') AT TIME ZONE 'America/Los_Angeles';
  UPDATE push_devices SET updated_at=t WHERE user_id=u;
  PERFORM findez_seed_daily_inventory(100,t-interval '1 minute');
  ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/'||day::text);
  PERFORM findez_seed_daily_inventory(100,t);
  PERFORM findez_seed_daily_inventory(100,t+interval '5 minutes');
  ASSERT (SELECT count(*) FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/'||day::text)=1;
 END LOOP;
 ASSERT (SELECT count(*) FROM personalization_notifications WHERE user_id=u)=9;
 UPDATE notification_preferences SET quiet_start=540,quiet_end=720 WHERE user_id=u;
 t:='2027-03-19 10:00 America/Los_Angeles';
 PERFORM findez_seed_daily_inventory(100,t);
 ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/2027-03-19');
 PERFORM findez_seed_daily_inventory(100,t+interval '2 hours');
 ASSERT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/2027-03-19');
 UPDATE notification_preferences SET paused_until=t+interval '3 days' WHERE user_id=u;
 PERFORM findez_seed_daily_inventory(100,t+interval '26 hours');
 ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/2027-03-20');
 UPDATE notification_preferences SET paused_until=NULL,inventory_alerts=false WHERE user_id=u;
 PERFORM findez_seed_daily_inventory(100,t+interval '26 hours');
 ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/2027-03-20');

 -- Verify actual claim, send-time checks and inbox on today's clock with a saturated event quota.
 UPDATE push_devices SET updated_at=now() WHERE user_id=u;
 UPDATE notification_preferences SET inventory_alerts=true,quiet_enabled=false,timezone='UTC' WHERE user_id=u;
 t:=((now() AT TIME ZONE 'UTC')::date+time '10:01') AT TIME ZONE 'UTC';
 PERFORM findez_seed_daily_inventory(100,t);
 SELECT id INTO STRICT n FROM personalization_notifications WHERE user_id=u AND condition_key='daily-inventory/'||(t AT TIME ZONE 'UTC')::date::text;
 UPDATE personalization_notifications SET scheduled_for=now() WHERE id=n;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,state)
 SELECT u,'low_stock',false,'accepted' FROM generate_series(1,5);
 ASSERT findez_personalization_claim(n)->>'user_id'=u::text;
 ASSERT findez_personalization_claim(n) IS NULL;
 ASSERT findez_notification_begin_attempt(n,'daily-fixture',1);
 ASSERT findez_notification_content(n)->>'title'='Daily inventory update';
 ASSERT findez_notification_inbox(u) @> '[{"action":"daily_inventory","display_text":"Your personal inventory has no recorded items yet."}]';
 ASSERT findez_personalization_destination(gen_random_uuid(),n) IS NULL;
 UPDATE notification_preferences SET inventory_alerts=false WHERE user_id=u;
 ASSERT findez_notification_content(n) IS NULL;
 ASSERT NOT has_function_privilege('authenticated','findez_seed_daily_inventory(int,timestamptz)','execute');
END $$;
ROLLBACK;

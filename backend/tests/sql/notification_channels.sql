\ir ../../supabase/migrations/20261125_02_notification_channels.sql
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); n personalization_notifications; p notification_preferences; t timestamptz:='2027-03-14 10:00 America/New_York';
BEGIN
 INSERT INTO auth.users VALUES(u);
 INSERT INTO notification_preferences(user_id,timezone) VALUES(u,'America/New_York') RETURNING * INTO p;
 n.id:=gen_random_uuid(); n.user_id:=u; n.category:='daily_inventory'; n.critical:=false;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at) VALUES
 (u,'low_stock',false,t-interval '3 hours'),(u,'scan_review',false,t-interval '5 hours');
 ASSERT findez_notification_budget(n,p,t) IS NULL;
 DELETE FROM notification_delivery_attempts WHERE user_id=u;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at) VALUES(u,'daily_inventory',false,t-interval '3 hours');
 n.category:='scan_review'; ASSERT findez_notification_budget(n,p,t) IS NULL;
 n.category:='low_stock'; ASSERT findez_notification_budget(n,p,t) IS NULL;
 n.category:='snap'; ASSERT findez_notification_budget(n,p,t) IS NULL;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at) VALUES(u,'first_item',false,t-interval '3 hours');
 ASSERT findez_notification_budget(n,p,t)='suggestion_cap';
 UPDATE notification_channel_policy SET engagement_daily=2;
 n.category:='discovery'; ASSERT findez_notification_budget(n,p,t)='engagement_cap';
 UPDATE notification_channel_policy SET engagement_daily=4;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at) VALUES(u,'discovery',false,t-interval '2 days'),(u,'discovery',false,t-interval '3 days');
 ASSERT findez_notification_budget(n,p,t)='discovery_cap';
 n.category:='weekly_insight'; ASSERT findez_notification_budget(n,p,t) IS NULL;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at) VALUES(u,'weekly_insight',false,t-interval '15 minutes');
 ASSERT findez_notification_budget(n,p,t)='insight_cap';
 n.category:='expiry'; ASSERT findez_notification_budget(n,p,t)='spacing';
 n.critical:=true; ASSERT findez_notification_budget(n,p,t) IS NULL;
 ASSERT findez_notification_quiet(p,'2027-03-14 06:30:00+00');
 ASSERT NOT findez_notification_quiet(p,t);
 ASSERT findez_notification_preferences(u,'{"daily_enabled":false,"inventory_alerts":true}',0)->>'daily_enabled'='false';
 ASSERT (SELECT inventory_alerts FROM notification_preferences WHERE user_id=u);
 -- A daily opt-in cannot grant a fifth engagement slot. Genuine stock events retain their own budget.
 DELETE FROM notification_delivery_attempts WHERE user_id=u;
 INSERT INTO notification_delivery_attempts(user_id,category,critical,reserved_at,state)
 SELECT u,k,false,t-interval '3 hours','accepted' FROM unnest(ARRAY['snap','add_item','discovery','discovery']) AS k;
 p.daily_enabled:=true;
 n.critical:=false;
 n.category:='daily_inventory'; ASSERT findez_notification_budget(n,p,t)='engagement_cap';
 n.category:='locate_item'; ASSERT findez_notification_budget(n,p,t)='engagement_cap';
 n.category:='low_stock'; ASSERT findez_notification_budget(n,p,t) IS NULL;
END $$;
ROLLBACK;

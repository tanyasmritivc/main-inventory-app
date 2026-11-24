BEGIN;
SET LOCAL lock_timeout='5s';
ALTER TABLE notification_preferences ADD COLUMN daily_enabled boolean;
UPDATE notification_preferences SET daily_enabled=inventory_alerts;
ALTER TABLE notification_preferences ALTER COLUMN daily_enabled SET DEFAULT true, ALTER COLUMN daily_enabled SET NOT NULL,
 DROP CONSTRAINT notification_preferences_cleanup_insights_check, DROP CONSTRAINT notification_preferences_weekly_recap_check;
ALTER TABLE personalization_notifications DROP CONSTRAINT personalization_notifications_category_check,
 ADD CHECK(category IN ('daily_inventory','low_stock','scan_review','expiry','locate_item','first_item','add_item','snap','discovery','weekly_insight')),
 ADD COLUMN action_targets uuid[] NOT NULL DEFAULT '{}', ADD COLUMN experiment_variant text;
CREATE TABLE notification_channel_policy (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 engagement_daily int NOT NULL DEFAULT 4 CHECK(engagement_daily BETWEEN 1 AND 10),
 suggestions_daily int NOT NULL DEFAULT 1 CHECK(suggestions_daily BETWEEN 0 AND 3),
 discoveries_weekly int NOT NULL DEFAULT 2 CHECK(discoveries_weekly BETWEEN 0 AND 7),
 insights_weekly int NOT NULL DEFAULT 1 CHECK(insights_weekly BETWEEN 0 AND 3),
 event_daily int NOT NULL DEFAULT 2 CHECK(event_daily BETWEEN 1 AND 10),
 event_weekly int NOT NULL DEFAULT 5 CHECK(event_weekly BETWEEN 1 AND 35),
 event_gap interval NOT NULL DEFAULT '24 hours' CHECK(event_gap >= interval '0'),
 spacing interval NOT NULL DEFAULT '2 hours' CHECK(spacing >= interval '0'),
 review_gap interval NOT NULL DEFAULT '7 days' CHECK(review_gap >= interval '0'),
 repeat_stock_gap interval NOT NULL DEFAULT '24 hours' CHECK(repeat_stock_gap >= interval '0'),
 suggestion_repeat interval NOT NULL DEFAULT '2 days' CHECK(suggestion_repeat >= interval '0'),
 add_experiment boolean NOT NULL DEFAULT false);
INSERT INTO notification_channel_policy DEFAULT VALUES;
ALTER TABLE notification_channel_policy ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON notification_channel_policy FROM PUBLIC,anon,authenticated;
GRANT SELECT, UPDATE ON notification_channel_policy TO service_role;

CREATE FUNCTION findez_notification_channel(category text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE WHEN category='daily_inventory' THEN 'daily'
 WHEN category IN ('first_item','add_item','snap') THEN 'suggestion'
 WHEN category IN ('discovery','weekly_insight') THEN 'discovery' ELSE 'event' END
$$;

CREATE OR REPLACE FUNCTION public.findez_notification_preferences(p_actor uuid,p_data jsonb DEFAULT NULL,p_expected bigint DEFAULT NULL,p_timezone text DEFAULT 'America/Los_Angeles') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE p notification_preferences; key text;
BEGIN
 IF NOT EXISTS(SELECT FROM auth.users WHERE id=p_actor) THEN RAISE insufficient_privilege; END IF;
 IF NOT EXISTS(SELECT FROM pg_timezone_names WHERE name=p_timezone) THEN RAISE invalid_parameter_value; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor::text,193));
 INSERT INTO notification_preferences(user_id,timezone) VALUES(p_actor,p_timezone) ON CONFLICT DO NOTHING;
 SELECT * INTO p FROM notification_preferences WHERE user_id=p_actor FOR UPDATE;
 IF p_data IS NOT NULL THEN
  IF p_expected IS DISTINCT FROM p.revision THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Notification preferences changed.'; END IF;
  IF jsonb_typeof(p_data)<>'object' OR p_data - ARRAY['push_enabled','in_app_enabled','quiet_enabled','quiet_start','quiet_end','timezone','inventory_alerts','capture_reminders','daily_enabled','weekly_recap','cleanup_insights','reengagement','user_reminders','show_details','paused_until']::text[]<>'{}'::jsonb THEN RAISE invalid_parameter_value; END IF;
  FOREACH key IN ARRAY ARRAY['push_enabled','in_app_enabled','quiet_enabled','inventory_alerts','capture_reminders','daily_enabled','weekly_recap','cleanup_insights','reengagement','user_reminders','show_details'] LOOP
   IF p_data ? key AND jsonb_typeof(p_data->key)<>'boolean' THEN RAISE invalid_parameter_value; END IF;
  END LOOP;
  p:=jsonb_populate_record(p,p_data);
  IF NOT EXISTS(SELECT FROM pg_timezone_names WHERE name=p.timezone) OR p.paused_until>now()+interval '7 days 1 minute' THEN RAISE invalid_parameter_value; END IF;
  UPDATE notification_preferences SET push_enabled=p.push_enabled,in_app_enabled=p.in_app_enabled,
   quiet_enabled=p.quiet_enabled,quiet_start=p.quiet_start,quiet_end=p.quiet_end,timezone=p.timezone,
   inventory_alerts=p.inventory_alerts,
   daily_enabled=CASE WHEN p_data ? 'inventory_alerts' AND NOT p_data ? 'daily_enabled' THEN p.inventory_alerts ELSE p.daily_enabled END,capture_reminders=p.capture_reminders,weekly_recap=p.weekly_recap,
   cleanup_insights=p.cleanup_insights,reengagement=p.reengagement,user_reminders=p.user_reminders,
   show_details=p.show_details,paused_until=p.paused_until,revision=revision+1,updated_at=now()
   WHERE user_id=p_actor RETURNING * INTO p;
  UPDATE personalization_notifications SET state='resolved',suppression_reason='category_off'
   WHERE user_id=p_actor AND state IN ('pending','sending') AND
    ((category='low_stock' AND NOT p.inventory_alerts) OR (category='scan_review' AND NOT p.capture_reminders));
  PERFORM findez_notification_metric('preferences_updated','preferences');
 END IF;
 RETURN to_jsonb(p)-'user_id';
END $$;
CREATE OR REPLACE FUNCTION public.findez_seed_daily_inventory(p_limit int, p_at timestamptz DEFAULT now()) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE made int;
BEGIN
 WITH due AS (
  SELECT p.user_id,local_day,p.timezone FROM notification_preferences p
  CROSS JOIN LATERAL (SELECT (p_at AT TIME ZONE p.timezone)::date AS local_day) clock
  WHERE p.push_enabled AND p.daily_enabled AND (p.paused_until IS NULL OR p.paused_until<=p_at)
    AND NOT findez_notification_quiet(p,p_at)
    AND (p_at AT TIME ZONE p.timezone)::time >=
      CASE WHEN findez_notification_quiet(p,(local_day+time '10:00') AT TIME ZONE p.timezone)
           THEN time '00:00'+make_interval(mins=>p.quiet_end) ELSE time '10:00' END
    AND EXISTS (SELECT FROM push_devices WHERE user_id=p.user_id AND enabled AND personalization_destinations AND updated_at>p_at-interval '90 days')
    AND NOT EXISTS (SELECT FROM personalization_notifications WHERE user_id=p.user_id AND condition_key='daily-inventory/'||local_day::text)
  ORDER BY p.user_id LIMIT least(100,greatest(1,p_limit))
 )
 INSERT INTO personalization_notifications(user_id,category,entity_type,entity_id,condition_key,policy_version,scheduled_for,expires_at)
 SELECT user_id,'daily_inventory','account',gen_random_uuid(),'daily-inventory/'||local_day::text,1,p_at,
        (local_day+1)::timestamp AT TIME ZONE timezone FROM due
 ON CONFLICT(user_id,condition_key) DO NOTHING;
 GET DIAGNOSTICS made=ROW_COUNT;
 RETURN made;
END $$;
CREATE OR REPLACE FUNCTION public.findez_daily_focus_view(n personalization_notifications,p notification_preferences,details boolean)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE
 kind text:=n.daily_focus->>'kind'; inv uuid:=(n.daily_focus->>'inventory_id')::uuid;
 target uuid:=(n.daily_focus->>'id')::uuid; entity text:=n.daily_focus->>'entity';
 item items; title text; body text; label text;
 local_date date:=(now() AT TIME ZONE p.timezone)::date;
 fallback jsonb:=jsonb_build_object('entity_type','account','notification_id',n.id,'active',true,
  'title','Your inventory check-in','body','What would you like to find faster? Choose one item and record where you keep it.');
BEGIN
 IF p.user_id IS DISTINCT FROM n.user_id OR NOT p.daily_enabled OR n.expires_at<=now()
    OR n.condition_key<>'daily-inventory/'||local_date::text THEN RETURN NULL; END IF;
 IF kind IS NULL OR NOT EXISTS(SELECT FROM app_inventories WHERE inventory_id=inv AND owner_user_id=n.user_id AND team_id IS NULL)
    OR findez_inventory_role(inv,n.user_id) IS NULL THEN RETURN fallback; END IF;
 IF entity='item' THEN
  SELECT * INTO item FROM items WHERE inventory_id=inv AND user_id=n.user_id AND item_id=target;
  IF NOT FOUND THEN RETURN fallback; END IF;
  label:=left(coalesce(nullif(btrim(item.name),''),'this item'),65);
  IF kind IN ('location','low_stock','expiry','quantity') AND NOT p.inventory_alerts THEN RETURN fallback; END IF;
  IF kind='location' AND nullif(btrim(item.location),'') IS NULL AND item.space_id IS NULL THEN
   title:='Give one item a home'; body:=CASE WHEN details THEN format('Where do you keep %s? Tap to add its missing location.',label)
      ELSE 'Open an item and save its storage location so you can find it next time.' END;
  ELSIF kind='low_stock' AND item.quantity>=0 AND ((item.reorder_enabled AND item.quantity<=item.reorder_threshold)
      OR EXISTS(SELECT FROM notification_stock_rules WHERE user_id=n.user_id AND item_id=target AND threshold>=item.quantity)) THEN
   title:='Time for a stock check'; body:=CASE WHEN details THEN format('%s has a recorded quantity of %s. Tap to check it against the shelf.',label,item.quantity)
      ELSE 'Check the recorded quantity of an item flagged by your saved low-stock threshold.' END;
  ELSIF kind='quantity' AND (item.quantity IS NULL OR item.quantity<0) THEN
   title:='Make your next count useful'; body:=CASE WHEN details THEN format('How many do you have of %s? Tap to record a quantity.',label)
      ELSE 'An item needs a quantity. Open its record to add one.' END;
  ELSIF kind='expiry' AND item.expires_on BETWEEN local_date AND local_date+7 THEN
   title:='Check an upcoming expiry'; body:=CASE WHEN details THEN format('%s has a recorded expiry date of %s. Tap to review it.',label,item.expires_on)
      ELSE 'Open an item whose recorded expiry date is coming up.' END;
  ELSIF kind='progress' AND (item.created_at AT TIME ZONE p.timezone)::date=local_date THEN
   title:='A new addition worth checking'; body:=CASE WHEN details THEN format('You recorded %s today. Tap to check its details.',label)
      ELSE 'Open a record you added today and check the details while they are fresh.' END;
  ELSE
   title:='Could you find this item today?'; body:=CASE WHEN details THEN format('Open the record for %s before your next project.',label)
      ELSE 'Revisit one saved item and check where to find it before your next project.' END;
  END IF;
 ELSIF entity='review' AND p.capture_reminders AND EXISTS(SELECT FROM capture_reviews WHERE inventory_id=inv AND user_id=n.user_id AND review_id=target AND status='pending') THEN
  title:='Finish one photo review'; body:='Your capture is waiting for review. Tap to check the extracted details.';
 ELSIF entity='inventory' AND p.reengagement AND kind IN ('snap','add_item') AND target=inv THEN
  IF EXISTS(SELECT FROM items WHERE inventory_id=inv AND user_id=n.user_id AND (created_at AT TIME ZONE p.timezone)::date=local_date) THEN
    RETURN fallback||jsonb_build_object('title','You added inventory today','body','Your new records are ready to search in FindEZ.');
  END IF;
  IF kind='snap' THEN title:='One shelf, one photo'; body:='Snap a shelf or toolbox and review the items FindEZ picks out.';
  ELSE title:='Add one item today'; body:='Pick one thing you often look for. Tap to record it and where it belongs.'; END IF;
 ELSE RETURN fallback;
 END IF;
 RETURN jsonb_build_object('notification_id',n.id,'entity_type',entity,'entity_id',target,'inventory_id',inv,
   'active',true,'quick_action',kind,'title',title,'body',body);
END $$;
CREATE OR REPLACE FUNCTION public.findez_choose_daily_focus(p_user uuid,p_date date,p_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 WITH preferences AS (
   SELECT * FROM notification_preferences WHERE user_id=p_user
 ), inventories AS MATERIALIZED (
   SELECT v.inventory_id,v.is_default FROM app_inventories v
   WHERE v.owner_user_id=p_user AND v.team_id IS NULL
     AND findez_inventory_role(v.inventory_id,p_user) IN ('owner','editor')
 ), records AS MATERIALIZED (
   SELECT i.*, (i.created_at AT TIME ZONE p.timezone)::date AS added_on
   FROM items i JOIN inventories v USING(inventory_id) CROSS JOIN preferences p
   WHERE i.user_id=p_user
 ), history AS MATERIALIZED (
   SELECT daily_focus->>'kind' AS kind,daily_focus->>'id' AS id,max(created_at) AS shown
   FROM personalization_notifications
   WHERE user_id=p_user AND category='daily_inventory' AND id<>p_id AND accepted_at IS NOT NULL
     AND created_at>=now()-interval '14 days' AND daily_focus IS NOT NULL
   GROUP BY 1,2
 ), candidates AS (
   SELECT choice.kind,choice.priority,i.inventory_id,i.item_id AS id,'item' AS entity,i.created_at AS recency
   -- Low stock is a transition alert. A daily scan of the same level must not re-arm it.
   FROM records i
   CROSS JOIN LATERAL (VALUES
     ('expiry',2,i.expires_on BETWEEN p_date AND p_date+7),
     ('location',3,nullif(btrim(i.location),'') IS NULL AND i.space_id IS NULL),
     ('quantity',4,i.quantity IS NULL OR i.quantity<0),
     ('progress',5,i.added_on=p_date),
     ('rediscover',8,true)
   ) choice(kind,priority,eligible) WHERE choice.eligible AND (choice.kind IN ('progress','rediscover') OR (SELECT inventory_alerts FROM preferences))
   UNION ALL
   SELECT 'review',0,r.inventory_id,r.review_id,'review',NULL::timestamptz
   FROM capture_reviews r JOIN inventories v USING(inventory_id) CROSS JOIN preferences p
   WHERE p.capture_reminders AND r.user_id=p_user AND r.status='pending'
   UNION ALL
   SELECT k.kind,k.priority,v.inventory_id,v.inventory_id,'inventory',NULL::timestamptz
   FROM inventories v CROSS JOIN preferences p
   CROSS JOIN (VALUES ('add_item',6),('snap',7)) k(kind,priority)
   WHERE v.is_default AND p.reengagement AND NOT EXISTS(SELECT FROM records WHERE added_on=p_date)
     AND coalesce((SELECT inventory_push_actions FROM push_devices WHERE user_id=p_user AND enabled
       AND personalization_destinations AND updated_at>now()-interval '90 days' ORDER BY updated_at DESC,device_token LIMIT 1),false)
 )
 SELECT jsonb_build_object('kind',c.kind,'inventory_id',c.inventory_id,'id',c.id,'entity',c.entity)
 FROM candidates c
 LEFT JOIN (SELECT kind,max(shown) AS shown FROM history GROUP BY kind) h USING(kind)
 LEFT JOIN history target ON target.kind=c.kind AND target.id=c.id::text
 WHERE NOT EXISTS (
   SELECT FROM personalization_notifications recent
   WHERE recent.user_id=p_user AND recent.category<>'daily_inventory' AND recent.accepted_at>now()-interval '24 hours'
   AND (recent.entity_id=c.id OR c.id=ANY(recent.action_targets))
   AND CASE WHEN recent.category IN ('first_item','add_item') THEN 'add_item'
     WHEN recent.category IN ('locate_item','discovery') THEN 'location'
     WHEN recent.category='weekly_insight' THEN 'quantity' WHEN recent.category='scan_review' THEN 'review' ELSE recent.category END=c.kind)
 ORDER BY h.shown NULLS FIRST,c.priority,target.shown NULLS FIRST,c.recency DESC NULLS LAST,c.id LIMIT 1
$$;

-- Evaluate reservations and provider attempts using the same account lock and clock.
CREATE FUNCTION findez_notification_budget(n personalization_notifications,p notification_preferences,t timestamptz)
RETURNS text LANGUAGE plpgsql STABLE SET search_path=public AS $$
DECLARE cfg notification_channel_policy; channel text:=findez_notification_channel(n.category);
 midnight timestamptz:=date_trunc('day',t AT TIME ZONE p.timezone) AT TIME ZONE p.timezone;
 used record;
BEGIN
 SELECT * INTO STRICT cfg FROM notification_channel_policy WHERE singleton;
 SELECT count(*) FILTER(WHERE ch='event' AND reserved_at>=midnight) AS event_today,
   count(*) FILTER(WHERE ch='event' AND reserved_at>t-interval '7 days') AS event_week,
   max(reserved_at) FILTER(WHERE ch='event' AND NOT critical) AS last_event,
   max(reserved_at) FILTER(WHERE category='scan_review') AS last_review,
   max(reserved_at) FILTER(WHERE NOT critical) AS last_noncritical,
   count(*) FILTER(WHERE (ch<>'event' OR category='locate_item') AND reserved_at>=midnight) AS engagement,
   count(*) FILTER(WHERE ch='daily' AND reserved_at>=midnight) AS daily_used,
   count(*) FILTER(WHERE ch='suggestion' AND reserved_at>=midnight) AS suggestions,
   count(*) FILTER(WHERE category=n.category AND reserved_at>t-interval '7 days') AS category_week
 INTO used FROM (
   SELECT a.*,findez_notification_channel(a.category) AS ch FROM notification_delivery_attempts a
   WHERE a.user_id=n.user_id AND a.notification_id IS DISTINCT FROM n.id AND a.state<>'cancelled'
   AND a.reserved_at >= least(midnight,t-interval '7 days',t-cfg.event_gap,t-cfg.spacing,t-cfg.review_gap)
 ) history;
 -- Location cleanup retains its legacy event cooldown and also consumes engagement budget.
 IF channel<>'event' OR n.category='locate_item' THEN
   IF used.engagement>=cfg.engagement_daily OR
      (channel<>'daily' AND p.daily_enabled AND used.daily_used=0 AND used.engagement+1>=cfg.engagement_daily)
   THEN RETURN 'engagement_cap'; END IF;
 END IF;
 IF channel='event' THEN
   IF used.event_today>=cfg.event_daily OR used.event_week>=cfg.event_weekly THEN RETURN 'event_cap'; END IF;
   IF NOT n.critical AND used.last_event>t-cfg.event_gap THEN RETURN 'event_cooldown'; END IF;
   IF n.category='scan_review' AND used.last_review>t-cfg.review_gap THEN RETURN 'review_cooldown'; END IF;
   IF n.category='low_stock' AND EXISTS(
    SELECT FROM notification_delivery_attempts a JOIN personalization_notifications old ON old.id=a.notification_id
     WHERE a.user_id=n.user_id AND a.state<>'cancelled' AND old.category=n.category AND old.entity_id=n.entity_id
       AND old.id<>n.id AND a.reserved_at>t-cfg.repeat_stock_gap AND (NOT n.critical OR old.critical)
   ) THEN RETURN 'stock_cooldown'; END IF;
 ELSIF channel<>'daily' THEN
   IF channel='suggestion' AND used.suggestions>=cfg.suggestions_daily THEN RETURN 'suggestion_cap'; END IF;
   IF channel='suggestion' AND EXISTS(SELECT FROM personalization_notifications h
     WHERE h.user_id=n.user_id AND h.category='daily_inventory' AND h.accepted_at>t-interval '24 hours'
       AND h.daily_focus->>'inventory_id'=n.inventory_id::text AND h.daily_focus->>'kind'=
         CASE WHEN n.category='first_item' THEN 'add_item' ELSE n.category END) THEN RETURN 'suggestion_cooldown'; END IF;
   IF channel='suggestion' AND EXISTS(SELECT FROM notification_delivery_attempts a
     WHERE a.user_id=n.user_id AND a.category=n.category AND a.state<>'cancelled' AND a.notification_id IS DISTINCT FROM n.id
       AND a.reserved_at>t-cfg.suggestion_repeat) THEN RETURN 'suggestion_cooldown'; END IF;
   IF n.category='discovery' AND used.category_week>=cfg.discoveries_weekly THEN RETURN 'discovery_cap'; END IF;
   IF n.category='weekly_insight' AND used.category_week>=cfg.insights_weekly THEN RETURN 'insight_cap'; END IF;
 END IF;
 IF NOT n.critical AND used.last_noncritical>t-cfg.spacing THEN RETURN 'spacing'; END IF;
 RETURN NULL;
END $$;
CREATE OR REPLACE FUNCTION public.findez_personalization_claim(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications;p notification_preferences;reason text; checked_at timestamptz;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND THEN RETURN NULL; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(n.user_id::text,193));
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id FOR UPDATE;
 IF n.state<>'pending' THEN RETURN NULL; END IF;
 checked_at:=clock_timestamp();
 reason:=findez_notification_eligible(p_id,checked_at);
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
 IF reason IS NULL THEN reason:=findez_notification_budget(n,p,checked_at); END IF;
 IF reason IS NOT NULL THEN
  UPDATE personalization_notifications SET suppression_reason=reason,
   state=CASE WHEN reason IN ('expired','stale','category_off','inactive') THEN 'resolved' ELSE state END,
   scheduled_for=greatest(scheduled_for,now()+interval '5 minutes') WHERE id=p_id;
  PERFORM findez_notification_metric(reason,n.category);
  RETURN NULL;
 END IF;
 INSERT INTO notification_delivery_attempts(notification_id,user_id,category,critical,reserved_at) VALUES(n.id,n.user_id,n.category,n.critical,checked_at)
 ON CONFLICT(notification_id) DO UPDATE SET state='reserved',reserved_at=excluded.reserved_at,finished_at=NULL
 WHERE notification_delivery_attempts.state='cancelled' AND notification_delivery_attempts.started_at IS NULL;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE personalization_notifications SET state='sending',suppression_reason=NULL WHERE id=p_id;
 PERFORM findez_notification_metric('queued',n.category);
 RETURN findez_personalization_destination(n.user_id,n.id)||jsonb_build_object('user_id',n.user_id,'category',n.category,'show_details',p.show_details);
END $$;
CREATE OR REPLACE FUNCTION public.findez_notification_begin_attempt(p_id uuid,p_device text DEFAULT NULL,p_revision bigint DEFAULT NULL) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; reason text; checked_at timestamptz; a notification_delivery_attempts; p notification_preferences;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND THEN RETURN false; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(n.user_id::text,193));
 SELECT * INTO a FROM notification_delivery_attempts WHERE notification_id=p_id FOR UPDATE;
 IF NOT FOUND OR a.state NOT IN ('reserved','started') OR a.attempts>=3 THEN RETURN false; END IF;
 checked_at:=clock_timestamp();
 reason:=findez_notification_eligible(p_id,checked_at);
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
 IF p_revision IS NOT NULL AND p.revision IS DISTINCT FROM p_revision THEN reason:='preferences_changed'; END IF;
 IF p_device IS NOT NULL AND NOT EXISTS(SELECT FROM push_devices WHERE device_token=p_device AND user_id=n.user_id AND enabled AND personalization_destinations) THEN reason:='no_device'; END IF;
 IF reason IS NULL AND a.started_at IS NULL THEN reason:=findez_notification_budget(n,p,checked_at); END IF;
 IF reason IS NOT NULL THEN
  IF a.started_at IS NULL THEN
   UPDATE notification_delivery_attempts SET state='cancelled',finished_at=now() WHERE id=a.id;
  ELSE UPDATE notification_delivery_attempts SET state='failed',finished_at=now(),error_code='eligibility_changed' WHERE id=a.id; END IF;
  UPDATE personalization_notifications SET state=CASE WHEN a.started_at IS NULL AND reason IN ('quiet_hours','paused','push_off','no_device','scheduled','preferences_changed','event_cap','event_cooldown','review_cooldown','stock_cooldown','engagement_cap','suggestion_cap','discovery_cap','insight_cap','spacing','suggestion_cooldown','active_session') THEN 'pending' ELSE 'resolved' END,
   scheduled_for=greatest(scheduled_for,now()+interval '5 minutes'),suppression_reason=reason WHERE id=p_id;
  RETURN false;
 END IF;
 UPDATE notification_delivery_attempts SET state='started',reserved_at=CASE WHEN started_at IS NULL THEN checked_at ELSE reserved_at END,started_at=coalesce(started_at,checked_at),attempts=attempts+1 WHERE id=a.id;
 UPDATE personalization_notifications SET attempted_at=coalesce(attempted_at,now()) WHERE id=p_id;
 RETURN true;
END $$;
CREATE OR REPLACE FUNCTION public.findez_personalization_candidates(p_limit int DEFAULT 50) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 WITH due AS (
  SELECT id,user_id,critical,scheduled_for,CASE WHEN category='daily_inventory' THEN 0
   WHEN category IN ('low_stock','scan_review','expiry') THEN 1 WHEN category IN ('discovery','weekly_insight') THEN 2 ELSE 3 END AS priority
  FROM personalization_notifications WHERE policy_version=1 AND state='pending' AND scheduled_for<=now()
 ), ranked AS (
  SELECT *,row_number() OVER(PARTITION BY user_id ORDER BY critical DESC,priority,scheduled_for,id) AS turn FROM due
 ), batch AS (
  SELECT * FROM ranked ORDER BY critical DESC,turn,scheduled_for,priority,id LIMIT least(100,greatest(1,p_limit))
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id) ORDER BY critical DESC,turn,scheduled_for,priority,id),'[]') FROM batch
$$;
CREATE OR REPLACE FUNCTION public.findez_notification_observe() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r jsonb; old_r jsonb; actor uuid:=findez_request_actor(); entity uuid; inv uuid; kind text;
 active boolean; was_active boolean; category text; event_key text; prefs notification_preferences; recipient uuid;
BEGIN
 r:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
 old_r:=CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
 inv:=(r->>'inventory_id')::uuid;
 kind:=CASE WHEN TG_TABLE_NAME='items' THEN 'item' ELSE 'review' END;
 entity:=(r->>CASE WHEN kind='item' THEN 'item_id' ELSE 'review_id' END)::uuid;
 active:=TG_OP<>'DELETE' AND CASE WHEN kind='item' THEN findez_notification_condition(r) ELSE r->>'status'='pending' END;
 -- Resolution applies to every recipient, including a change by another editor.
 UPDATE personalization_notifications SET state='resolved',suppression_reason='resolved',
  completed_at=CASE WHEN opened_at IS NOT NULL AND TG_OP='UPDATE' THEN now() ELSE completed_at END
 WHERE personalization_notifications.category IN ('low_stock','scan_review') AND entity_type=kind AND entity_id=entity AND (TG_OP='DELETE' OR inventory_id IS DISTINCT FROM inv OR
 CASE WHEN kind='item' THEN NOT findez_notification_item_condition(user_id,r) ELSE NOT active END)
  AND state NOT IN ('resolved','dismissed');
 IF TG_OP='DELETE' THEN RETURN coalesce(NEW,OLD); END IF;
 FOR recipient IN SELECT actor WHERE actor IS NOT NULL UNION SELECT user_id FROM notification_stock_rules WHERE kind='item' AND item_id=entity AND threshold IS NOT NULL LOOP
 actor:=recipient;
 active:=CASE WHEN kind='item' THEN findez_notification_item_condition(actor,r) ELSE r->>'status'='pending' END;
 IF NOT active OR findez_inventory_role(inv,actor) IS NULL THEN CONTINUE; END IF;
 SELECT * INTO prefs FROM notification_preferences WHERE user_id=actor;
 IF NOT FOUND THEN
  INSERT INTO notification_preferences(user_id) VALUES(actor) ON CONFLICT DO NOTHING;
  SELECT * INTO prefs FROM notification_preferences WHERE user_id=actor;
 END IF;
 category:=CASE WHEN kind='item' THEN 'low_stock' ELSE 'scan_review' END;
 IF (category='low_stock' AND NOT prefs.inventory_alerts) OR (category='scan_review' AND NOT prefs.capture_reminders)
 OR NOT (prefs.in_app_enabled OR prefs.push_enabled) THEN CONTINUE; END IF;
 was_active:=CASE WHEN kind='item' THEN findez_notification_item_condition(actor,old_r) ELSE old_r->>'status'='pending' END;
 IF kind='item' THEN
  -- A new default quantity of zero is not evidence of a stock change.
  IF TG_OP<>'UPDATE' OR was_active OR (old_r->>'quantity')::numeric IS NULL OR (old_r->>'quantity')::numeric<0 THEN CONTINUE; END IF;
  event_key:='stock:'||entity::text||':'||txid_current()::text;
 ELSE
  IF TG_OP<>'INSERT' THEN CONTINUE; END IF;
  event_key:='review:'||entity::text;
 END IF;
 INSERT INTO personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key,policy_version,critical,scheduled_for)
 VALUES(actor,inv,category,kind,entity,event_key,1,kind='item' AND (r->>'quantity')::numeric=0,
  now()) ON CONFLICT DO NOTHING;
 IF FOUND THEN PERFORM findez_notification_metric('candidate',category); ELSE PERFORM findez_notification_metric('duplicate',category); END IF;
 END LOOP;
 RETURN coalesce(NEW,OLD);
END $$;
CREATE OR REPLACE FUNCTION public.findez_notification_inbox(p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(r ORDER BY r.created_at DESC),'[]') FROM (
 SELECT n.id,CASE WHEN n.category='daily_inventory' AND coalesce(focus->>'entity_type','account')='account' THEN 'daily_inventory' ELSE 'personalization' END AS action,n.category,n.created_at,n.read_at IS NOT NULL AS is_read,
 CASE WHEN category='daily_inventory' THEN focus->>'body' WHEN findez_tip_text(category) IS NOT NULL THEN findez_tip_text(category) WHEN category='scan_review' THEN 'A photo review is waiting for you.' ELSE 'An inventory item needs your attention.' END AS display_text
 FROM personalization_notifications n JOIN notification_preferences p ON p.user_id=n.user_id
 LEFT JOIN LATERAL (SELECT findez_daily_focus_view(n,p,true) AS focus WHERE n.category='daily_inventory') advice ON true
 WHERE n.user_id=p_actor AND n.policy_version=1 AND p.in_app_enabled AND n.state NOT IN ('resolved','dismissed')
 AND n.expires_at>now() AND (findez_personalization_destination(p_actor,n.id)->'active')='true'::jsonb
 AND ((n.category IN ('expiry','locate_item','low_stock') AND p.inventory_alerts) OR (n.category='daily_inventory' AND p.daily_enabled) OR (n.category='scan_review' AND p.capture_reminders) OR (n.category IN ('first_item','add_item','snap') AND p.reengagement))
 ORDER BY n.created_at DESC LIMIT 100) r
$$;
REVOKE ALL ON FUNCTION findez_notification_budget(personalization_notifications,notification_preferences,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION findez_notification_budget(personalization_notifications,notification_preferences,timestamptz) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

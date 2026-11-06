-- Additive policy over the existing notification queue. Apply after 081.
BEGIN;
CREATE TABLE public.notification_preferences (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 revision bigint NOT NULL DEFAULT 0,
 push_enabled boolean NOT NULL DEFAULT false,
 in_app_enabled boolean NOT NULL DEFAULT true,
 quiet_enabled boolean NOT NULL DEFAULT true,
 quiet_start integer NOT NULL DEFAULT 1260 CHECK(quiet_start BETWEEN 0 AND 1439),
 quiet_end integer NOT NULL DEFAULT 480 CHECK(quiet_end BETWEEN 0 AND 1439),
 timezone text NOT NULL DEFAULT 'America/Los_Angeles',
 inventory_alerts boolean NOT NULL DEFAULT true,
 capture_reminders boolean NOT NULL DEFAULT true,
 weekly_recap boolean NOT NULL DEFAULT false CHECK(NOT weekly_recap),
 cleanup_insights boolean NOT NULL DEFAULT false CHECK(NOT cleanup_insights),
 reengagement boolean NOT NULL DEFAULT false CHECK(NOT reengagement),
 user_reminders boolean NOT NULL DEFAULT false CHECK(NOT user_reminders),
 show_details boolean NOT NULL DEFAULT false,
 paused_until timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now()
);
-- Only explicit previous notification opt-ins are carried forward.
INSERT INTO public.notification_preferences(user_id,push_enabled,inventory_alerts,capture_reminders,timezone,quiet_start,quiet_end)
 SELECT user_id,true,'low_stock'=ANY(categories),'scan_review'=ANY(categories),timezone,quiet_start,quiet_end
 FROM public.personalization_profiles WHERE enabled AND cardinality(categories)>0;
ALTER TABLE public.personalization_notifications
 ADD COLUMN policy_version integer NOT NULL DEFAULT 0,
 ADD COLUMN critical boolean NOT NULL DEFAULT false,
 ADD COLUMN scheduled_for timestamptz NOT NULL DEFAULT now(),
 ADD COLUMN expires_at timestamptz NOT NULL DEFAULT now()+interval '24 hours',
 ADD COLUMN read_at timestamptz,
 ADD COLUMN suppression_reason text;
-- Never replay pre-migration candidates under new defaults.
UPDATE public.personalization_notifications SET state='resolved' WHERE state='pending';
CREATE TABLE public.notification_delivery_attempts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 notification_id uuid REFERENCES public.personalization_notifications(id) ON DELETE SET NULL,
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 category text NOT NULL,
 critical boolean NOT NULL,
 reserved_at timestamptz NOT NULL DEFAULT now(),
 started_at timestamptz,
 finished_at timestamptz,
 state text NOT NULL DEFAULT 'reserved' CHECK(state IN ('reserved','started','accepted','unknown','failed','cancelled')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 3),
 error_code text,
 UNIQUE(notification_id)
);
CREATE INDEX notification_delivery_caps ON public.notification_delivery_attempts(user_id,reserved_at DESC);
CREATE TABLE public.notification_policy_metrics (
 day date NOT NULL DEFAULT (now() AT TIME ZONE 'UTC')::date,
 reason text NOT NULL, category text NOT NULL, count bigint NOT NULL DEFAULT 0,
 PRIMARY KEY(day,reason,category)
);
CREATE TABLE public.notification_inbox_hidden (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 invitation_id uuid NOT NULL,
 hidden_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,invitation_id)
);
-- Personal alert rules do not change shared inventory quantities or thresholds.
CREATE TABLE public.notification_stock_rules (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 item_id uuid NOT NULL REFERENCES public.items(item_id) ON DELETE CASCADE,
 threshold integer CHECK(threshold BETWEEN 0 AND 2147483647),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,item_id)
);
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['notification_preferences','notification_delivery_attempts','notification_policy_metrics','notification_inbox_hidden','notification_stock_rules'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
 END LOOP;
END $$;

CREATE FUNCTION public.findez_notification_metric(p_reason text,p_category text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 INSERT INTO notification_policy_metrics(reason,category,count) VALUES(p_reason,p_category,1)
 ON CONFLICT(day,reason,category) DO UPDATE SET count=notification_policy_metrics.count+1
$$;

CREATE FUNCTION public.findez_notification_preferences(p_actor uuid,p_data jsonb DEFAULT NULL,p_expected bigint DEFAULT NULL,p_timezone text DEFAULT 'America/Los_Angeles') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE p notification_preferences; key text;
BEGIN
 IF NOT EXISTS(SELECT FROM auth.users WHERE id=p_actor) THEN RAISE insufficient_privilege; END IF;
 IF NOT EXISTS(SELECT FROM pg_timezone_names WHERE name=p_timezone) THEN RAISE invalid_parameter_value; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor::text,193));
 INSERT INTO notification_preferences(user_id,timezone) VALUES(p_actor,p_timezone) ON CONFLICT DO NOTHING;
 SELECT * INTO p FROM notification_preferences WHERE user_id=p_actor FOR UPDATE;
 IF p_data IS NOT NULL THEN
  IF p_expected IS DISTINCT FROM p.revision THEN RAISE serialization_failure; END IF;
  IF jsonb_typeof(p_data)<>'object' OR p_data - ARRAY['push_enabled','in_app_enabled','quiet_enabled','quiet_start','quiet_end','timezone','inventory_alerts','capture_reminders','weekly_recap','cleanup_insights','reengagement','user_reminders','show_details','paused_until']::text[]<>'{}'::jsonb THEN RAISE invalid_parameter_value; END IF;
  FOREACH key IN ARRAY ARRAY['push_enabled','in_app_enabled','quiet_enabled','inventory_alerts','capture_reminders','weekly_recap','cleanup_insights','reengagement','user_reminders','show_details'] LOOP
   IF p_data ? key AND jsonb_typeof(p_data->key)<>'boolean' THEN RAISE invalid_parameter_value; END IF;
  END LOOP;
  p:=jsonb_populate_record(p,p_data);
  IF NOT EXISTS(SELECT FROM pg_timezone_names WHERE name=p.timezone) OR p.paused_until>now()+interval '7 days 1 minute' THEN RAISE invalid_parameter_value; END IF;
  UPDATE notification_preferences SET push_enabled=p.push_enabled,in_app_enabled=p.in_app_enabled,
   quiet_enabled=p.quiet_enabled,quiet_start=p.quiet_start,quiet_end=p.quiet_end,timezone=p.timezone,
   inventory_alerts=p.inventory_alerts,capture_reminders=p.capture_reminders,weekly_recap=p.weekly_recap,
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

CREATE FUNCTION public.findez_notification_quiet(p notification_preferences,p_at timestamptz) RETURNS boolean
LANGUAGE sql STABLE SET search_path=public AS $$
 SELECT p.quiet_enabled AND (p.quiet_start=p.quiet_end OR
 CASE WHEN p.quiet_start<p.quiet_end THEN minute>=p.quiet_start AND minute<p.quiet_end
 ELSE minute>=p.quiet_start OR minute<p.quiet_end END)
 FROM (SELECT extract(hour from p_at AT TIME ZONE p.timezone)::int*60+extract(minute from p_at AT TIME ZONE p.timezone)::int AS minute) m
$$;

CREATE FUNCTION public.findez_notification_condition(r jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
 SELECT coalesce((r->>'quantity')::numeric>=0 AND ((r->>'quantity')::numeric=0 OR
 (r->'reorder_enabled'='true'::jsonb AND (r->>'quantity')::numeric<=(r->>'reorder_threshold')::numeric)),false)
$$;

CREATE FUNCTION public.findez_notification_stock_rules(p_actor uuid,p_rules jsonb,p_import boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE entry jsonb; entity uuid; threshold_value integer; inv uuid; result jsonb:='{}';
BEGIN
 IF jsonb_typeof(p_rules)<>'array' OR jsonb_array_length(p_rules)>500 THEN RAISE invalid_parameter_value; END IF;
 FOR entry IN SELECT value FROM jsonb_array_elements(p_rules) LOOP
  entity:=(entry->>'item_id')::uuid; threshold_value:=(entry->>'threshold')::integer;
  SELECT inventory_id INTO inv FROM items WHERE item_id=entity;
  IF inv IS NULL OR findez_inventory_role(inv,p_actor) IS NULL THEN
   IF p_import THEN CONTINUE; ELSE RAISE insufficient_privilege; END IF;
  END IF;
  IF threshold_value<0 THEN RAISE invalid_parameter_value; END IF;
  IF p_import THEN
   IF threshold_value IS NOT NULL THEN
    INSERT INTO notification_stock_rules(user_id,item_id,threshold) VALUES(p_actor,entity,threshold_value) ON CONFLICT DO NOTHING;
   END IF;
  ELSE
   -- Null is a tombstone: another device's old local value cannot restore it.
   INSERT INTO notification_stock_rules(user_id,item_id,threshold) VALUES(p_actor,entity,threshold_value)
   ON CONFLICT(user_id,item_id) DO UPDATE SET threshold=excluded.threshold,updated_at=now();
  END IF;
  IF EXISTS(SELECT FROM notification_stock_rules WHERE user_id=p_actor AND item_id=entity) THEN
   result:=result||jsonb_build_object(entity::text,(SELECT threshold FROM notification_stock_rules WHERE user_id=p_actor AND item_id=entity));
  END IF;
 END LOOP;
 RETURN result;
END $$;

CREATE FUNCTION public.findez_notification_item_condition(p_actor uuid,r jsonb) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT findez_notification_condition(r) OR coalesce((r->>'quantity')::numeric>=0 AND
 (r->>'quantity')::numeric<=(SELECT threshold FROM notification_stock_rules WHERE user_id=p_actor AND item_id=(r->>'item_id')::uuid),false)
$$;

CREATE OR REPLACE FUNCTION public.findez_personalization_destination(p_actor uuid,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; r jsonb;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id AND user_id=p_actor;
 IF NOT FOUND OR findez_inventory_role(n.inventory_id,p_actor) IS NULL THEN RETURN NULL; END IF;
 IF n.entity_type='item' THEN SELECT to_jsonb(i) INTO r FROM items i WHERE item_id=n.entity_id AND inventory_id=n.inventory_id;
 ELSE SELECT to_jsonb(i) INTO r FROM capture_reviews i WHERE review_id=n.entity_id AND inventory_id=n.inventory_id; END IF;
 IF r IS NULL THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('notification_id',n.id,'inventory_id',n.inventory_id,'entity_type',n.entity_type,'entity_id',n.entity_id,
  'active',CASE WHEN n.entity_type='review' THEN r->>'status'='pending' ELSE findez_notification_item_condition(p_actor,r) END);
END $$;

CREATE FUNCTION public.findez_notification_observe() RETURNS trigger
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
 WHERE entity_type=kind AND entity_id=entity AND (TG_OP='DELETE' OR inventory_id IS DISTINCT FROM inv OR
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
  now()+CASE WHEN kind='review' THEN interval '1 hour' ELSE interval '0' END) ON CONFLICT DO NOTHING;
 IF FOUND THEN PERFORM findez_notification_metric('candidate',category); ELSE PERFORM findez_notification_metric('duplicate',category); END IF;
 END LOOP;
 RETURN coalesce(NEW,OLD);
END $$;
CREATE TRIGGER notification_policy_items AFTER INSERT OR UPDATE OR DELETE ON public.items FOR EACH ROW EXECUTE FUNCTION findez_notification_observe();
CREATE TRIGGER notification_policy_reviews AFTER INSERT OR UPDATE OR DELETE ON public.capture_reviews FOR EACH ROW EXECUTE FUNCTION findez_notification_observe();

-- Retain behavioral telemetry but let only the policy observer enqueue alerts.
DO $$ DECLARE definition text; start_at int; end_at int; BEGIN
 definition:=pg_get_functiondef('public.findez_personalization_observe()'::regprocedure);
 start_at:=strpos(definition,' IF category IS NOT NULL AND category=ANY(p.categories) THEN');
 end_at:=strpos(definition,' EXCEPTION WHEN OTHERS');
 IF start_at=0 OR end_at<=start_at THEN RAISE EXCEPTION 'Unexpected 081 observer; review before migrating'; END IF;
 definition:=substr(definition,1,start_at-1)||substr(definition,end_at);
 -- The legacy observer must not resolve zero-stock candidates just because
 -- they have no configured reorder threshold. Policy owns all queue state.
 definition:=regexp_replace(definition,'UPDATE public.personalization_notifications[^;]*;','','g');
 EXECUTE definition;
END $$;

DO $$ DECLARE signature regprocedure; definition text; BEGIN
 FOR signature IN SELECT oid::regprocedure FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('findez_personalization_memory_reset','findez_personalization_change') LOOP
  definition:=pg_get_functiondef(signature);
  definition:=regexp_replace(definition,'DELETE FROM public.personalization_notifications WHERE user_id=([^;]+);','DELETE FROM public.personalization_notifications WHERE policy_version=0 AND user_id=\1;','g');
  EXECUTE definition;
 END LOOP;
END $$;

CREATE FUNCTION public.findez_notification_eligible(p_id uuid,p_at timestamptz) RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications;p notification_preferences;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND OR n.policy_version<>1 OR n.state NOT IN ('pending','sending') THEN RETURN 'inactive'; END IF;
 IF n.expires_at<=p_at THEN RETURN 'expired'; END IF;
 IF (findez_personalization_destination(n.user_id,n.id)->'active') IS DISTINCT FROM 'true'::jsonb THEN RETURN 'stale'; END IF;
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
 IF NOT FOUND OR NOT p.push_enabled THEN RETURN 'push_off'; END IF;
 IF (n.category='low_stock' AND NOT p.inventory_alerts) OR (n.category='scan_review' AND NOT p.capture_reminders) THEN RETURN 'category_off'; END IF;
 IF p.paused_until>p_at THEN RETURN 'paused'; END IF;
 IF findez_notification_quiet(p,p_at) THEN RETURN 'quiet_hours'; END IF;
 IF n.scheduled_for>p_at THEN RETURN 'scheduled'; END IF;
 IF NOT EXISTS(SELECT FROM push_devices WHERE user_id=n.user_id AND enabled AND personalization_destinations AND updated_at>p_at-interval '90 days') THEN RETURN 'no_device'; END IF;
 RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_candidates(p_limit int DEFAULT 50) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(r),'[]') FROM (SELECT id FROM personalization_notifications
 WHERE policy_version=1 AND state='pending' AND scheduled_for<=now()
 ORDER BY critical DESC,scheduled_for,id LIMIT least(100,greatest(1,p_limit))) r
$$;

CREATE OR REPLACE FUNCTION public.findez_personalization_claim(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications;p notification_preferences;reason text;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND THEN RETURN NULL; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(n.user_id::text,193));
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id FOR UPDATE;
 IF n.state<>'pending' THEN RETURN NULL; END IF;
 reason:=findez_notification_eligible(p_id,now());
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
 IF reason IS NULL THEN
  IF (SELECT count(*) FROM notification_delivery_attempts WHERE user_id=n.user_id AND state<>'cancelled'
   AND reserved_at>=date_trunc('day',now() AT TIME ZONE p.timezone) AT TIME ZONE p.timezone)>=2 THEN reason:='daily_cap';
  ELSIF (SELECT count(*) FROM notification_delivery_attempts WHERE user_id=n.user_id AND state<>'cancelled' AND reserved_at>now()-interval '7 days')>=5 THEN reason:='weekly_cap';
  ELSIF NOT n.critical AND EXISTS(SELECT FROM notification_delivery_attempts WHERE user_id=n.user_id AND NOT critical AND state<>'cancelled' AND reserved_at>now()-interval '24 hours') THEN reason:='noncritical_cap';
  ELSIF n.category='scan_review' AND EXISTS(SELECT FROM notification_delivery_attempts WHERE user_id=n.user_id AND category='scan_review' AND state<>'cancelled' AND reserved_at>now()-interval '7 days') THEN reason:='category_cap'; END IF;
 END IF;
 IF reason IS NOT NULL THEN
  UPDATE personalization_notifications SET suppression_reason=reason,
   state=CASE WHEN reason IN ('expired','stale','category_off','inactive') THEN 'resolved' ELSE state END,
   scheduled_for=greatest(scheduled_for,now()+interval '5 minutes') WHERE id=p_id;
  PERFORM findez_notification_metric(reason,n.category);
  RETURN NULL;
 END IF;
 INSERT INTO notification_delivery_attempts(notification_id,user_id,category,critical) VALUES(n.id,n.user_id,n.category,n.critical)
 ON CONFLICT(notification_id) DO UPDATE SET state='reserved',reserved_at=now(),finished_at=NULL
 WHERE notification_delivery_attempts.state='cancelled' AND notification_delivery_attempts.started_at IS NULL;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE personalization_notifications SET state='sending',suppression_reason=NULL WHERE id=p_id;
 PERFORM findez_notification_metric('queued',n.category);
 RETURN findez_personalization_destination(n.user_id,n.id)||jsonb_build_object('user_id',n.user_id,'category',n.category,'show_details',p.show_details);
END $$;

CREATE FUNCTION public.findez_notification_begin_attempt(p_id uuid,p_device text DEFAULT NULL,p_revision bigint DEFAULT NULL) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; reason text; a notification_delivery_attempts; p notification_preferences;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND THEN RETURN false; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(n.user_id::text,193));
 SELECT * INTO a FROM notification_delivery_attempts WHERE notification_id=p_id FOR UPDATE;
 IF NOT FOUND OR a.state NOT IN ('reserved','started') OR a.attempts>=3 THEN RETURN false; END IF;
 reason:=findez_notification_eligible(p_id,now());
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
 IF p_revision IS NOT NULL AND p.revision IS DISTINCT FROM p_revision THEN reason:='preferences_changed'; END IF;
 IF p_device IS NOT NULL AND NOT EXISTS(SELECT FROM push_devices WHERE device_token=p_device AND user_id=n.user_id AND enabled AND personalization_destinations) THEN reason:='no_device'; END IF;
 -- The actual first provider attempt owns the local day, including a claim
 -- immediately before midnight whose request starts just after midnight.
 IF reason IS NULL AND a.started_at IS NULL AND
  (SELECT count(*) FROM notification_delivery_attempts WHERE user_id=n.user_id AND id<>a.id AND state<>'cancelled'
   AND reserved_at>=date_trunc('day',now() AT TIME ZONE p.timezone) AT TIME ZONE p.timezone)>=2 THEN reason:='daily_cap'; END IF;
 IF reason IS NOT NULL THEN
  IF a.started_at IS NULL THEN
   UPDATE notification_delivery_attempts SET state='cancelled',finished_at=now() WHERE id=a.id;
  ELSE UPDATE notification_delivery_attempts SET state='failed',finished_at=now(),error_code='eligibility_changed' WHERE id=a.id; END IF;
  UPDATE personalization_notifications SET state=CASE WHEN a.started_at IS NULL AND reason IN ('quiet_hours','paused','push_off','no_device','scheduled','preferences_changed','daily_cap') THEN 'pending' ELSE 'resolved' END,
   scheduled_for=greatest(scheduled_for,now()+interval '5 minutes'),suppression_reason=reason WHERE id=p_id;
  RETURN false;
 END IF;
 UPDATE notification_delivery_attempts SET state='started',reserved_at=CASE WHEN started_at IS NULL THEN now() ELSE reserved_at END,started_at=coalesce(started_at,now()),attempts=attempts+1 WHERE id=a.id;
 UPDATE personalization_notifications SET attempted_at=coalesce(attempted_at,now()) WHERE id=p_id;
 RETURN true;
END $$;

CREATE FUNCTION public.findez_notification_cancel_reservation(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 UPDATE notification_delivery_attempts SET state='cancelled',finished_at=now()
 WHERE notification_id=p_id AND state='reserved' AND started_at IS NULL;
 IF FOUND THEN UPDATE personalization_notifications SET state='pending',scheduled_for=now()+interval '5 minutes',suppression_reason='cancelled_before_send' WHERE id=p_id AND state='sending'; END IF;
END $$;

CREATE FUNCTION public.findez_notification_content(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications;p notification_preferences;r jsonb;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND OR findez_notification_eligible(p_id,now()) IS NOT NULL THEN RETURN NULL; END IF;
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
 IF n.category='low_stock' AND p.show_details THEN
  SELECT to_jsonb(i) INTO r FROM items i WHERE item_id=n.entity_id AND inventory_id=n.inventory_id;
  RETURN jsonb_build_object('revision',p.revision,'title',left(coalesce(r->>'name','Inventory item'),80),
   'body','Recorded quantity: '||(r->>'quantity')||'. Open your inventory to review.');
 END IF;
 RETURN jsonb_build_object('revision',p.revision,'title','FindEZ','body',CASE WHEN n.category='scan_review' THEN 'A photo review is waiting for you.' ELSE 'An inventory item needs your attention.' END);
END $$;

CREATE FUNCTION public.findez_notification_finish(p_id uuid,p_result text,p_error text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE category_name text;
BEGIN
 IF p_result NOT IN ('accepted','unknown','failed') OR (p_error IS NOT NULL AND p_error !~ '^[a-z_]{1,40}$') THEN RAISE invalid_parameter_value; END IF;
 UPDATE notification_delivery_attempts SET state=p_result,error_code=p_error,finished_at=now()
 WHERE notification_id=p_id AND state='started' RETURNING category INTO category_name;
 IF NOT FOUND THEN RETURN; END IF;
 UPDATE personalization_notifications SET state=CASE WHEN state IN ('resolved','dismissed') THEN state WHEN p_result='accepted' THEN 'accepted' ELSE 'unknown' END,
  accepted_at=CASE WHEN p_result='accepted' THEN now() ELSE accepted_at END WHERE id=p_id;
 PERFORM findez_notification_metric(p_result,category_name);
END $$;

CREATE FUNCTION public.findez_notification_inbox(p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(r ORDER BY r.created_at DESC),'[]') FROM (
 SELECT n.id,'personalization' AS action,n.category,n.created_at,n.read_at IS NOT NULL AS is_read,
 CASE WHEN category='scan_review' THEN 'A photo review is waiting for you.' ELSE 'An inventory item needs your attention.' END AS display_text
 FROM personalization_notifications n JOIN notification_preferences p ON p.user_id=n.user_id
 WHERE n.user_id=p_actor AND n.policy_version=1 AND p.in_app_enabled AND n.state NOT IN ('resolved','dismissed')
 AND n.expires_at>now() AND (findez_personalization_destination(p_actor,n.id)->'active')='true'::jsonb
 AND ((n.category='low_stock' AND p.inventory_alerts) OR (n.category='scan_review' AND p.capture_reminders))
 ORDER BY n.created_at DESC LIMIT 100) r
$$;

CREATE FUNCTION public.findez_notification_inbox_action(p_actor uuid,p_action text,p_id uuid DEFAULT NULL) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE changed int;
BEGIN
 IF p_action NOT IN ('read','dismiss') THEN RAISE invalid_parameter_value; END IF;
 UPDATE personalization_notifications SET read_at=coalesce(read_at,now()),
 state=CASE WHEN p_action='dismiss' THEN 'dismissed' ELSE state END,
 dismissed_at=CASE WHEN p_action='dismiss' THEN coalesce(dismissed_at,now()) ELSE dismissed_at END
 WHERE user_id=p_actor AND policy_version=1 AND (p_id IS NULL OR id=p_id)
 AND (findez_personalization_destination(p_actor,id)) IS NOT NULL;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed>0 THEN PERFORM findez_notification_metric(p_action,'inbox'); END IF;
 RETURN changed;
END $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_feedback(p_actor uuid,p_id uuid,p_outcome text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id AND user_id=p_actor FOR UPDATE;
 IF NOT FOUND OR findez_personalization_destination(p_actor,p_id) IS NULL THEN RETURN false; END IF;
 IF p_outcome='delivered' THEN
  IF n.accepted_at IS NULL THEN RETURN false; END IF;
  UPDATE personalization_notifications SET delivered_at=coalesce(delivered_at,now()) WHERE id=p_id;
 ELSIF p_outcome='opened' THEN UPDATE personalization_notifications SET opened_at=coalesce(opened_at,now()),read_at=coalesce(read_at,now()) WHERE id=p_id;
 ELSIF p_outcome='dismissed' THEN UPDATE personalization_notifications SET dismissed_at=coalesce(dismissed_at,now()),state='dismissed',read_at=coalesce(read_at,now()) WHERE id=p_id;
 ELSE RAISE invalid_parameter_value; END IF;
 PERFORM findez_notification_metric(p_outcome,n.category);
 RETURN true;
END $$;

CREATE FUNCTION public.findez_notification_cleanup() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 UPDATE personalization_notifications SET state='resolved',suppression_reason='expired' WHERE policy_version=1 AND state='pending' AND expires_at<=now();
 -- Crash before provider call releases its reservation; an ambiguous started send
 -- consumes its slot and must never be blindly replayed.
 UPDATE notification_delivery_attempts SET state='cancelled',finished_at=now() WHERE state='reserved' AND reserved_at<now()-interval '15 minutes';
 UPDATE personalization_notifications n SET state='pending',scheduled_for=now() WHERE policy_version=1 AND state IN ('sending','unknown')
 AND EXISTS(SELECT FROM notification_delivery_attempts a WHERE a.notification_id=n.id AND a.state='cancelled' AND a.started_at IS NULL);
 UPDATE notification_delivery_attempts SET state='unknown',finished_at=now(),error_code='worker_interrupted' WHERE state='started' AND reserved_at<now()-interval '15 minutes';
 DELETE FROM notification_delivery_attempts WHERE reserved_at<now()-interval '90 days';
 DELETE FROM notification_policy_metrics WHERE day<current_date-90;
 DELETE FROM notification_inbox_hidden WHERE hidden_at<now()-interval '90 days';
END $$;

CREATE FUNCTION public.findez_notification_action_metric() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.policy_version=1 AND NEW.completed_at IS NOT NULL AND OLD.completed_at IS NULL THEN
  PERFORM findez_notification_metric('action_completed',NEW.category);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER notification_policy_action AFTER UPDATE ON personalization_notifications FOR EACH ROW EXECUTE FUNCTION findez_notification_action_metric();

DO $$ DECLARE f regprocedure; BEGIN
 FOR f IN SELECT oid::regprocedure FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE 'findez_notification_%' LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

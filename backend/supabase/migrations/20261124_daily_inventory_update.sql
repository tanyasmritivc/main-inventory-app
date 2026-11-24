BEGIN;
SET LOCAL lock_timeout='5s';
-- An account update also exists for a new account without an inventory.
ALTER TABLE public.personalization_notifications ALTER COLUMN inventory_id DROP NOT NULL,
 DROP CONSTRAINT personalization_notifications_category_check,
 ADD CHECK(category IN ('low_stock','scan_review','expiry','locate_item','first_item','add_item','snap','daily_inventory')),
 DROP CONSTRAINT personalization_notifications_entity_type_check,
 ADD CHECK(entity_type IN ('item','review','inventory','account')),
 ADD CHECK(CASE WHEN category='daily_inventory' THEN entity_type='account' AND inventory_id IS NULL
                ELSE entity_type<>'account' AND inventory_id IS NOT NULL END);

-- The scheduled date and end of day are local civil dates, including on DST changes.
CREATE FUNCTION public.findez_seed_daily_inventory(p_limit int, p_at timestamptz DEFAULT now()) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE made int;
BEGIN
 WITH due AS (
  SELECT p.user_id,local_day,p.timezone FROM notification_preferences p
  CROSS JOIN LATERAL (SELECT (p_at AT TIME ZONE p.timezone)::date AS local_day) clock
  WHERE p.push_enabled AND p.inventory_alerts AND (p.paused_until IS NULL OR p.paused_until<=p_at)
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

CREATE FUNCTION public.findez_daily_inventory_summary(p_user uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT CASE count(*) WHEN 0 THEN 'Your personal inventory has no recorded items yet.'
   WHEN 1 THEN 'Your personal inventory has 1 recorded item.'
   ELSE format('Your personal inventory has %s recorded items.',count(*)) END
 FROM items i JOIN app_inventories v ON v.inventory_id=i.inventory_id
 WHERE v.owner_user_id=p_user AND v.team_id IS NULL AND findez_inventory_role(v.inventory_id,p_user) IS NOT NULL
$$;
REVOKE ALL ON FUNCTION public.findez_seed_daily_inventory(int,timestamptz),public.findez_daily_inventory_summary(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_seed_daily_inventory(int,timestamptz),public.findez_daily_inventory_summary(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_personalization_destination(p_actor uuid,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; r jsonb;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id AND user_id=p_actor;
 IF FOUND AND n.category='daily_inventory' THEN
  RETURN jsonb_build_object('notification_id',n.id,'entity_type','account','active',
   EXISTS(SELECT FROM notification_preferences p WHERE p.user_id=p_actor AND p.inventory_alerts
    AND n.condition_key='daily-inventory/'||(now() AT TIME ZONE p.timezone)::date::text));
 END IF;
 IF NOT FOUND OR findez_inventory_role(n.inventory_id,p_actor) IS NULL THEN RETURN NULL; END IF;
 IF n.category IN ('expiry','locate_item','first_item','add_item','snap') THEN
  RETURN jsonb_build_object('notification_id',n.id,'inventory_id',n.inventory_id,
    'entity_type',n.entity_type,'entity_id',n.entity_id,'quick_action',n.category,
    'active',findez_tip_active(p_actor,n.inventory_id,n.category,n.entity_id));
 END IF;
 IF n.entity_type='item' THEN SELECT to_jsonb(i) INTO r FROM items i WHERE item_id=n.entity_id AND inventory_id=n.inventory_id;
 ELSE SELECT to_jsonb(i) INTO r FROM capture_reviews i WHERE review_id=n.entity_id AND inventory_id=n.inventory_id; END IF;
 IF r IS NULL THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('notification_id',n.id,'inventory_id',n.inventory_id,'entity_type',n.entity_type,'entity_id',n.entity_id,
  'active',CASE WHEN n.entity_type='review' THEN r->>'status'='pending' ELSE findez_notification_item_condition(p_actor,r) END);
END $$;

CREATE OR REPLACE FUNCTION public.findez_notification_content(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications;p notification_preferences;r jsonb;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND OR findez_notification_eligible(p_id,now()) IS NOT NULL THEN RETURN NULL; END IF;
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
 IF n.category='daily_inventory' THEN
  RETURN jsonb_build_object('revision',p.revision,'title','Daily inventory update','body',
   CASE WHEN p.show_details THEN findez_daily_inventory_summary(n.user_id)
    WHEN p.in_app_enabled THEN 'Open FindEZ to see your personal inventory summary.'
    ELSE 'Your daily inventory check-in is ready.' END);
 END IF;
 IF findez_tip_text(n.category) IS NOT NULL THEN
  RETURN jsonb_build_object('revision',p.revision,'title','FindEZ','body',findez_tip_text(n.category));
 END IF;
 IF n.category='low_stock' AND p.show_details THEN
  SELECT to_jsonb(i) INTO r FROM items i WHERE item_id=n.entity_id AND inventory_id=n.inventory_id;
  RETURN jsonb_build_object('revision',p.revision,'title',left(coalesce(r->>'name','Inventory item'),80),
   'body','Recorded quantity: '||(r->>'quantity')||'. Open your inventory to review.');
 END IF;
 RETURN jsonb_build_object('revision',p.revision,'title','FindEZ','body',CASE WHEN n.category='scan_review' THEN 'A photo review is waiting for you.' WHEN n.critical THEN 'An item reached zero recorded stock. Tap to review it.' ELSE 'An item reached its low-stock threshold. Tap to review it.' END);
END $$;

CREATE OR REPLACE FUNCTION public.findez_notification_inbox(p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(r ORDER BY r.created_at DESC),'[]') FROM (
 SELECT n.id,CASE WHEN n.category='daily_inventory' THEN 'daily_inventory' ELSE 'personalization' END AS action,n.category,n.created_at,n.read_at IS NOT NULL AS is_read,
 CASE WHEN category='daily_inventory' THEN findez_daily_inventory_summary(p_actor) WHEN findez_tip_text(category) IS NOT NULL THEN findez_tip_text(category) WHEN category='scan_review' THEN 'A photo review is waiting for you.' ELSE 'An inventory item needs your attention.' END AS display_text
 FROM personalization_notifications n JOIN notification_preferences p ON p.user_id=n.user_id
 WHERE n.user_id=p_actor AND n.policy_version=1 AND p.in_app_enabled AND n.state NOT IN ('resolved','dismissed')
 AND n.expires_at>now() AND (findez_personalization_destination(p_actor,n.id)->'active')='true'::jsonb
 AND ((n.category IN ('expiry','locate_item','low_stock','daily_inventory') AND p.inventory_alerts) OR (n.category='scan_review' AND p.capture_reminders) OR (n.category IN ('first_item','add_item','snap') AND p.reengagement))
 ORDER BY n.created_at DESC LIMIT 100) r
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
 IF reason IS NULL AND n.category<>'daily_inventory' THEN
  IF (SELECT count(*) FROM notification_delivery_attempts WHERE user_id=n.user_id AND category<>'daily_inventory' AND state<>'cancelled'
   AND reserved_at>=date_trunc('day',now() AT TIME ZONE p.timezone) AT TIME ZONE p.timezone)>=2 THEN reason:='daily_cap';
  ELSIF (SELECT count(*) FROM notification_delivery_attempts WHERE user_id=n.user_id AND category<>'daily_inventory' AND state<>'cancelled' AND reserved_at>now()-interval '7 days')>=5 THEN reason:='weekly_cap';
  ELSIF NOT n.critical AND EXISTS(SELECT FROM notification_delivery_attempts WHERE user_id=n.user_id AND category<>'daily_inventory' AND NOT critical AND state<>'cancelled' AND reserved_at>now()-interval '24 hours') THEN reason:='noncritical_cap';
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

CREATE OR REPLACE FUNCTION public.findez_notification_begin_attempt(p_id uuid,p_device text DEFAULT NULL,p_revision bigint DEFAULT NULL) RETURNS boolean
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
 IF reason IS NULL AND n.category<>'daily_inventory' AND a.started_at IS NULL AND
  (SELECT count(*) FROM notification_delivery_attempts WHERE user_id=n.user_id AND category<>'daily_inventory' AND id<>a.id AND state<>'cancelled'
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

NOTIFY pgrst,'reload schema';
COMMIT;

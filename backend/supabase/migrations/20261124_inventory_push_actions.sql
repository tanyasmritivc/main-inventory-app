-- Extend the existing queue. Existing opt-outs, limits and device registrations survive.
BEGIN;
SET LOCAL lock_timeout='5s';
ALTER TABLE public.push_devices ADD COLUMN inventory_push_actions boolean NOT NULL DEFAULT false;
-- A signed-in, OS-authorized iPhone registers through /push/devices. An
-- explicitly saved account preference (revision > 0) always wins on relaunch.
CREATE FUNCTION public.findez_initialize_phone_alerts() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.enabled AND NEW.personalization_destinations THEN
  INSERT INTO notification_preferences(user_id,push_enabled,revision)
  VALUES(NEW.user_id,true,1) ON CONFLICT(user_id) DO UPDATE
  SET push_enabled=true, revision=1, updated_at=now()
  WHERE notification_preferences.revision=0 AND NOT notification_preferences.push_enabled;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_initialize_phone_alerts() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER notification_authorized_registration AFTER INSERT OR UPDATE ON public.push_devices
 FOR EACH ROW EXECUTE FUNCTION public.findez_initialize_phone_alerts();

ALTER TABLE public.notification_preferences DROP CONSTRAINT notification_preferences_reengagement_check;
ALTER TABLE public.personalization_notifications DROP CONSTRAINT personalization_notifications_category_check,
 ADD CHECK (category IN ('low_stock','scan_review','expiry','locate_item','first_item','add_item','snap'));
ALTER TABLE public.personalization_notifications DROP CONSTRAINT personalization_notifications_entity_type_check,
 ADD CHECK (entity_type IN ('item','review','inventory'));

CREATE FUNCTION public.findez_tip_active(p_user uuid,p_inventory uuid,p_category text,p_entity uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS (
  SELECT FROM app_inventories inv JOIN notification_preferences p ON p.user_id=p_user
  WHERE inv.inventory_id=p_inventory AND inv.team_id IS NULL AND inv.owner_user_id=p_user
   AND findez_inventory_role(p_inventory,p_user) IN ('owner','editor')
   AND CASE WHEN p_category IN ('expiry','locate_item') THEN p.inventory_alerts AND EXISTS (
     SELECT FROM items i WHERE i.item_id=p_entity AND i.inventory_id=p_inventory
      AND CASE WHEN p_category='expiry' THEN i.expires_on BETWEEN (now() AT TIME ZONE p.timezone)::date AND (now() AT TIME ZONE p.timezone)::date+7
               ELSE nullif(btrim(i.location),'') IS NULL AND i.space_id IS NULL END)
   ELSE p.reengagement AND p_entity=p_inventory AND
    CASE WHEN p_category='first_item' THEN NOT EXISTS(SELECT FROM items WHERE inventory_id=p_inventory)
         WHEN p_category IN ('add_item','snap') THEN EXISTS(SELECT FROM items WHERE inventory_id=p_inventory)
            AND NOT EXISTS(SELECT FROM items WHERE inventory_id=p_inventory AND created_at>now()-interval '3 days')
         ELSE false END END)
$$;

CREATE OR REPLACE FUNCTION public.findez_personalization_destination(p_actor uuid,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; r jsonb;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id AND user_id=p_actor;
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
  now()+CASE WHEN kind='review' THEN interval '1 hour' ELSE interval '0' END) ON CONFLICT DO NOTHING;
 IF FOUND THEN PERFORM findez_notification_metric('candidate',category); ELSE PERFORM findez_notification_metric('duplicate',category); END IF;
 END LOOP;
 RETURN coalesce(NEW,OLD);
END $$;

CREATE FUNCTION public.findez_tip_text(p_category text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE p_category
  WHEN 'expiry' THEN 'An item is approaching its recorded expiry date. Tap to check it.'
  WHEN 'locate_item' THEN 'An item has no saved location. Tap to record where it belongs.'
  WHEN 'first_item' THEN 'Start your inventory with one item. Tap to add it.'
  WHEN 'add_item' THEN 'Have something new on your shelf? Tap to add an item.'
  WHEN 'snap' THEN 'Capture a shelf in one photo. Tap to open Scan.'
 END
$$;

CREATE OR REPLACE FUNCTION public.findez_notification_content(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications;p notification_preferences;r jsonb;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND OR findez_notification_eligible(p_id,now()) IS NOT NULL THEN RETURN NULL; END IF;
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
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
 SELECT n.id,'personalization' AS action,n.category,n.created_at,n.read_at IS NOT NULL AS is_read,
 CASE WHEN findez_tip_text(category) IS NOT NULL THEN findez_tip_text(category) WHEN category='scan_review' THEN 'A photo review is waiting for you.' ELSE 'An inventory item needs your attention.' END AS display_text
 FROM personalization_notifications n JOIN notification_preferences p ON p.user_id=n.user_id
 WHERE n.user_id=p_actor AND n.policy_version=1 AND p.in_app_enabled AND n.state NOT IN ('resolved','dismissed')
 AND n.expires_at>now() AND (findez_personalization_destination(p_actor,n.id)->'active')='true'::jsonb
 AND ((n.category IN ('expiry','locate_item','low_stock') AND p.inventory_alerts) OR (n.category='scan_review' AND p.capture_reminders) OR (n.category IN ('first_item','add_item','snap') AND p.reengagement))
 ORDER BY n.created_at DESC LIMIT 100) r
$$;

-- One actionable suggestion at a time per opted-in account. Time-sensitive stock
-- events retain their existing independent enqueue path and higher priority.
CREATE FUNCTION public.findez_seed_inventory_pushes(p_limit int DEFAULT 50) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inserted int;
BEGIN
 WITH choices AS (
  SELECT p.user_id,inv.inventory_id,target.* FROM notification_preferences p
  JOIN app_inventories inv ON inv.owner_user_id=p.user_id AND inv.team_id IS NULL AND inv.is_default
  JOIN LATERAL (
   SELECT * FROM (
    SELECT CASE WHEN i.expires_on BETWEEN (now() AT TIME ZONE p.timezone)::date AND (now() AT TIME ZONE p.timezone)::date+7
      THEN 'expiry' ELSE 'locate_item' END AS category,
      'item' AS kind,i.item_id AS entity,coalesce(i.expires_on::text,'') AS occurrence
    FROM items i WHERE p.inventory_alerts AND i.inventory_id=inv.inventory_id AND
     (i.expires_on BETWEEN (now() AT TIME ZONE p.timezone)::date AND (now() AT TIME ZONE p.timezone)::date+7
      OR (nullif(btrim(i.location),'') IS NULL AND i.space_id IS NULL AND i.created_at<now()-interval '2 days'))
    UNION ALL
    SELECT CASE WHEN NOT EXISTS(SELECT FROM items WHERE inventory_id=inv.inventory_id) THEN 'first_item'
      WHEN EXISTS(SELECT FROM personalization_notifications n WHERE n.user_id=p.user_id AND n.category='snap'
        AND n.created_at>now()-interval '8 days') THEN 'add_item' ELSE 'snap' END,
      'inventory',inv.inventory_id,to_char(now() AT TIME ZONE p.timezone,'IYYY-IW')
    WHERE p.reengagement AND EXISTS(SELECT FROM push_devices WHERE user_id=p.user_id AND inventory_push_actions AND enabled)
     AND NOT EXISTS(SELECT FROM items WHERE inventory_id=inv.inventory_id AND created_at>now()-interval '3 days')
   ) t
   WHERE NOT EXISTS(SELECT FROM personalization_notifications n WHERE n.user_id=p.user_id
     AND n.condition_key=concat_ws('/','inventory-tip',t.category,t.entity,t.occurrence))
   ORDER BY CASE t.category WHEN 'expiry' THEN 0 WHEN 'locate_item' THEN 2 ELSE 1 END,t.entity LIMIT 1
  ) target ON true
  WHERE p.push_enabled AND (p.paused_until IS NULL OR p.paused_until<=now())
   AND NOT findez_notification_quiet(p,now())
   AND findez_inventory_role(inv.inventory_id,p.user_id) IN ('owner','editor')
   AND EXISTS(SELECT FROM push_devices WHERE user_id=p.user_id AND enabled AND personalization_destinations AND updated_at>now()-interval '90 days')
   AND NOT EXISTS(SELECT FROM personalization_notifications n WHERE n.user_id=p.user_id
     AND n.category IN ('expiry','locate_item','first_item','add_item','snap')
     AND n.created_at>now()-interval '3 days')
  ORDER BY p.user_id LIMIT least(100,greatest(1,p_limit))
 )
 INSERT INTO personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key,policy_version)
 SELECT user_id,inventory_id,category,kind,entity,concat_ws('/','inventory-tip',category,entity,occurrence),1 FROM choices
 ON CONFLICT DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 RETURN inserted;
END $$;
REVOKE ALL ON FUNCTION public.findez_seed_inventory_pushes(int),public.findez_tip_active(uuid,uuid,text,uuid),public.findez_tip_text(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_seed_inventory_pushes(int),public.findez_tip_active(uuid,uuid,text,uuid),public.findez_tip_text(text) TO service_role;
-- Explicit account self-test; one device and one attempt per minute.
ALTER TABLE public.push_devices ADD COLUMN last_test_push_at timestamptz;
CREATE FUNCTION public.findez_claim_test_device(p_user uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE device push_devices;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_user::text,193));
 IF EXISTS (SELECT FROM push_devices WHERE user_id=p_user AND last_test_push_at>now()-interval '1 minute') THEN RETURN NULL; END IF;
 SELECT * INTO device FROM push_devices WHERE user_id=p_user AND enabled AND updated_at>now()-interval '90 days'
 ORDER BY updated_at DESC,device_token LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE push_devices SET last_test_push_at=now() WHERE device_token=device.device_token;
 RETURN jsonb_build_object('environment',device.environment,'device_token',device.device_token);
END $$;
REVOKE ALL ON FUNCTION public.findez_claim_test_device(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_claim_test_device(uuid) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

BEGIN;
SET LOCAL lock_timeout='5s';
-- Keep the selected target with its existing notification. A tap must never
-- rediscover a different item because the inventory changed after delivery.
ALTER TABLE public.personalization_notifications ADD COLUMN daily_focus jsonb;

CREATE FUNCTION public.findez_choose_daily_focus(p_user uuid,p_date date,p_id uuid)
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
   FROM records i LEFT JOIN notification_stock_rules rule ON rule.user_id=p_user AND rule.item_id=i.item_id
   CROSS JOIN LATERAL (VALUES
     ('low_stock',1,i.quantity>=0 AND ((i.reorder_enabled AND i.quantity<=i.reorder_threshold) OR i.quantity<=rule.threshold)),
     ('expiry',2,i.expires_on BETWEEN p_date AND p_date+7),
     ('location',3,nullif(btrim(i.location),'') IS NULL AND i.space_id IS NULL),
     ('quantity',4,i.quantity IS NULL OR i.quantity<0),
     ('progress',5,i.added_on=p_date),
     ('rediscover',8,true)
   ) choice(kind,priority,eligible) WHERE choice.eligible
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
 ORDER BY h.shown NULLS FIRST,c.priority,target.shown NULLS FIRST,c.recency DESC NULLS LAST,c.id LIMIT 1
$$;

CREATE FUNCTION public.findez_assign_daily_focus() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE local_date date;
BEGIN
 IF TG_OP='INSERT' OR (NEW.state='sending' AND OLD.state='pending' AND NEW.attempted_at IS NULL) THEN
   SELECT (NEW.scheduled_for AT TIME ZONE timezone)::date INTO local_date FROM notification_preferences WHERE user_id=NEW.user_id;
   NEW.daily_focus:=findez_choose_daily_focus(NEW.user_id,local_date,NEW.id);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER choose_daily_focus BEFORE INSERT OR UPDATE OF state ON public.personalization_notifications
 FOR EACH ROW WHEN (NEW.category='daily_inventory') EXECUTE FUNCTION public.findez_assign_daily_focus();

-- A disabled category, expired task, revoked inventory or deleted record never
-- authorizes navigation or private lock-screen text.
CREATE FUNCTION public.findez_daily_focus_view(n personalization_notifications,p notification_preferences,details boolean)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE
 kind text:=n.daily_focus->>'kind'; inv uuid:=(n.daily_focus->>'inventory_id')::uuid;
 target uuid:=(n.daily_focus->>'id')::uuid; entity text:=n.daily_focus->>'entity';
 item items; title text; body text; label text;
 local_date date:=(now() AT TIME ZONE p.timezone)::date;
 fallback jsonb:=jsonb_build_object('entity_type','account','notification_id',n.id,'active',true,
  'title','Your inventory check-in','body','What would you like to find faster? Choose one item and record where you keep it.');
BEGIN
 IF p.user_id IS DISTINCT FROM n.user_id OR NOT p.inventory_alerts OR n.expires_at<=now()
    OR n.condition_key<>'daily-inventory/'||local_date::text THEN RETURN NULL; END IF;
 IF kind IS NULL OR NOT EXISTS(SELECT FROM app_inventories WHERE inventory_id=inv AND owner_user_id=n.user_id AND team_id IS NULL)
    OR findez_inventory_role(inv,n.user_id) IS NULL THEN RETURN fallback; END IF;
 IF entity='item' THEN
  SELECT * INTO item FROM items WHERE inventory_id=inv AND user_id=n.user_id AND item_id=target;
  IF NOT FOUND THEN RETURN fallback; END IF;
  label:=left(coalesce(nullif(btrim(item.name),''),'this item'),65);
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
REVOKE ALL ON FUNCTION public.findez_choose_daily_focus(uuid,date,uuid),public.findez_assign_daily_focus(),
 public.findez_daily_focus_view(personalization_notifications,notification_preferences,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_choose_daily_focus(uuid,date,uuid),
 public.findez_daily_focus_view(personalization_notifications,notification_preferences,boolean) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_personalization_destination(p_actor uuid,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; r jsonb;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id AND user_id=p_actor;
 IF FOUND AND n.category='daily_inventory' THEN
  RETURN (SELECT findez_daily_focus_view(n,p,false)-'title'-'body' FROM notification_preferences p WHERE user_id=p_actor);
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
  SELECT findez_daily_focus_view(n,p,p.show_details) INTO r;
  IF r IS NULL THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('revision',p.revision,'title',r->>'title','body',r->>'body',
    'direct',r->>'entity_type'<>'account');
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
 SELECT n.id,CASE WHEN n.category='daily_inventory' AND coalesce(focus->>'entity_type','account')='account' THEN 'daily_inventory' ELSE 'personalization' END AS action,n.category,n.created_at,n.read_at IS NOT NULL AS is_read,
 CASE WHEN category='daily_inventory' THEN focus->>'body' WHEN findez_tip_text(category) IS NOT NULL THEN findez_tip_text(category) WHEN category='scan_review' THEN 'A photo review is waiting for you.' ELSE 'An inventory item needs your attention.' END AS display_text
 FROM personalization_notifications n JOIN notification_preferences p ON p.user_id=n.user_id
 LEFT JOIN LATERAL (SELECT findez_daily_focus_view(n,p,true) AS focus WHERE n.category='daily_inventory') advice ON true
 WHERE n.user_id=p_actor AND n.policy_version=1 AND p.in_app_enabled AND n.state NOT IN ('resolved','dismissed')
 AND n.expires_at>now() AND (findez_personalization_destination(p_actor,n.id)->'active')='true'::jsonb
 AND ((n.category IN ('expiry','locate_item','low_stock','daily_inventory') AND p.inventory_alerts) OR (n.category='scan_review' AND p.capture_reminders) OR (n.category IN ('first_item','add_item','snap') AND p.reengagement))
 ORDER BY n.created_at DESC LIMIT 100) r
$$;

NOTIFY pgrst,'reload schema';
COMMIT;

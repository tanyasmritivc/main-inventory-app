BEGIN;
-- Snapshot at most four records. Resolve only still-authorized, unfinished targets.
CREATE FUNCTION findez_discovery_remaining(n personalization_notifications) RETURNS uuid[]
LANGUAGE sql STABLE SET search_path=public AS $$
 SELECT ARRAY(SELECT i.item_id FROM unnest(n.action_targets) WITH ORDINALITY target(id,pos)
   JOIN items i ON i.item_id=target.id AND i.inventory_id=n.inventory_id AND i.user_id=n.user_id
   JOIN app_inventories v ON v.inventory_id=i.inventory_id AND v.team_id IS NULL AND v.owner_user_id=n.user_id
   JOIN notification_preferences p ON p.user_id=n.user_id
   WHERE findez_inventory_role(v.inventory_id,n.user_id) IN ('owner','editor')
   AND ((n.category='discovery' AND p.cleanup_insights AND nullif(btrim(i.location),'') IS NULL AND i.space_id IS NULL)
    OR (n.category='weekly_insight' AND p.weekly_recap AND (i.quantity IS NULL OR i.quantity<0)))
   ORDER BY pos)
$$;
ALTER FUNCTION findez_personalization_destination(uuid,uuid) RENAME TO findez_single_destination;
CREATE FUNCTION findez_personalization_destination(p_actor uuid,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; targets uuid[];
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id AND user_id=p_actor;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF n.category IN ('low_stock','scan_review') THEN
  RETURN findez_single_destination(p_actor,p_id)||jsonb_build_object('quick_action',n.category);
 END IF;
 IF n.category NOT IN ('discovery','weekly_insight') THEN RETURN findez_single_destination(p_actor,p_id); END IF;
 targets:=findez_discovery_remaining(n);
 IF cardinality(targets)=0 OR n.expires_at<=now() THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('active',true,'entity_type','item','entity_id',targets[1],'inventory_id',n.inventory_id,
   'notification_id',n.id,'quick_action',n.category,'remaining_ids',targets);
END $$;

CREATE OR REPLACE FUNCTION findez_seed_inventory_pushes(p_limit int DEFAULT 50) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE made int;
BEGIN
 WITH accounts AS (
 SELECT p.*,v.inventory_id, (now() AT TIME ZONE p.timezone)::date AS day,
   dev.inventory_push_actions,dev.updated_at AS last_registration
 FROM notification_preferences p JOIN app_inventories v ON v.owner_user_id=p.user_id AND v.team_id IS NULL AND v.is_default
 JOIN LATERAL (SELECT updated_at,inventory_push_actions FROM push_devices WHERE user_id=p.user_id AND enabled
   AND personalization_destinations AND updated_at>now()-interval '90 days' ORDER BY updated_at DESC,device_token LIMIT 1) dev ON true
 WHERE p.push_enabled AND coalesce(p.paused_until<=now(),true) AND NOT findez_notification_quiet(p,now())
   AND findez_inventory_role(v.inventory_id,p.user_id) IN ('owner','editor')
 ), opportunities AS (
 SELECT a.*,o.* FROM accounts a CROSS JOIN LATERAL (
   WITH records AS MATERIALIZED (SELECT i.* FROM items i WHERE i.inventory_id=a.inventory_id AND i.user_id=a.user_id),
   gaps AS (SELECT category,ARRAY(SELECT i.item_id FROM records i WHERE
       CASE WHEN category='discovery' THEN i.space_id IS NULL AND nullif(btrim(i.location),'') IS NULL
       ELSE i.quantity IS NULL OR i.quantity<0 END
       AND NOT EXISTS(SELECT FROM personalization_notifications h WHERE h.user_id=a.user_id AND h.category=k.category
        AND h.accepted_at>now()-interval '7 days' AND i.item_id=ANY(h.action_targets))
       ORDER BY i.created_at,i.item_id LIMIT 4) AS targets
     FROM (VALUES ('discovery',a.cleanup_insights),('weekly_insight',a.weekly_recap)) k(category,on_flag) WHERE on_flag),
   suggestions AS (SELECT CASE WHEN NOT EXISTS(SELECT FROM records) THEN 'first_item'
     WHEN (SELECT category FROM personalization_notifications WHERE user_id=a.user_id
      AND category IN ('snap','add_item') AND accepted_at IS NOT NULL ORDER BY accepted_at DESC LIMIT 1)='snap'
       THEN 'add_item' ELSE 'snap' END AS kind
     WHERE a.reengagement AND a.inventory_push_actions
       AND NOT EXISTS(SELECT FROM items i JOIN app_inventories v USING(inventory_id)
          WHERE i.user_id=a.user_id AND v.owner_user_id=a.user_id AND v.team_id IS NULL AND i.created_at>now()-interval '3 days')
       AND NOT EXISTS(SELECT FROM personalization_notifications h WHERE h.user_id=a.user_id AND h.opened_at>now()-interval '2 hours'))
   SELECT 'expiry' AS category,'item' AS entity_type,i.item_id AS target,
     'expiry/'||i.item_id||'/'||i.expires_on AS event_key,ARRAY[i.item_id] AS targets,0 AS priority
   FROM records i WHERE a.inventory_alerts AND i.expires_on BETWEEN a.day AND a.day+7
   UNION ALL
   SELECT g.category,'item',g.targets[1],g.category||'/'||a.day,g.targets,1
   FROM gaps g WHERE cardinality(g.targets)>=2
   UNION ALL
   SELECT s.kind,'inventory',a.inventory_id,'suggestion/'||a.day,'{}'::uuid[],2 FROM suggestions s
   UNION ALL
   SELECT 'locate_item','item',i.item_id,'inventory-tip/locate_item/'||i.item_id||'/',ARRAY[i.item_id],3
   FROM records i WHERE a.inventory_alerts AND NOT a.cleanup_insights AND i.space_id IS NULL
     AND nullif(btrim(i.location),'') IS NULL AND i.created_at<now()-interval '2 days'
 ) o WHERE NOT EXISTS(SELECT FROM personalization_notifications n WHERE n.user_id=a.user_id AND
   (n.condition_key=o.event_key OR (n.category=o.category AND n.state IN ('pending','sending'))
   OR (n.category=o.category AND o.category IN ('expiry','locate_item') AND n.entity_id=o.target
    AND n.created_at>now()-interval '7 days')))
 ), selected AS (
 SELECT DISTINCT ON(user_id,category) * FROM opportunities ORDER BY user_id,category,priority,target
 )
 INSERT INTO personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key,policy_version,action_targets)
 SELECT user_id,inventory_id,category,entity_type,target,event_key,1,targets FROM selected
 ORDER BY priority,user_id,category LIMIT least(100,greatest(1,p_limit)) ON CONFLICT DO NOTHING;
 GET DIAGNOSTICS made=ROW_COUNT;
 RETURN made;
END $$;

-- Recheck activity across personal inventories at the provider boundary, including a queued first-item prompt.
ALTER FUNCTION findez_tip_active(uuid,uuid,text,uuid) RENAME TO findez_saved_tip_active;
CREATE FUNCTION findez_tip_active(p_user uuid,p_inventory uuid,p_category text,p_entity uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT findez_saved_tip_active(p_user,p_inventory,p_category,p_entity) AND
  (p_category NOT IN ('add_item','snap','first_item') OR NOT EXISTS(
   SELECT FROM items i JOIN app_inventories v USING(inventory_id) WHERE i.user_id=p_user AND v.owner_user_id=p_user
   AND v.team_id IS NULL AND i.created_at>now()-interval '3 days'))
$$;
ALTER FUNCTION findez_notification_content(uuid) RENAME TO findez_single_content;
CREATE FUNCTION findez_notification_content(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; p notification_preferences; total int; reason text;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF n.category NOT IN ('discovery','weekly_insight') THEN RETURN findez_single_content(p_id); END IF;
 IF findez_notification_eligible(p_id,now()) IS NOT NULL THEN RETURN NULL; END IF;
 SELECT * INTO p FROM notification_preferences WHERE user_id=n.user_id;
 total:=cardinality(findez_discovery_remaining(n));
 IF total=0 THEN RETURN NULL; END IF;
 reason:=CASE WHEN n.category='discovery' THEN 'a storage location' ELSE 'a recorded quantity' END;
 RETURN jsonb_build_object('revision',p.revision,'title',CASE WHEN n.category='discovery' THEN 'Make parts easier to find' ELSE 'A quick inventory check' END,
  'body',CASE WHEN p.show_details THEN format('%s %s %s. Tap to review.',total,CASE WHEN total=1 THEN 'record needs' ELSE 'records need' END,reason)
    ELSE 'Open FindEZ to review the details of your saved records.' END);
END $$;
CREATE OR REPLACE FUNCTION public.findez_notification_inbox(p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(r ORDER BY r.created_at DESC),'[]') FROM (
 SELECT n.id,CASE WHEN n.category='daily_inventory' AND coalesce(focus->>'entity_type','account')='account' THEN 'daily_inventory' ELSE 'personalization' END AS action,n.category,n.created_at,n.read_at IS NOT NULL AS is_read,
 CASE WHEN category IN ('discovery','weekly_insight') THEN 'Review incomplete inventory records.' WHEN category='daily_inventory' THEN focus->>'body' WHEN findez_tip_text(category) IS NOT NULL THEN findez_tip_text(category) WHEN category='scan_review' THEN 'A photo review is waiting for you.' ELSE 'An inventory item needs your attention.' END AS display_text
 FROM personalization_notifications n JOIN notification_preferences p ON p.user_id=n.user_id
 LEFT JOIN LATERAL (SELECT findez_daily_focus_view(n,p,true) AS focus WHERE n.category='daily_inventory') advice ON true
 WHERE n.user_id=p_actor AND n.policy_version=1 AND p.in_app_enabled AND n.state NOT IN ('resolved','dismissed')
 AND n.expires_at>now() AND (findez_personalization_destination(p_actor,n.id)->'active')='true'::jsonb
 AND ((n.category IN ('expiry','locate_item','low_stock') AND p.inventory_alerts) OR (n.category='discovery' AND p.cleanup_insights) OR (n.category='weekly_insight' AND p.weekly_recap) OR (n.category='daily_inventory' AND p.daily_enabled) OR (n.category='scan_review' AND p.capture_reminders) OR (n.category IN ('first_item','add_item','snap') AND p.reengagement))
 ORDER BY n.created_at DESC LIMIT 100) r
$$;
REVOKE ALL ON FUNCTION findez_personalization_destination(uuid,uuid),findez_notification_content(uuid),findez_tip_active(uuid,uuid,text,uuid),findez_discovery_remaining(personalization_notifications) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION findez_personalization_destination(uuid,uuid),findez_notification_content(uuid),findez_tip_active(uuid,uuid,text,uuid) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

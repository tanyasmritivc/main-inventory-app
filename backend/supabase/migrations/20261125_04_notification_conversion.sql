BEGIN;
ALTER TABLE push_devices ADD COLUMN conversion_events boolean NOT NULL DEFAULT false;
ALTER TABLE notification_preferences ADD COLUMN last_foreground_at timestamptz;
ALTER TABLE personalization_notifications ADD COLUMN push_tapped_at timestamptz,
 ADD COLUMN destination_at timestamptz, ADD COLUMN action_started_at timestamptz,
 ADD COLUMN workflow_finished_at timestamptz, ADD COLUMN interaction_capable boolean NOT NULL DEFAULT false;
CREATE TABLE notification_action_results (
 notification_id uuid NOT NULL REFERENCES personalization_notifications(id) ON DELETE CASCADE,
 target_id uuid NOT NULL, action text NOT NULL, recorded_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(notification_id,target_id,action));
CREATE INDEX notification_interaction_window ON personalization_notifications(user_id,destination_at DESC)
 WHERE destination_at IS NOT NULL;
CREATE TABLE notification_provider_receipts (
 notification_id uuid NOT NULL REFERENCES personalization_notifications(id) ON DELETE CASCADE,
 attempt smallint NOT NULL CHECK(attempt BETWEEN 1 AND 3), outcome text NOT NULL,
 submitted_at timestamptz NOT NULL, observed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(notification_id,attempt));
CREATE TABLE notification_disablements (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, revision bigint NOT NULL,
 setting text NOT NULL, notification_id uuid REFERENCES personalization_notifications(id) ON DELETE SET NULL,
 changed_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(user_id,revision,setting));
DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['notification_action_results','notification_provider_receipts','notification_disablements'] LOOP
 EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON %I FROM PUBLIC,anon,authenticated',t);
 EXECUTE format('GRANT ALL ON %I TO service_role',t);
END LOOP; END $$;

CREATE FUNCTION findez_notification_activity(p_actor uuid) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 INSERT INTO notification_preferences(user_id,last_foreground_at) VALUES(p_actor,now())
 ON CONFLICT(user_id) DO UPDATE SET last_foreground_at=now() WHERE notification_preferences.last_foreground_at IS NULL
 OR notification_preferences.last_foreground_at<now()-interval '5 minutes'
$$;
-- Revalidate the rendered preview immediately before an APNs call and record which client
-- can report a real tap. This also keeps pre-upgrade clients out of conversion denominators.
CREATE FUNCTION findez_notification_submit(p_id uuid,p_device text,p_revision bigint,p_preview text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; current_content jsonb; device push_devices; fingerprint text; dest jsonb;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id;
 IF NOT FOUND THEN RETURN false; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(n.user_id::text,193));
 SELECT * INTO device FROM push_devices WHERE device_token=p_device AND user_id=n.user_id AND enabled AND personalization_destinations FOR SHARE;
 IF NOT FOUND THEN RETURN false; END IF;
 dest:=findez_personalization_destination(n.user_id,p_id);
 IF dest->>'entity_type'='inventory' AND NOT device.inventory_push_actions THEN RETURN false; END IF;
 current_content:=findez_notification_content(p_id);
 fingerprint:=encode(sha256(convert_to((current_content->>'title')||chr(31)||(current_content->>'body')||chr(31)||coalesce(current_content->>'direct','false'),'UTF8')),'hex');
 IF current_content IS NULL OR fingerprint IS DISTINCT FROM p_preview THEN RETURN false; END IF;
 IF NOT findez_notification_begin_attempt(p_id,p_device,p_revision) THEN RETURN false; END IF;
 UPDATE personalization_notifications SET interaction_capable=device.conversion_events WHERE id=p_id;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION findez_notification_submit(uuid,text,bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION findez_notification_submit(uuid,text,bigint,text) TO service_role;

CREATE FUNCTION findez_notification_receipt(p_id uuid,p_outcome text,p_submitted timestamptz) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 INSERT INTO notification_provider_receipts(notification_id,attempt,outcome,submitted_at)
 SELECT notification_id,attempts,p_outcome,p_submitted FROM notification_delivery_attempts
 WHERE notification_id=p_id AND attempts BETWEEN 1 AND 3 AND p_outcome IN ('accepted','rejected','unknown')
 ON CONFLICT DO NOTHING
$$;

CREATE FUNCTION findez_notification_action(n personalization_notifications) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE WHEN n.category='daily_inventory' THEN coalesce(n.daily_focus->>'kind','check_in')
   ELSE n.category END
$$;
CREATE FUNCTION findez_record_notification_optout() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE field text;
BEGIN
 FOREACH field IN ARRAY ARRAY['push_enabled','daily_enabled','inventory_alerts','capture_reminders','reengagement','weekly_recap','cleanup_insights'] LOOP
  IF to_jsonb(OLD)->field='true'::jsonb AND to_jsonb(NEW)->field='false'::jsonb THEN
   INSERT INTO notification_disablements(user_id,revision,setting,notification_id)
   SELECT NEW.user_id,NEW.revision,field,(SELECT id FROM personalization_notifications WHERE user_id=NEW.user_id
    AND accepted_at>now()-interval '7 days' ORDER BY accepted_at DESC LIMIT 1)
   ON CONFLICT DO NOTHING;
  END IF;
 END LOOP;
 RETURN NEW;
END $$;
CREATE TRIGGER notification_optout AFTER UPDATE OF push_enabled,daily_enabled,inventory_alerts,capture_reminders,reengagement,weekly_recap,cleanup_insights
 ON notification_preferences FOR EACH ROW EXECUTE FUNCTION findez_record_notification_optout();

-- Legacy 'opened' includes inbox visits. Only an explicit push interaction counts as a tap.
ALTER FUNCTION findez_personalization_feedback(uuid,uuid,text) RENAME TO findez_legacy_notification_feedback;
CREATE FUNCTION findez_personalization_feedback(p_actor uuid,p_id uuid,p_outcome text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n personalization_notifications; d jsonb; k text;
BEGIN
 SELECT * INTO n FROM personalization_notifications WHERE id=p_id AND user_id=p_actor FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 IF p_outcome IN ('opened','delivered','dismissed') THEN
  IF (p_outcome='opened' AND n.opened_at IS NOT NULL) OR (p_outcome='delivered' AND n.delivered_at IS NOT NULL)
    OR (p_outcome='dismissed' AND n.dismissed_at IS NOT NULL) THEN RETURN true; END IF;
  RETURN findez_legacy_notification_feedback(p_actor,p_id,p_outcome);
 END IF;
 IF p_outcome='push_tapped' THEN
  IF n.attempted_at IS NULL THEN RETURN false; END IF;
  UPDATE personalization_notifications SET push_tapped_at=coalesce(push_tapped_at,now()),read_at=coalesce(read_at,now()) WHERE id=p_id;
  RETURN true;
 END IF;
 -- Adding a record makes an Add/Scan nudge ineligible for future sends. A completed
 -- scan can still confirm its original visit against a real write in that inventory.
 IF p_outcome='scan_saved' THEN
  IF findez_notification_action(n)<>'snap' OR n.destination_at IS NULL OR n.destination_at<now()-interval '24 hours' OR NOT EXISTS(
    SELECT FROM app_inventories v WHERE v.inventory_id=coalesce(n.inventory_id,(n.daily_focus->>'inventory_id')::uuid)
     AND v.owner_user_id=p_actor AND v.team_id IS NULL AND findez_inventory_role(v.inventory_id,p_actor) IN ('owner','editor')) OR NOT EXISTS(
    SELECT FROM notification_action_results WHERE notification_id=p_id AND action IN ('item_added','capture_queued')) THEN RETURN false; END IF;
  INSERT INTO notification_action_results VALUES(p_id,coalesce(n.inventory_id,(n.daily_focus->>'inventory_id')::uuid),'scan_saved',now()) ON CONFLICT DO NOTHING;
  UPDATE personalization_notifications SET action_started_at=coalesce(action_started_at,now()),workflow_finished_at=coalesce(workflow_finished_at,now()) WHERE id=p_id;
  RETURN true;
 END IF;
 d:=findez_personalization_destination(p_actor,p_id);
 IF d IS NULL OR d->>'active'<>'true' THEN RETURN false; END IF;
 IF p_outcome='destination_opened' THEN
  UPDATE personalization_notifications SET destination_at=coalesce(destination_at,now()),opened_at=coalesce(opened_at,now()),read_at=coalesce(read_at,now()) WHERE id=p_id;
 ELSIF p_outcome='action_started' THEN
  UPDATE personalization_notifications SET action_started_at=coalesce(action_started_at,now()) WHERE id=p_id AND destination_at IS NOT NULL;
  RETURN FOUND;
 ELSIF p_outcome='record_reviewed' THEN
  k:=findez_notification_action(n);
  IF n.destination_at IS NULL OR n.destination_at<now()-interval '24 hours' OR
    d->>'entity_type'<>'item' OR k NOT IN ('rediscover','progress','expiry','low_stock') THEN RETURN false; END IF;
  INSERT INTO notification_action_results VALUES(p_id,(d->>'entity_id')::uuid,p_outcome,now()) ON CONFLICT DO NOTHING;
  UPDATE personalization_notifications SET action_started_at=coalesce(action_started_at,now()),workflow_finished_at=coalesce(workflow_finished_at,now()) WHERE id=p_id;
 ELSE RETURN false;
 END IF;
 RETURN true;
END $$;

-- Attribute verified inventory writes to the most recent matching destination in the same personal inventory.
CREATE FUNCTION findez_attribute_inventory_action() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=findez_request_actor(); n personalization_notifications; kind text; target uuid; completed int;
BEGIN
 IF actor IS NULL OR NEW.user_id<>actor OR NOT EXISTS(SELECT FROM app_inventories v WHERE v.inventory_id=NEW.inventory_id
   AND v.owner_user_id=actor AND v.team_id IS NULL AND findez_inventory_role(v.inventory_id,actor) IN ('owner','editor')) THEN RETURN NEW; END IF;
 IF TG_TABLE_NAME='capture_reviews' THEN
   target:=NEW.review_id;
   IF TG_OP='INSERT' THEN kind:='capture_queued';
   ELSIF OLD.status='pending' AND NEW.status='resolved' THEN kind:='review_resolved';
   ELSE RETURN NEW; END IF;
 ELSIF TG_OP='INSERT' THEN kind:='item_added'; target:=NEW.item_id;
 ELSE
   target:=NEW.item_id;
   IF TG_ARGV[0]='location' AND (NEW.space_id IS NOT NULL OR nullif(btrim(NEW.location),'') IS NOT NULL) AND
      (NEW.location IS DISTINCT FROM OLD.location OR NEW.space_id IS DISTINCT FROM OLD.space_id) THEN kind:='location_updated'; END IF;
   IF TG_ARGV[0]='quantity' AND NEW.quantity>=0 AND NEW.quantity IS DISTINCT FROM OLD.quantity AND kind IS NULL THEN kind:='quantity_updated'; END IF;
 END IF;
 IF kind='item_added' THEN
   INSERT INTO notification_action_results(notification_id,target_id,action)
   SELECT q.id,target,'addition_after_visit' FROM personalization_notifications q
   WHERE q.user_id=actor AND greatest(q.push_tapped_at,q.destination_at) BETWEEN now()-interval '24 hours' AND now()
   ORDER BY greatest(q.push_tapped_at,q.destination_at) DESC,q.id LIMIT 1 ON CONFLICT DO NOTHING;
 END IF;
 IF kind IS NULL THEN RETURN NEW; END IF;
 SELECT q.* INTO n FROM personalization_notifications q
 WHERE q.user_id=actor AND q.destination_at BETWEEN now()-interval '24 hours' AND now()
 AND coalesce(q.inventory_id,(q.daily_focus->>'inventory_id')::uuid)=NEW.inventory_id
 AND (kind IN ('item_added','capture_queued') OR target=ANY(q.action_targets) OR target=coalesce((q.daily_focus->>'id')::uuid,q.entity_id))
 AND CASE kind
   WHEN 'capture_queued' THEN findez_notification_action(q)='snap'
   WHEN 'item_added' THEN findez_notification_action(q) IN ('snap','add_item','first_item')
   WHEN 'location_updated' THEN findez_notification_action(q) IN ('discovery','locate_item','location')
   WHEN 'quantity_updated' THEN findez_notification_action(q) IN ('weekly_insight','quantity','low_stock')
   WHEN 'review_resolved' THEN findez_notification_action(q) IN ('review','scan_review') END
 ORDER BY q.destination_at DESC,q.id LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN NEW; END IF;
 INSERT INTO notification_action_results(notification_id,target_id,action) VALUES(n.id,target,kind) ON CONFLICT DO NOTHING;
 SELECT count(DISTINCT target_id) INTO completed FROM notification_action_results WHERE notification_id=n.id AND action=kind;
 UPDATE personalization_notifications SET action_started_at=coalesce(action_started_at,now()),
 workflow_finished_at=CASE WHEN findez_notification_action(n)<>'snap' AND completed>=greatest(cardinality(n.action_targets),1) THEN coalesce(workflow_finished_at,now()) ELSE workflow_finished_at END WHERE id=n.id;
 RETURN NEW;
END $$;
CREATE TRIGGER attribute_notification_items AFTER INSERT ON items
 FOR EACH ROW EXECUTE FUNCTION findez_attribute_inventory_action('add');
CREATE TRIGGER attribute_notification_location AFTER UPDATE OF location,space_id ON items
 FOR EACH ROW EXECUTE FUNCTION findez_attribute_inventory_action('location');
CREATE TRIGGER attribute_notification_quantity AFTER UPDATE OF quantity ON items
 FOR EACH ROW EXECUTE FUNCTION findez_attribute_inventory_action('quantity');
CREATE TRIGGER attribute_notification_reviews AFTER INSERT OR UPDATE OF status ON capture_reviews
 FOR EACH ROW EXECUTE FUNCTION findez_attribute_inventory_action();
REVOKE ALL ON FUNCTION findez_record_notification_optout(),findez_attribute_inventory_action(),findez_notification_activity(uuid),
findez_notification_receipt(uuid,text,timestamptz),findez_personalization_feedback(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION findez_notification_activity(uuid),findez_notification_receipt(uuid,text,timestamptz),findez_personalization_feedback(uuid,uuid,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

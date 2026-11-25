BEGIN;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL lock_timeout='5s';

CREATE TABLE public.activation_accounts (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  signed_up_at timestamptz NOT NULL,
  next_due timestamptz NOT NULL,
  reminders integer NOT NULL DEFAULT 0,
  email_enabled boolean NOT NULL DEFAULT true,
  unsubscribe_token uuid UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  first_space_at timestamptz,
  first_item_at timestamptz,
  first_setup_at timestamptz
);
CREATE INDEX activation_due ON public.activation_accounts(next_due,user_id)
  WHERE first_space_at IS NULL AND first_item_at IS NULL AND first_setup_at IS NULL;

CREATE TABLE public.activation_organizations (
  organization_id uuid PRIMARY KEY REFERENCES public.app_organizations ON DELETE CASCADE,
  active_at timestamptz NOT NULL
);
CREATE TABLE public.activation_reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.activation_accounts ON DELETE CASCADE,
  cycle integer NOT NULL CHECK (cycle > 0),
  step integer NOT NULL CHECK (step > 0),
  channel text NOT NULL CHECK (channel IN ('email','push')),
  claimed_at timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  outcome text NOT NULL DEFAULT 'reserved' CHECK (outcome IN
    ('reserved','cancelled','submitting','accepted','rejected','unknown')),
  delivered_at timestamptz,
  opened_at timestamptz,
  UNIQUE(user_id,cycle)
);

-- Record the signup transaction, including accounts created during rollout.
CREATE FUNCTION public.findez_activation_enroll() RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  INSERT INTO activation_accounts(user_id,signed_up_at,next_due)
    VALUES(NEW.id,coalesce(NEW.created_at,now()),coalesce(NEW.created_at,now()) + interval '168 hours');
  RETURN NEW;
END $$;
CREATE TRIGGER findez_activation_signup AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.findez_activation_enroll();

CREATE FUNCTION public.findez_activation_log_evidence(kind text, details jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$
 SELECT kind IN ('review_resolved','review_dismissed')
    OR (kind IN ('bulk_create','spreadsheet_import') AND jsonb_typeof(details->'inserted')='number' AND details->'inserted'>'0'::jsonb)
    OR (kind='scan_image' AND jsonb_typeof(details->'total_detected')='number' AND details->'total_detected'>'0'::jsonb)
$$;

CREATE FUNCTION public.findez_activation_activity() RETURNS trigger LANGUAGE plpgsql
SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE actor uuid; org uuid; ws uuid; owner_id uuid; stamp timestamptz := now();
BEGIN
  IF TG_TABLE_NAME='activity_log' THEN
    IF NOT coalesce(findez_activation_log_evidence(NEW.event_type,NEW.metadata),false) THEN RETURN NEW; END IF;
  END IF;
  IF TG_TABLE_NAME='connector_import_sessions' THEN
    IF NEW.kind <> 'inventory' OR NEW.tables='[]'::jsonb THEN RETURN NEW; END IF;
    actor := NEW.actor_id;
    SELECT i.team_id,(to_jsonb(i)->>'organization_id')::uuid INTO ws,org FROM app_inventories i WHERE inventory_id=NEW.inventory_id;
  ELSIF TG_TABLE_NAME='team_activity' THEN
    IF NEW.action NOT IN ('space_created','space_added','space_removed','item_added','item_updated','item_deleted') THEN RETURN NEW; END IF;
    actor := NEW.actor_id;
    ws := NEW.team_id;
  ELSIF TG_TABLE_NAME='app_physical_locations' THEN
    ws := NEW.team_id;
  ELSE
    SELECT i.team_id,i.owner_user_id,(to_jsonb(i)->>'organization_id')::uuid INTO ws,owner_id,org
    FROM app_inventories i WHERE inventory_id=NEW.inventory_id;
    actor := findez_request_actor();
    IF actor IS NULL AND ws IS NULL THEN actor := coalesce(owner_id,NEW.user_id); END IF;
  END IF;
  IF ws IS NOT NULL THEN
    SELECT coalesce(org,organization_id) INTO org FROM teams WHERE team_id=ws;
    actor := coalesce(actor,findez_request_actor());
  END IF;
  IF org IS NOT NULL THEN
    INSERT INTO activation_organizations VALUES(org,stamp) ON CONFLICT DO NOTHING;
  END IF;
  IF TG_TABLE_NAME='spaces' THEN
    UPDATE activation_accounts SET first_space_at=stamp WHERE user_id=actor AND first_space_at IS NULL;
  ELSIF TG_TABLE_NAME='items' THEN
    UPDATE activation_accounts SET first_item_at=stamp WHERE user_id=actor AND first_item_at IS NULL;
  ELSE
    UPDATE activation_accounts SET first_setup_at=stamp WHERE user_id=actor AND first_setup_at IS NULL;
  END IF;
  RETURN NEW;
END $$;
-- A saved capture review or a named physical location is meaningful setup,
-- even before the first item is confirmed. Creating a default inventory isn't.
CREATE TRIGGER activation_space AFTER INSERT ON public.spaces FOR EACH ROW EXECUTE FUNCTION public.findez_activation_activity();
CREATE TRIGGER activation_item AFTER INSERT ON public.items FOR EACH ROW EXECUTE FUNCTION public.findez_activation_activity();
CREATE TRIGGER activation_work_log AFTER INSERT ON public.activity_log FOR EACH ROW EXECUTE FUNCTION public.findez_activation_activity();
CREATE TRIGGER activation_capture AFTER INSERT ON public.capture_reviews FOR EACH ROW EXECUTE FUNCTION public.findez_activation_activity();
CREATE TRIGGER activation_team_activity AFTER INSERT ON public.team_activity FOR EACH ROW EXECUTE FUNCTION public.findez_activation_activity();
CREATE TRIGGER activation_location AFTER INSERT ON public.app_physical_locations FOR EACH ROW EXECUTE FUNCTION public.findez_activation_activity();

CREATE TRIGGER activation_import AFTER INSERT ON public.connector_import_sessions FOR EACH ROW EXECUTE FUNCTION public.findez_activation_activity();

INSERT INTO public.activation_accounts(user_id,signed_up_at,next_due)
SELECT id,coalesce(created_at,now()),greatest(now(),coalesce(created_at,now())+interval '168 hours') FROM auth.users ON CONFLICT DO NOTHING;

-- Only evidence of inventory work counts: reading a page, opening the app or
-- automatically provisioning an inventory does not establish activation.
CREATE TEMP TABLE activation_history ON COMMIT DROP AS
 SELECT user_id,inventory_id,'space'::text kind,created_at::timestamptz stamp FROM public.spaces
 UNION ALL SELECT user_id,inventory_id,'item',created_at::timestamptz FROM public.items
 UNION ALL SELECT user_id,inventory_id,'setup',created_at FROM public.capture_reviews
 UNION ALL SELECT actor_id,inventory_id,'setup',created_at FROM public.connector_import_sessions
   WHERE kind='inventory' AND tables<>'[]'::jsonb
 UNION ALL SELECT user_id,inventory_id,
   CASE event_type WHEN 'inventory.item_created' THEN 'item' ELSE 'setup' END,occurred_at
 FROM public.personalization_events WHERE event_type IN ('inventory.item_created','inventory.item_updated',
   'inventory.item_moved','inventory.quantity_changed','inventory.item_consumed','inventory.item_deleted',
   'scan.review_required','scan.review_completed')
 UNION ALL SELECT user_id,inventory_id,'setup',created_at FROM public.activity_log
 WHERE findez_activation_log_evidence(event_type,metadata)
 UNION ALL SELECT actor_id,NULL::uuid,
   CASE action WHEN 'space_created' THEN 'space' WHEN 'item_added' THEN 'item' ELSE 'setup' END,created_at
 FROM public.team_activity WHERE action IN ('space_created','space_added','space_removed','item_added','item_updated','item_deleted');

UPDATE public.activation_accounts a SET first_space_at=h.first_space,first_item_at=h.first_item,first_setup_at=h.first_setup
FROM (SELECT user_id,min(coalesce(stamp,now())) FILTER (WHERE kind='space') first_space,
      min(coalesce(stamp,now())) FILTER (WHERE kind='item') first_item,
      min(coalesce(stamp,now())) FILTER (WHERE kind='setup') first_setup FROM activation_history GROUP BY user_id) h
WHERE a.user_id=h.user_id;

INSERT INTO public.activation_organizations
SELECT coalesce((to_jsonb(i)->>'organization_id')::uuid,t.organization_id),min(coalesce(h.stamp,now()))
FROM activation_history h JOIN public.app_inventories i USING(inventory_id) LEFT JOIN public.teams t USING(team_id)
WHERE coalesce((to_jsonb(i)->>'organization_id')::uuid,t.organization_id) IS NOT NULL GROUP BY 1 ON CONFLICT DO NOTHING;
INSERT INTO public.activation_organizations
SELECT t.organization_id,min(a.created_at) FROM public.team_activity a JOIN public.teams t USING(team_id)
WHERE t.organization_id IS NOT NULL AND a.action IN ('space_created','space_added','space_removed','item_added','item_updated','item_deleted')
GROUP BY t.organization_id ON CONFLICT DO NOTHING;

INSERT INTO public.activation_organizations
SELECT DISTINCT t.organization_id,now() FROM public.teams t WHERE t.organization_id IS NOT NULL AND
 (EXISTS (SELECT FROM public.app_physical_locations l WHERE l.team_id=t.team_id) OR
  EXISTS (SELECT FROM public.app_inventories i WHERE i.team_id=t.team_id AND
    (EXISTS(SELECT FROM public.spaces s WHERE s.inventory_id=i.inventory_id) OR
     EXISTS(SELECT FROM public.items s WHERE s.inventory_id=i.inventory_id) OR
     EXISTS(SELECT FROM public.capture_reviews s WHERE s.inventory_id=i.inventory_id)))) ON CONFLICT DO NOTHING;

CREATE FUNCTION public.findez_activation_inactive(actor uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT EXISTS(SELECT FROM activation_accounts a JOIN auth.users u ON u.id=a.user_id
   WHERE a.user_id=actor AND a.first_space_at IS NULL AND a.first_item_at IS NULL AND a.first_setup_at IS NULL
   AND u.deleted_at IS NULL AND NOT coalesce(u.is_anonymous,false)
   AND (u.banned_until IS NULL OR u.banned_until<=now())
   AND NOT EXISTS(SELECT FROM activation_organizations o WHERE o.organization_id IN (
     SELECT organization_id FROM app_organization_members WHERE user_id=actor
     UNION ALL SELECT organization_id FROM app_organizations WHERE owner_user_id=actor
     UNION ALL SELECT t.organization_id FROM team_memberships m JOIN teams t USING(team_id) WHERE m.user_id=actor)))
$$;

CREATE FUNCTION public.findez_activation_channels(actor uuid, allow_email boolean, allow_push boolean)
RETURNS TABLE(channel text, target jsonb) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT 'email'::text,jsonb_build_object('email',u.email,'unsubscribe',a.unsubscribe_token)
 FROM activation_accounts a JOIN auth.users u ON u.id=a.user_id
 WHERE allow_email AND a.user_id=actor AND a.email_enabled AND u.email_confirmed_at IS NOT NULL AND nullif(u.email,'') IS NOT NULL
 UNION ALL
 (SELECT 'push',jsonb_build_object('device_token',d.device_token,'environment',d.environment,'details',p.show_details)
  FROM notification_preferences p JOIN push_devices d USING(user_id)
  WHERE allow_push AND p.user_id=actor AND p.push_enabled AND p.reengagement AND d.enabled
    AND d.personalization_destinations AND d.inventory_push_actions AND d.platform='ios'
    AND d.updated_at>=now()-interval '90 days' AND coalesce(p.paused_until<=now(),true)
    AND NOT findez_notification_quiet(p,now())
  ORDER BY d.updated_at DESC,d.device_token LIMIT 1)
$$;

CREATE FUNCTION public.findez_activation_claim(allow_email boolean,allow_push boolean)
RETURNS uuid LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE entry record; reminder uuid; week_no integer;
BEGIN
 SELECT a.user_id,a.signed_up_at,a.reminders,c.channel INTO entry FROM activation_accounts a
 CROSS JOIN LATERAL (
    SELECT channel FROM findez_activation_channels(a.user_id,allow_email,allow_push)
    ORDER BY (channel=CASE WHEN a.reminders%2=0 THEN 'email' ELSE 'push' END) DESC LIMIT 1
 ) c WHERE a.next_due<=now() AND a.first_space_at IS NULL AND a.first_item_at IS NULL AND a.first_setup_at IS NULL
 AND findez_activation_inactive(a.user_id)
 ORDER BY a.next_due,a.user_id LIMIT 1 FOR UPDATE OF a SKIP LOCKED;
 IF NOT FOUND THEN RETURN NULL; END IF;
 week_no := floor(extract(epoch FROM now()-entry.signed_up_at)/604800)::integer;
 INSERT INTO activation_reminders(user_id,cycle,step,channel) VALUES(entry.user_id,week_no,entry.reminders+1,entry.channel) RETURNING id INTO reminder;
 UPDATE activation_accounts SET next_due=now()+interval '168 hours',reminders=reminders+1 WHERE user_id=entry.user_id;
 RETURN reminder;
END $$;

-- Final eligibility/recipient lookup at the handoff boundary. An interrupted
-- or ambiguous provider call cannot acquire a second submission permission.
CREATE FUNCTION public.findez_activation_begin(p_id uuid,allow_email boolean,allow_push boolean)
RETURNS jsonb LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE r activation_reminders; dest jsonb;
BEGIN
 SELECT * INTO r FROM activation_reminders WHERE id=p_id AND outcome='reserved' FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 PERFORM 1 FROM activation_accounts WHERE user_id=r.user_id FOR UPDATE;
 IF r.claimed_at>=now()-interval '5 minutes' AND findez_activation_inactive(r.user_id) THEN
   SELECT c.target INTO dest FROM findez_activation_channels(r.user_id,allow_email,allow_push) c WHERE c.channel=r.channel;
 END IF;
 IF dest IS NULL THEN
   UPDATE activation_reminders SET outcome='cancelled' WHERE id=p_id; RETURN NULL;
 END IF;
 UPDATE activation_accounts SET next_due=greatest(next_due,now()+interval '168 hours') WHERE user_id=r.user_id;
 UPDATE activation_reminders SET outcome='submitting',submitted_at=now() WHERE id=p_id;
 RETURN dest || jsonb_build_object('id',p_id,'user_id',r.user_id,'cycle',r.cycle,'step',r.step,'channel',r.channel);
END $$;

CREATE FUNCTION public.findez_activation_destination(p_actor uuid,p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE inv uuid;
BEGIN
 IF NOT EXISTS(SELECT FROM activation_reminders WHERE id=p_id AND user_id=p_actor AND channel='push' AND submitted_at IS NOT NULL)
    OR NOT findez_activation_inactive(p_actor) THEN RETURN NULL; END IF;
 inv:=findez_default_inventory(p_actor);
 RETURN jsonb_build_object('notification_id',p_id,'entity_type','inventory','entity_id',inv,'inventory_id',inv,'active',true,'quick_action','first_item');
END $$;

ALTER TABLE public.activation_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activation_organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activation_reminders ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.activation_accounts,public.activation_organizations,public.activation_reminders FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.activation_accounts,public.activation_organizations,public.activation_reminders TO service_role;
DO $$ DECLARE f regprocedure; BEGIN
 FOR f IN SELECT oid::regprocedure FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN
 ('findez_activation_enroll','findez_activation_log_evidence','findez_activation_activity','findez_activation_inactive','findez_activation_channels',
 'findez_activation_claim','findez_activation_begin','findez_activation_destination') LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f);
 END LOOP;
END $$;
-- Internal reporting only. Activation can happen without a reminder or a tap.
CREATE VIEW public.activation_campaign_metrics WITH (security_invoker=true) AS
SELECT a.user_id,a.signed_up_at,a.first_space_at,a.first_item_at,a.first_setup_at,
       least(a.first_space_at,a.first_item_at,a.first_setup_at)-a.signed_up_at AS time_to_first_observed_activation,
       count(r.id) FILTER (WHERE r.channel='email' AND r.outcome='accepted') AS email_accepted,
       count(r.id) FILTER (WHERE r.channel='email' AND r.delivered_at IS NOT NULL) AS email_delivered,
       count(r.id) FILTER (WHERE r.channel='email' AND r.opened_at IS NOT NULL) AS observed_email_opens,
       count(r.id) FILTER (WHERE r.channel='push' AND r.outcome='accepted') AS apns_accepted,
       count(r.id) FILTER (WHERE r.channel='push' AND r.delivered_at IS NOT NULL) AS app_reported_push_deliveries,
       count(r.id) FILTER (WHERE r.channel='push' AND r.opened_at IS NOT NULL) AS push_taps
FROM public.activation_accounts a LEFT JOIN public.activation_reminders r USING(user_id)
GROUP BY a.user_id;
REVOKE ALL ON public.activation_campaign_metrics FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.activation_campaign_metrics TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

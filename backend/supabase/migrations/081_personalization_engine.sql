-- Optional behavioral intelligence. Existing inventory authorization remains authoritative.
BEGIN;
ALTER TABLE public.push_devices ADD COLUMN IF NOT EXISTS personalization_destinations boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS public.personalization_profiles (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 enabled boolean NOT NULL DEFAULT false, revision bigint NOT NULL DEFAULT 0,
 generation bigint NOT NULL DEFAULT 0, categories text[] NOT NULL DEFAULT '{}',
 timezone text NOT NULL DEFAULT 'UTC', quiet_start integer NOT NULL DEFAULT 1260,
 quiet_end integer NOT NULL DEFAULT 540, daily_cap integer NOT NULL DEFAULT 1,
 weekly_cap integer NOT NULL DEFAULT 3, updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(categories <@ ARRAY['low_stock','scan_review']::text[] AND cardinality(categories)<=2),
 CHECK(quiet_start BETWEEN 0 AND 1439 AND quiet_end BETWEEN 0 AND 1439),
 CHECK(daily_cap BETWEEN 0 AND 2 AND weekly_cap BETWEEN 0 AND 5)
);
CREATE TABLE IF NOT EXISTS public.personalization_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 event_type text NOT NULL CHECK(event_type IN ('inventory.search_performed','inventory.search_succeeded',
 'inventory.search_failed','inventory.item_viewed','inventory.item_created','inventory.item_updated',
 'inventory.item_moved','inventory.quantity_changed','inventory.item_consumed','inventory.item_deleted',
 'inventory.alias_confirmed','scan.review_required','scan.review_completed','notification.sent',
 'notification.delivered','notification.opened','notification.dismissed','notification.action_completed')),
 occurred_at timestamptz NOT NULL DEFAULT now(), source text NOT NULL CHECK(source IN ('database','search','explicit','apns','device')),
 inventory_id uuid REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 entity_type text CHECK(entity_type IN ('item','review','notification')), entity_id uuid,
 payload jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(payload)='object' AND octet_length(payload::text)<=256
 AND payload - ARRAY['count','delta','query_hash']::text[] = '{}'::jsonb),
 dedupe_key text NOT NULL CHECK(length(dedupe_key) BETWEEN 1 AND 160), UNIQUE(user_id,dedupe_key),
 CHECK((entity_type IS NULL)=(entity_id IS NULL)),
 CHECK(entity_type NOT IN ('item','review') OR inventory_id IS NOT NULL),
 CHECK(NOT payload ? 'count' OR (jsonb_typeof(payload->'count')='number' AND payload->>'count' ~ '^[0-9]+$' AND (payload->>'count')::numeric BETWEEN 0 AND 1000000)),
 CHECK(NOT payload ? 'delta' OR (jsonb_typeof(payload->'delta')='number' AND payload->>'delta' ~ '^-?[0-9]+$' AND (payload->>'delta')::numeric BETWEEN -1000000 AND 1000000)),
 CHECK(NOT payload ? 'query_hash' OR (jsonb_typeof(payload->'query_hash')='string' AND payload->>'query_hash' ~ '^[a-f0-9]{64}$'))
);
CREATE INDEX IF NOT EXISTS personalization_events_recent ON public.personalization_events(user_id,inventory_id,occurred_at DESC);
CREATE INDEX IF NOT EXISTS personalization_events_retention ON public.personalization_events(occurred_at);
CREATE TABLE IF NOT EXISTS public.personalization_aliases (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 alias text NOT NULL CHECK(length(alias) BETWEEN 1 AND 60 AND alias ~ '^[[:alnum:]][[:alnum:] ]*$'),
 item_id uuid NOT NULL REFERENCES public.items(item_id) ON DELETE CASCADE,
 confirmed_at timestamptz NOT NULL DEFAULT now(), operation_id uuid NOT NULL,
 PRIMARY KEY(user_id,inventory_id,alias)
);
CREATE TABLE IF NOT EXISTS public.personalization_receipts (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, operation_id uuid NOT NULL,
 digest text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id,operation_id)
);
CREATE TABLE IF NOT EXISTS public.personalization_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 category text NOT NULL CHECK(category IN ('low_stock','scan_review')),
 entity_type text NOT NULL CHECK(entity_type IN ('item','review')), entity_id uuid NOT NULL,
 condition_key text NOT NULL, state text NOT NULL DEFAULT 'pending'
 CHECK(state IN ('pending','sending','accepted','unknown','resolved','dismissed')),
 created_at timestamptz NOT NULL DEFAULT now(), attempted_at timestamptz, accepted_at timestamptz,
 delivered_at timestamptz, opened_at timestamptz, dismissed_at timestamptz, completed_at timestamptz,
 UNIQUE(user_id,condition_key)
);
CREATE UNIQUE INDEX IF NOT EXISTS personalization_one_pending ON public.personalization_notifications(user_id,entity_type,entity_id,category) WHERE state IN ('pending','sending');
CREATE INDEX IF NOT EXISTS personalization_notifications_pending ON public.personalization_notifications(created_at) WHERE state='pending';
CREATE INDEX IF NOT EXISTS personalization_notifications_caps ON public.personalization_notifications(user_id,attempted_at DESC);

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['personalization_profiles','personalization_events','personalization_aliases','personalization_receipts','personalization_notifications'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
 EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
 IF t<>'personalization_receipts' THEN
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
  EXECUTE format('DROP POLICY IF EXISTS personalization_owner ON public.%I',t);
  EXECUTE format('CREATE POLICY personalization_owner ON public.%I FOR SELECT TO authenticated USING(user_id=auth.uid() AND NOT (coalesce(nullif(current_setting(''request.jwt.claims'',true),'''')::jsonb,''{}'') ? ''api_key_id''))',t);
 END IF;
 IF t IN ('personalization_events','personalization_aliases','personalization_notifications') THEN
  EXECUTE format('DROP POLICY IF EXISTS personalization_inventory ON public.%I',t);
  EXECUTE format('CREATE POLICY personalization_inventory ON public.%I AS RESTRICTIVE FOR SELECT TO authenticated USING(inventory_id IS NULL OR public.findez_inventory_role(inventory_id,auth.uid()) IS NOT NULL)',t);
 END IF;
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_enabled(p_actor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce((SELECT p.enabled AND EXISTS(SELECT 1 FROM public.user_memory m WHERE m.user_id=p_actor
 AND m.key='__settings_v1' AND m.memory_kind='settings' AND m.payload->'enabled'='true'::jsonb)
 FROM public.personalization_profiles p WHERE p.user_id=p_actor),false)
$$;

CREATE OR REPLACE FUNCTION public.findez_personalization_change(p_actor uuid,p_operation uuid,p_digest text,
 p_expected bigint,p_action text,p_data jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE p public.personalization_profiles; old_digest text; inv uuid; item uuid; label text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN RAISE insufficient_privilege; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor::text,81));
 INSERT INTO public.personalization_profiles(user_id) VALUES(p_actor) ON CONFLICT DO NOTHING;
 SELECT * INTO p FROM public.personalization_profiles WHERE user_id=p_actor FOR UPDATE;
 SELECT digest INTO old_digest FROM public.personalization_receipts WHERE user_id=p_actor AND operation_id=p_operation;
 IF FOUND THEN
  IF old_digest<>p_digest THEN RAISE unique_violation; END IF;
  RETURN jsonb_build_object('saved',true,'replayed',true,'revision',p.revision);
 END IF;
 IF p.revision IS DISTINCT FROM p_expected THEN RAISE serialization_failure; END IF;
 IF p_digest !~ '^[a-f0-9]{64}$' OR jsonb_typeof(p_data)<>'object' THEN RAISE invalid_parameter_value; END IF;
 IF p_action='settings' THEN
  IF p_data - ARRAY['enabled','categories','timezone','quiet_start','quiet_end','daily_cap','weekly_cap']::text[] <> '{}'::jsonb
   OR jsonb_typeof(p_data->'enabled') IS DISTINCT FROM 'boolean'
   OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_data->>'timezone') THEN RAISE invalid_parameter_value; END IF;
  IF p_data->'enabled'='true'::jsonb AND NOT EXISTS(SELECT 1 FROM public.user_memory WHERE user_id=p_actor
   AND key='__settings_v1' AND memory_kind='settings' AND payload->'enabled'='true'::jsonb) THEN RAISE check_violation USING message='Enable memory first'; END IF;
  UPDATE public.personalization_profiles SET enabled=(p_data->>'enabled')::boolean,
   categories=ARRAY(SELECT jsonb_array_elements_text(p_data->'categories')),timezone=p_data->>'timezone',
   quiet_start=(p_data->>'quiet_start')::int,quiet_end=(p_data->>'quiet_end')::int,
   daily_cap=(p_data->>'daily_cap')::int,weekly_cap=(p_data->>'weekly_cap')::int WHERE user_id=p_actor;
  -- Do not send an old candidate after re-enabling a category.
  UPDATE public.personalization_notifications SET state='resolved' WHERE user_id=p_actor AND state='pending'
   AND (p_data->'enabled'<>'true'::jsonb OR NOT (p_data->'categories' ? category));
 ELSIF p_action='alias' THEN
  IF NOT public.findez_personalization_enabled(p_actor) THEN RAISE check_violation; END IF;
  inv:=(p_data->>'inventory_id')::uuid;item:=(p_data->>'item_id')::uuid;label:=p_data->>'alias';
  IF public.findez_inventory_role(inv,p_actor) IS NULL THEN RAISE insufficient_privilege; END IF;
  IF label IS NULL OR length(label) NOT BETWEEN 1 AND 60 OR label !~ '^[[:alnum:]][[:alnum:] ]*$' THEN RAISE invalid_parameter_value; END IF;
  IF item IS NULL THEN DELETE FROM public.personalization_aliases WHERE user_id=p_actor AND inventory_id=inv AND alias=label;
  ELSE
   IF NOT EXISTS(SELECT 1 FROM public.items WHERE item_id=item AND inventory_id=inv) THEN RAISE insufficient_privilege; END IF;
   IF (SELECT count(*) FROM public.personalization_aliases WHERE user_id=p_actor)>=100
    AND NOT EXISTS(SELECT 1 FROM public.personalization_aliases WHERE user_id=p_actor AND inventory_id=inv AND alias=label) THEN RAISE check_violation; END IF;
   INSERT INTO public.personalization_aliases(user_id,inventory_id,alias,item_id,operation_id) VALUES(p_actor,inv,label,item,p_operation)
    ON CONFLICT(user_id,inventory_id,alias) DO UPDATE SET item_id=excluded.item_id,confirmed_at=now(),operation_id=excluded.operation_id;
   INSERT INTO public.personalization_events(user_id,event_type,source,inventory_id,entity_type,entity_id,dedupe_key)
    VALUES(p_actor,'inventory.alias_confirmed','explicit',inv,'item',item,'alias:'||p_operation::text) ON CONFLICT DO NOTHING;
  END IF;
 ELSIF p_action='reset' THEN
  DELETE FROM public.personalization_events WHERE user_id=p_actor;
  DELETE FROM public.personalization_aliases WHERE user_id=p_actor;
  DELETE FROM public.personalization_notifications WHERE user_id=p_actor;
  UPDATE public.personalization_profiles SET enabled=false,categories='{}',generation=generation+1 WHERE user_id=p_actor;
 ELSE RAISE invalid_parameter_value;
 END IF;
 UPDATE public.personalization_profiles SET revision=revision+1,updated_at=now() WHERE user_id=p_actor RETURNING * INTO p;
 INSERT INTO public.personalization_receipts VALUES(p_actor,p_operation,p_digest,now());
 RETURN jsonb_build_object('saved',true,'replayed',false,'revision',p.revision);
END $$;

-- Master memory Forget is one transaction across both stores, including delayed work.
CREATE OR REPLACE FUNCTION public.findez_personalization_memory_reset() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.key='__settings_v1' AND NEW.memory_kind='settings' AND
  coalesce((NEW.payload->>'generation')::bigint,0)>coalesce((OLD.payload->>'generation')::bigint,0) THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.user_id::text,81));
  PERFORM 1 FROM public.personalization_profiles WHERE user_id=NEW.user_id FOR UPDATE;
  DELETE FROM public.personalization_events WHERE user_id=NEW.user_id;
  DELETE FROM public.personalization_aliases WHERE user_id=NEW.user_id;
  DELETE FROM public.personalization_notifications WHERE user_id=NEW.user_id;
  UPDATE public.personalization_profiles SET enabled=false,categories='{}',revision=revision+1,generation=generation+1 WHERE user_id=NEW.user_id;
 ELSIF NEW.key='__settings_v1' AND NEW.memory_kind='settings' AND NEW.payload->'enabled'='false'::jsonb THEN
  UPDATE public.personalization_profiles SET enabled=false,revision=revision+1 WHERE user_id=NEW.user_id AND enabled;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS personalization_memory_reset ON public.user_memory;
CREATE TRIGGER personalization_memory_reset AFTER UPDATE ON public.user_memory FOR EACH ROW EXECUTE FUNCTION public.findez_personalization_memory_reset();

-- Bounded optional event insert; all callable writers are server-only.
CREATE OR REPLACE FUNCTION public.findez_personalization_event(p_actor uuid,p_generation bigint,p_key text,p_type text,
 p_inventory uuid,p_entity_type text,p_entity uuid,p_payload jsonb,p_source text DEFAULT 'search') RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 PERFORM 1 FROM public.personalization_profiles WHERE user_id=p_actor AND generation=p_generation FOR SHARE;
 IF NOT FOUND OR NOT public.findez_personalization_enabled(p_actor) THEN RETURN false; END IF;
 IF p_inventory IS NOT NULL AND public.findez_inventory_role(p_inventory,p_actor) IS NULL THEN RETURN false; END IF;
 IF p_entity_type='item' AND NOT EXISTS(SELECT 1 FROM public.items WHERE item_id=p_entity AND inventory_id=p_inventory) THEN RETURN false; END IF;
 INSERT INTO public.personalization_events(user_id,event_type,source,inventory_id,entity_type,entity_id,payload,dedupe_key)
 VALUES(p_actor,p_type,p_source,p_inventory,p_entity_type,p_entity,coalesce(p_payload,'{}'),p_key) ON CONFLICT(user_id,dedupe_key) DO NOTHING;
 RETURN FOUND;
END $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_observe() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor(); r jsonb; prior jsonb; inv uuid; entity uuid; kind text;
 ev text; key text; category text; before_qty numeric; qty numeric; threshold numeric; p public.personalization_profiles;
BEGIN
 -- Event failures are isolated in a subtransaction: inventory success never depends on learning.
 BEGIN
 IF actor IS NULL OR NOT public.findez_personalization_enabled(actor) THEN RETURN coalesce(NEW,OLD); END IF;
 SELECT * INTO p FROM public.personalization_profiles WHERE user_id=actor FOR SHARE NOWAIT;
 IF NOT FOUND OR NOT p.enabled THEN RETURN coalesce(NEW,OLD); END IF;
 r:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
 prior:=CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
 inv:=(r->>'inventory_id')::uuid;
 IF public.findez_inventory_role(inv,actor) IS NULL THEN RETURN coalesce(NEW,OLD); END IF;
 key:=gen_random_uuid()::text;
 IF TG_TABLE_NAME='items' THEN
  entity:=(r->>'item_id')::uuid;kind:='item';
  ev:=CASE TG_OP WHEN 'INSERT' THEN 'inventory.item_created' WHEN 'DELETE' THEN 'inventory.item_deleted'
   ELSE CASE WHEN prior->'quantity' IS DISTINCT FROM r->'quantity' THEN 'inventory.quantity_changed'
    WHEN prior->'space_id' IS DISTINCT FROM r->'space_id' OR prior->'location' IS DISTINCT FROM r->'location' THEN 'inventory.item_moved'
    ELSE 'inventory.item_updated' END END;
  IF TG_OP='UPDATE' AND r - ARRAY['updated_at']::text[]=prior - ARRAY['updated_at']::text[] THEN RETURN NEW; END IF;
  qty:=(r->>'quantity')::numeric;before_qty:=(prior->>'quantity')::numeric;
  threshold:=CASE WHEN r->'reorder_enabled'='true'::jsonb THEN (r->>'reorder_threshold')::numeric END;
  IF TG_OP='UPDATE' AND qty IS NOT NULL AND before_qty IS NOT NULL AND threshold IS NOT NULL
   AND qty>=0 AND qty<=threshold AND before_qty>threshold THEN category:='low_stock'; END IF;
  IF TG_OP='DELETE' OR threshold IS NULL OR (qty IS NOT NULL AND qty>threshold) THEN
   UPDATE public.personalization_notifications SET state='resolved',completed_at=CASE WHEN TG_OP='UPDATE' AND threshold IS NOT NULL AND qty>threshold AND opened_at IS NOT NULL THEN now() ELSE completed_at END
    WHERE user_id=actor AND inventory_id=inv AND entity_id=entity AND state NOT IN ('resolved','dismissed');
  END IF;
 ELSIF TG_TABLE_NAME='capture_reviews' THEN
  entity:=(r->>'review_id')::uuid;kind:='review';
  IF TG_OP='INSERT' AND r->>'status'='pending' THEN ev:='scan.review_required';category:='scan_review';
  ELSIF TG_OP='UPDATE' AND prior->>'status'='pending' AND r->>'status'='resolved' THEN
   ev:='scan.review_completed';
   UPDATE public.personalization_notifications SET state='resolved',completed_at=CASE WHEN opened_at IS NOT NULL THEN now() ELSE completed_at END
    WHERE user_id=actor AND inventory_id=inv AND entity_id=entity AND state NOT IN ('resolved','dismissed');
  ELSE
   UPDATE public.personalization_notifications SET state='resolved' WHERE user_id=actor AND inventory_id=inv AND entity_id=entity AND state='pending' AND (TG_OP='DELETE' OR r->>'status'<>'pending');
   RETURN coalesce(NEW,OLD);
  END IF;
 ELSE RETURN coalesce(NEW,OLD);
 END IF;
 INSERT INTO public.personalization_events(user_id,event_type,source,inventory_id,entity_type,entity_id,dedupe_key,payload)
  VALUES(actor,ev,'database',inv,kind,entity,key,CASE WHEN ev='inventory.quantity_changed' AND qty IS NOT NULL AND before_qty IS NOT NULL THEN jsonb_build_object('delta',qty-before_qty) ELSE '{}'::jsonb END);
 IF category IS NOT NULL AND category=ANY(p.categories) THEN
  INSERT INTO public.personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key)
   VALUES(actor,inv,category,kind,entity,CASE WHEN kind='review' THEN 'review:'||entity::text ELSE key END) ON CONFLICT DO NOTHING;
 END IF;
 EXCEPTION WHEN OTHERS THEN RAISE LOG 'Optional personalization observation unavailable';
 END;
 RETURN coalesce(NEW,OLD);
END $$;
DROP TRIGGER IF EXISTS personalization_items ON public.items;
CREATE TRIGGER personalization_items AFTER INSERT OR UPDATE OR DELETE ON public.items FOR EACH ROW EXECUTE FUNCTION public.findez_personalization_observe();
DROP TRIGGER IF EXISTS personalization_reviews ON public.capture_reviews;
CREATE TRIGGER personalization_reviews AFTER INSERT OR UPDATE OR DELETE ON public.capture_reviews FOR EACH ROW EXECUTE FUNCTION public.findez_personalization_observe();

CREATE OR REPLACE FUNCTION public.findez_personalization_destination(p_actor uuid,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n public.personalization_notifications; r jsonb;
BEGIN
 SELECT * INTO n FROM public.personalization_notifications WHERE id=p_id AND user_id=p_actor;
 IF NOT FOUND OR public.findez_inventory_role(n.inventory_id,p_actor) IS NULL THEN RETURN NULL; END IF;
 IF n.entity_type='item' THEN SELECT to_jsonb(i) INTO r FROM public.items i WHERE item_id=n.entity_id AND inventory_id=n.inventory_id;
 ELSE SELECT to_jsonb(i) INTO r FROM public.capture_reviews i WHERE review_id=n.entity_id AND inventory_id=n.inventory_id;
 END IF;
 IF r IS NULL THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('notification_id',n.id,'inventory_id',n.inventory_id,'entity_type',n.entity_type,'entity_id',n.entity_id,
 'active',CASE WHEN n.entity_type='review' THEN r->>'status'='pending' ELSE
  r->'reorder_enabled'='true'::jsonb AND (r->>'quantity')::numeric >= 0 AND (r->>'quantity')::numeric<=(r->>'reorder_threshold')::numeric END);
END $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_priority(p_category text,p_dismissals int,p_completed int) RETURNS integer
LANGUAGE sql IMMUTABLE AS $$ SELECT greatest(0,least(100,
 CASE p_category WHEN 'low_stock' THEN 90 WHEN 'scan_review' THEN 65 ELSE 0 END
 -least(3,p_dismissals)*15+least(2,p_completed)*2)) $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_candidates(p_limit int DEFAULT 50) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(r),'[]') FROM (
 SELECT n.id,public.findez_personalization_priority(n.category,
 count(h.dismissed_at)::int,count(h.completed_at)::int) AS priority
 FROM public.personalization_notifications n
 LEFT JOIN public.personalization_notifications h ON h.user_id=n.user_id AND h.category=n.category AND h.created_at>now()-interval '30 days'
 WHERE n.state='pending'
 GROUP BY n.id ORDER BY priority DESC,n.created_at LIMIT least(100,greatest(1,p_limit))) r
$$;

CREATE OR REPLACE FUNCTION public.findez_personalization_claim(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n public.personalization_notifications;p public.personalization_profiles;minute integer;destination jsonb; penalty integer; completed integer;
BEGIN
 SELECT * INTO n FROM public.personalization_notifications WHERE id=p_id;
 IF NOT FOUND THEN RETURN NULL; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(n.user_id::text,81));
 SELECT * INTO n FROM public.personalization_notifications WHERE id=p_id FOR UPDATE;
 SELECT * INTO p FROM public.personalization_profiles WHERE user_id=n.user_id FOR SHARE;
 IF n.state<>'pending' OR NOT public.findez_personalization_enabled(n.user_id) OR NOT n.category=ANY(p.categories) THEN RETURN NULL; END IF;
 destination:=public.findez_personalization_destination(n.user_id,n.id);
 IF destination IS NULL OR destination->'active' IS DISTINCT FROM 'true'::jsonb OR n.created_at<now()-interval '7 days' THEN
  UPDATE public.personalization_notifications SET state='resolved' WHERE id=p_id; RETURN NULL;
 END IF;
 IF n.category='scan_review' AND n.created_at>now()-interval '24 hours' THEN RETURN NULL; END IF;
 minute:=extract(hour from now() AT TIME ZONE p.timezone)::int*60+extract(minute from now() AT TIME ZONE p.timezone)::int;
 IF p.quiet_start=p.quiet_end OR
  (p.quiet_start<p.quiet_end AND minute>=p.quiet_start AND minute<p.quiet_end) OR
  (p.quiet_start>p.quiet_end AND (minute>=p.quiet_start OR minute<p.quiet_end)) THEN RETURN NULL; END IF;
 IF (SELECT count(*) FROM public.personalization_notifications WHERE user_id=n.user_id AND attempted_at>now()-interval '24 hours')>=p.daily_cap
 OR (SELECT count(*) FROM public.personalization_notifications WHERE user_id=n.user_id AND attempted_at>now()-interval '7 days')>=p.weekly_cap THEN RETURN NULL; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.push_devices WHERE user_id=n.user_id AND enabled AND personalization_destinations AND updated_at>now()-interval '90 days') THEN RETURN NULL; END IF;
 SELECT count(dismissed_at),count(completed_at) INTO penalty,completed FROM public.personalization_notifications WHERE user_id=n.user_id AND category=n.category AND created_at>now()-interval '30 days';
 -- Repeated explicit dismissals suppress this category; inactivity is never negative feedback.
 IF penalty>=3 THEN RETURN NULL; END IF;
 UPDATE public.personalization_notifications SET state='sending',attempted_at=now() WHERE id=p_id;
 RETURN destination||jsonb_build_object('user_id',n.user_id,'category',n.category,'score',public.findez_personalization_priority(n.category,penalty,completed));
END $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_delivery_ready(p_id uuid) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE n public.personalization_notifications;p public.personalization_profiles;minute integer;
BEGIN
 SELECT * INTO n FROM public.personalization_notifications WHERE id=p_id;
 IF NOT FOUND OR n.state<>'sending' OR n.attempted_at<now()-interval '2 minutes' THEN RETURN false; END IF;
 SELECT * INTO p FROM public.personalization_profiles WHERE user_id=n.user_id;
 IF NOT public.findez_personalization_enabled(n.user_id) OR NOT n.category=ANY(p.categories)
 OR p.daily_cap=0 OR p.weekly_cap=0 OR (public.findez_personalization_destination(n.user_id,n.id)->'active') IS DISTINCT FROM 'true'::jsonb THEN RETURN false; END IF;
 minute:=extract(hour from now() AT TIME ZONE p.timezone)::int*60+extract(minute from now() AT TIME ZONE p.timezone)::int;
 RETURN NOT (p.quiet_start=p.quiet_end OR
 (p.quiet_start<p.quiet_end AND minute>=p.quiet_start AND minute<p.quiet_end) OR
 (p.quiet_start>p.quiet_end AND (minute>=p.quiet_start OR minute<p.quiet_end)));
END $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_feedback(p_actor uuid,p_id uuid,p_outcome text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n public.personalization_notifications;
BEGIN
 SELECT * INTO n FROM public.personalization_notifications WHERE id=p_id AND user_id=p_actor FOR UPDATE;
 IF NOT FOUND OR n.attempted_at IS NULL OR public.findez_personalization_destination(p_actor,p_id) IS NULL
 OR NOT public.findez_personalization_enabled(p_actor) THEN RETURN false; END IF;
 IF p_outcome='delivered' THEN UPDATE public.personalization_notifications SET delivered_at=coalesce(delivered_at,now()) WHERE id=p_id;
 ELSIF p_outcome='opened' THEN UPDATE public.personalization_notifications SET opened_at=coalesce(opened_at,now()) WHERE id=p_id;
 ELSIF p_outcome='dismissed' THEN UPDATE public.personalization_notifications SET dismissed_at=coalesce(dismissed_at,now()),state=CASE WHEN state='resolved' THEN state ELSE 'dismissed' END WHERE id=p_id;
 ELSE RAISE invalid_parameter_value;
 END IF;
 INSERT INTO public.personalization_events(user_id,event_type,source,inventory_id,entity_type,entity_id,dedupe_key)
 VALUES(p_actor,'notification.'||p_outcome,'device',n.inventory_id,'notification',p_id,p_id::text||':'||p_outcome) ON CONFLICT DO NOTHING;
 RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.findez_personalization_cleanup() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 DELETE FROM public.personalization_events WHERE occurred_at<now()-interval '90 days';
 DELETE FROM public.personalization_notifications WHERE created_at<now()-interval '90 days';
 -- CAS revisions still reject old commands after their receipt expires.
 DELETE FROM public.personalization_receipts WHERE created_at<now()-interval '90 days';
 UPDATE public.personalization_notifications SET state='unknown' WHERE state='sending' AND attempted_at<now()-interval '15 minutes';
END $$;


CREATE OR REPLACE FUNCTION public.findez_personalization_outcome() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE kind text;
BEGIN
 IF NOT public.findez_personalization_enabled(NEW.user_id) THEN RETURN NEW; END IF;
 IF NEW.accepted_at IS NOT NULL AND OLD.accepted_at IS NULL THEN kind:='sent';
 ELSIF NEW.completed_at IS NOT NULL AND OLD.completed_at IS NULL AND NEW.opened_at IS NOT NULL THEN kind:='action_completed';
 ELSE RETURN NEW; END IF;
 INSERT INTO public.personalization_events(user_id,event_type,source,inventory_id,entity_type,entity_id,dedupe_key)
 VALUES(NEW.user_id,'notification.'||kind,CASE WHEN kind='sent' THEN 'apns' ELSE 'database' END,
 NEW.inventory_id,'notification',NEW.id,NEW.id::text||':'||kind) ON CONFLICT DO NOTHING;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS personalization_outcome ON public.personalization_notifications;
CREATE TRIGGER personalization_outcome AFTER UPDATE ON public.personalization_notifications FOR EACH ROW EXECUTE FUNCTION public.findez_personalization_outcome();

-- One bounded read per search; facts always come from the separately authorized item query.
CREATE OR REPLACE FUNCTION public.findez_personalization_context(p_actor uuid,p_inventory uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE p public.personalization_profiles;
BEGIN
 IF NOT public.findez_personalization_enabled(p_actor) OR public.findez_inventory_role(p_inventory,p_actor) IS NULL THEN RETURN NULL; END IF;
 SELECT * INTO p FROM public.personalization_profiles WHERE user_id=p_actor;
 RETURN jsonb_build_object('generation',p.generation,
 'aliases',coalesce((SELECT jsonb_agg(a) FROM (SELECT alias,item_id,confirmed_at FROM public.personalization_aliases
 WHERE user_id=p_actor AND inventory_id=p_inventory ORDER BY confirmed_at DESC LIMIT 100) a),'[]'),
 'events',coalesce((SELECT jsonb_agg(e) FROM (SELECT event_type,entity_type,entity_id,occurred_at,source FROM public.personalization_events
 WHERE user_id=p_actor AND inventory_id=p_inventory AND occurred_at>now()-interval '90 days' ORDER BY occurred_at DESC LIMIT 512) e),'[]'));
END $$;

DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT oid::regprocedure AS signature FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE 'findez_personalization_%' LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',r.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

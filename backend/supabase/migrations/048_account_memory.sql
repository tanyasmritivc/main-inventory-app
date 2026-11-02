-- Explicit account preferences and private inventory aliases. No inferred promotion.
BEGIN;
ALTER TABLE public.user_memory
 ADD COLUMN memory_kind text NOT NULL DEFAULT 'legacy',
 ADD COLUMN payload jsonb NOT NULL DEFAULT '{}',
 ADD COLUMN revision bigint NOT NULL DEFAULT 0,
 ADD COLUMN confirmed_at timestamptz;
ALTER TABLE public.inventory_user_memory
 ADD COLUMN memory_kind text NOT NULL DEFAULT 'legacy',
 ADD COLUMN payload jsonb NOT NULL DEFAULT '{}',
 ADD COLUMN revision bigint NOT NULL DEFAULT 0,
 ADD COLUMN confirmed_at timestamptz;
CREATE TABLE public.memory_events (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 operation_id uuid NOT NULL, request_digest text NOT NULL CHECK(length(request_digest)=64),
 memory_key text, inventory_id uuid REFERENCES public.app_inventories ON DELETE SET NULL,
 action text NOT NULL CHECK(action IN ('settings','set','delete','clear')),
 revision bigint NOT NULL, generation bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id,operation_id)
);
ALTER TABLE public.user_memory ADD COLUMN source_operation_id uuid,
 ADD CONSTRAINT account_memory_source FOREIGN KEY(user_id,source_operation_id) REFERENCES public.memory_events(user_id,operation_id) DEFERRABLE INITIALLY DEFERRED,
 ADD CONSTRAINT account_memory_kind CHECK(memory_kind IN ('legacy','settings','preference') AND revision>=0 AND octet_length(payload::text)<=1024);
ALTER TABLE public.inventory_user_memory ADD COLUMN source_operation_id uuid,
 ADD CONSTRAINT inventory_memory_source FOREIGN KEY(user_id,source_operation_id) REFERENCES public.memory_events(user_id,operation_id) DEFERRABLE INITIALLY DEFERRED,
 ADD CONSTRAINT inventory_memory_kind CHECK(memory_kind IN ('legacy','alias') AND revision>=0 AND octet_length(payload::text)<=1024);
CREATE INDEX memory_events_owner_revision ON public.memory_events(user_id,revision);
ALTER TABLE public.memory_events ENABLE ROW LEVEL SECURITY;
-- Remove misleading permissive baseline policies, including any historical copies.
DO $$ DECLARE t text; p record; BEGIN
 FOREACH t IN ARRAY ARRAY['user_memory','inventory_user_memory','memory_events'] LOOP
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
   EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,t);
  END LOOP;
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
  EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
 END LOOP;
END $$;
-- Legacy analytics/history must not remain an alternate public memory path.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['conversation_history','query_logs'] LOOP
  IF to_regclass('public.'||t) IS NOT NULL THEN
   EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I','Service role full access to '||t,t);
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated',t);
   EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
   EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
   EXECUTE format('CREATE POLICY memory_private_owner ON public.%I AS RESTRICTIVE FOR SELECT TO authenticated USING(user_id=auth.uid() AND NOT (coalesce(nullif(current_setting(''request.jwt.claims'',true),'''')::jsonb,''{}'') ? ''api_key_id''))',t);
   EXECUTE format('CREATE POLICY memory_private_read ON public.%I FOR SELECT TO authenticated USING(user_id=auth.uid())',t);
  END IF;
 END LOOP;
END $$;
CREATE POLICY memory_owner ON public.user_memory FOR SELECT TO authenticated
 USING(user_id=auth.uid() AND NOT (coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}') ? 'api_key_id'));
CREATE POLICY memory_inventory_owner ON public.inventory_user_memory FOR SELECT TO authenticated
 USING(user_id=auth.uid() AND public.findez_inventory_role(inventory_id,auth.uid()) IS NOT NULL
 AND NOT (coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}') ? 'api_key_id'));
CREATE POLICY memory_event_owner ON public.memory_events FOR SELECT TO authenticated
 USING(user_id=auth.uid() AND NOT (coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}') ? 'api_key_id'));

-- Prevent old in-flight extractors from recreating forgotten legacy facts.
CREATE FUNCTION public.findez_guard_memory_promotion() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF current_setting('findez.memory_actor',true) IS DISTINCT FROM NEW.user_id::text THEN
  RAISE insufficient_privilege USING message='Use explicit memory controls';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_guard_memory_promotion() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER memory_controlled_write BEFORE INSERT OR UPDATE ON public.user_memory FOR EACH ROW EXECUTE FUNCTION public.findez_guard_memory_promotion();
CREATE TRIGGER memory_controlled_write BEFORE INSERT OR UPDATE ON public.inventory_user_memory FOR EACH ROW EXECUTE FUNCTION public.findez_guard_memory_promotion();

CREATE FUNCTION public.findez_change_memory(
 p_actor uuid,p_operation uuid,p_digest text,p_expected bigint,p_action text,
 p_key text DEFAULT NULL,p_payload jsonb DEFAULT '{}',p_inventory uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE control public.user_memory; receipt public.memory_events; next_revision bigint;
 generation bigint; enabled boolean; space uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN RAISE insufficient_privilege; END IF;
 PERFORM set_config('findez.memory_actor',p_actor::text,true);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor::text,48));
 -- Preserve an untrusted old key that happens to collide with the reserved control.
 UPDATE public.user_memory SET key='__legacy_control_'||gen_random_uuid()::text,
  payload=jsonb_build_object('original_key',key)
 WHERE user_id=p_actor AND key='__settings_v1' AND memory_kind='legacy';
 INSERT INTO public.user_memory(user_id,key,value,memory_kind,payload)
 VALUES(p_actor,'__settings_v1','explicit memory settings','settings','{"enabled":false,"generation":0}')
 ON CONFLICT(user_id,key) DO NOTHING;
 SELECT * INTO control FROM public.user_memory WHERE user_id=p_actor AND key='__settings_v1' FOR UPDATE;
 IF control.memory_kind<>'settings' THEN RAISE check_violation USING message='Memory settings need review'; END IF;
 generation:=(control.payload->>'generation')::bigint;
 enabled:=(control.payload->>'enabled')::boolean;
 SELECT * INTO receipt FROM public.memory_events WHERE user_id=p_actor AND operation_id=p_operation;
 IF FOUND THEN
  IF receipt.request_digest<>p_digest THEN RAISE unique_violation USING message='Operation key reused'; END IF;
  RETURN jsonb_build_object('saved',true,'replayed',true,'revision',control.revision);
 END IF;
 IF p_expected IS DISTINCT FROM control.revision THEN RAISE serialization_failure USING message='Memory changed; refresh'; END IF;
 IF p_action IS NULL OR p_action NOT IN ('settings','set','delete','clear') OR p_digest IS NULL OR p_digest !~ '^[a-f0-9]{64}$' OR p_payload IS NULL OR jsonb_typeof(p_payload)<>'object' THEN RAISE invalid_parameter_value; END IF;
 IF p_inventory IS NOT NULL AND public.findez_inventory_role(p_inventory,p_actor) IS NULL THEN RAISE insufficient_privilege; END IF;
 IF p_action='settings' THEN
  IF p_inventory IS NOT NULL OR p_payload NOT IN ('{"enabled":true}'::jsonb,'{"enabled":false}'::jsonb) THEN RAISE invalid_parameter_value; END IF;
  enabled:=(p_payload->>'enabled')::boolean;
 ELSIF p_action='clear' THEN
  DELETE FROM public.user_memory WHERE user_id=p_actor AND key<>'__settings_v1';
  DELETE FROM public.inventory_user_memory WHERE user_id=p_actor;
  generation:=generation+1;
  enabled:=false;
 ELSIF p_action IN ('set','delete') THEN
  IF p_action='set' AND NOT enabled THEN RAISE check_violation USING message='Enable memory first'; END IF;
  IF p_inventory IS NULL THEN
   IF p_key IS NULL OR p_key NOT IN ('answer_length','answer_format') THEN RAISE invalid_parameter_value; END IF;
   IF p_action='set' AND NOT (
    (p_key='answer_length' AND p_payload IN ('{"value":"brief"}'::jsonb,'{"value":"standard"}'::jsonb,'{"value":"detailed"}'::jsonb)) OR
    (p_key='answer_format' AND p_payload IN ('{"value":"paragraphs"}'::jsonb,'{"value":"bullets"}'::jsonb))
   ) THEN RAISE invalid_parameter_value; END IF;
  ELSE
   IF p_key IS NULL OR p_key !~ '^alias:[a-f0-9]{64}$' THEN RAISE invalid_parameter_value; END IF;
   IF p_action='set' THEN
    IF jsonb_typeof(p_payload)<>'object' OR (SELECT count(*) FROM jsonb_object_keys(p_payload))<>2
      OR jsonb_typeof(p_payload->'alias')<>'string' OR length(p_payload->>'alias') NOT BETWEEN 1 AND 60
      OR p_payload->>'alias' !~ '^[[:alnum:]][[:alnum:] ]*$' THEN RAISE invalid_parameter_value; END IF;
    space:=(p_payload->>'space_id')::uuid;
    IF space IS NULL OR NOT EXISTS(SELECT 1 FROM public.spaces WHERE id=space AND inventory_id=p_inventory) THEN RAISE insufficient_privilege; END IF;
    IF (SELECT count(*) FROM public.inventory_user_memory WHERE user_id=p_actor AND memory_kind='alias')>=50
      AND NOT EXISTS(SELECT 1 FROM public.inventory_user_memory WHERE user_id=p_actor AND inventory_id=p_inventory AND key=p_key)
      THEN RAISE check_violation USING message='At most 50 aliases'; END IF;
   END IF;
  END IF;
  next_revision:=control.revision+1;
  IF p_inventory IS NULL THEN
   IF p_action='delete' THEN DELETE FROM public.user_memory WHERE user_id=p_actor AND key=p_key;
   ELSE INSERT INTO public.user_memory(user_id,key,value,memory_kind,payload,revision,confirmed_at,source_operation_id)
    VALUES(p_actor,p_key,p_payload->>'value','preference',p_payload,next_revision,now(),p_operation)
    ON CONFLICT(user_id,key) DO UPDATE SET value=excluded.value,memory_kind=excluded.memory_kind,payload=excluded.payload,
      revision=excluded.revision,confirmed_at=now(),updated_at=now(),source_operation_id=p_operation; END IF;
  ELSE
   IF p_action='delete' THEN DELETE FROM public.inventory_user_memory WHERE user_id=p_actor AND inventory_id=p_inventory AND key=p_key;
   ELSE INSERT INTO public.inventory_user_memory(inventory_id,user_id,key,value,memory_kind,payload,revision,confirmed_at,source_operation_id)
    VALUES(p_inventory,p_actor,p_key,p_payload->>'alias','alias',p_payload,next_revision,now(),p_operation)
    ON CONFLICT(inventory_id,user_id,key) DO UPDATE SET value=excluded.value,memory_kind=excluded.memory_kind,payload=excluded.payload,
     revision=excluded.revision,confirmed_at=now(),updated_at=now(),source_operation_id=p_operation; END IF;
  END IF;
 END IF;
 next_revision:=control.revision+1;
 UPDATE public.user_memory SET payload=jsonb_build_object('enabled',enabled,'generation',generation),
  revision=next_revision,confirmed_at=now(),updated_at=now(),source_operation_id=p_operation WHERE user_id=p_actor AND key='__settings_v1';
 INSERT INTO public.memory_events(user_id,operation_id,request_digest,action,revision,generation,memory_key,inventory_id)
 VALUES(p_actor,p_operation,p_digest,p_action,next_revision,generation,p_key,p_inventory);
 RETURN jsonb_build_object('saved',true,'replayed',false,'revision',next_revision);
END $$;
REVOKE ALL ON FUNCTION public.findez_change_memory(uuid,uuid,text,bigint,text,text,jsonb,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_change_memory(uuid,uuid,text,bigint,text,text,jsonb,uuid) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

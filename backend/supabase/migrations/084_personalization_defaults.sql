-- Default-on private inventory personalization; explicit opt-outs/reset remain off.
BEGIN;
ALTER TABLE public.personalization_profiles ALTER COLUMN enabled SET DEFAULT true;
CREATE OR REPLACE FUNCTION public.findez_initialize_personalization(p_actor uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 PERFORM set_config('findez.memory_actor',p_actor::text,true);
 INSERT INTO public.user_memory(user_id,key,value,memory_kind,payload)
 VALUES(p_actor,'__settings_v1','memory settings','settings','{"enabled":true,"generation":0}')
 ON CONFLICT(user_id,key) DO NOTHING;
 UPDATE public.user_memory SET payload=jsonb_set(payload,'{enabled}','true'::jsonb)
 WHERE user_id=p_actor AND key='__settings_v1' AND memory_kind='settings' AND revision=0 AND source_operation_id IS NULL;
 INSERT INTO public.personalization_profiles(user_id,enabled)
 SELECT p_actor,coalesce((payload->>'enabled')::boolean,false) FROM public.user_memory
 WHERE user_id=p_actor AND key='__settings_v1' AND memory_kind='settings'
 ON CONFLICT(user_id) DO NOTHING;
END $$;
REVOKE ALL ON FUNCTION public.findez_initialize_personalization(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_initialize_personalization(uuid) TO service_role;
DO $$ DECLARE actor uuid; BEGIN
 FOR actor IN SELECT id FROM auth.users LOOP
  PERFORM public.findez_initialize_personalization(actor);
 END LOOP;
END $$;
-- A revision-zero profile is an untouched default, not a recorded opt-out.
UPDATE public.personalization_profiles p SET enabled=true
 WHERE p.revision=0 AND NOT p.enabled AND EXISTS(SELECT 1 FROM public.user_memory m
 WHERE m.user_id=p.user_id AND m.key='__settings_v1' AND m.memory_kind='settings'
 AND m.payload->'enabled'='true'::jsonb);
CREATE OR REPLACE FUNCTION public.findez_new_user_personalization() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 PERFORM public.findez_initialize_personalization(NEW.id);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_new_user_personalization() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS findez_new_user_personalization ON auth.users;
CREATE TRIGGER findez_new_user_personalization AFTER INSERT ON auth.users
 FOR EACH ROW EXECUTE FUNCTION public.findez_new_user_personalization();
-- The visible Memory switch enables the learning layer too. Explicit off/reset
-- still uses the existing reset trigger and never enables notifications.
CREATE OR REPLACE FUNCTION public.findez_memory_enable_personalization() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.key='__settings_v1' AND NEW.memory_kind='settings'
 AND NEW.payload->'enabled'='true'::jsonb AND OLD.payload->'enabled' IS DISTINCT FROM 'true'::jsonb THEN
  INSERT INTO public.personalization_profiles(user_id,enabled) VALUES(NEW.user_id,true)
  ON CONFLICT(user_id) DO UPDATE SET enabled=true,revision=personalization_profiles.revision+1;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_memory_enable_personalization() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS memory_enable_personalization ON public.user_memory;
CREATE TRIGGER memory_enable_personalization AFTER UPDATE ON public.user_memory
 FOR EACH ROW EXECUTE FUNCTION public.findez_memory_enable_personalization();
NOTIFY pgrst,'reload schema';
COMMIT;

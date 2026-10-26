-- Run only against a disposable schema clone after migration 084. All synthetic rows roll back.
BEGIN;
 INSERT INTO auth.users(id) VALUES('00000000-0000-0000-0000-000000000841');
 DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.personalization_profiles WHERE user_id='00000000-0000-0000-0000-000000000841' AND enabled AND categories='{}') THEN RAISE EXCEPTION 'New user profile defaults'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.user_memory WHERE user_id='00000000-0000-0000-0000-000000000841' AND key='__settings_v1' AND payload->>'enabled'='true') THEN RAISE EXCEPTION 'New user memory defaults'; END IF;
 END $$;
 SELECT set_config('findez.memory_actor','00000000-0000-0000-0000-000000000841',true);
 UPDATE public.user_memory SET payload=jsonb_set(payload,'{enabled}','false'),revision=1 WHERE user_id='00000000-0000-0000-0000-000000000841' AND key='__settings_v1';
 SELECT public.findez_initialize_personalization('00000000-0000-0000-0000-000000000841');
 DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.user_memory WHERE user_id='00000000-0000-0000-0000-000000000841' AND key='__settings_v1' AND payload->>'enabled'='true') THEN RAISE EXCEPTION 'Optout lost'; END IF;
 END $$;
 UPDATE public.user_memory SET payload=jsonb_set(payload,'{enabled}','true'),revision=2 WHERE user_id='00000000-0000-0000-0000-000000000841' AND key='__settings_v1';
 DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.personalization_profiles WHERE user_id='00000000-0000-0000-0000-000000000841' AND enabled AND categories='{}') THEN RAISE EXCEPTION 'Toggle sync failed'; END IF;
 IF has_function_privilege('authenticated','public.findez_initialize_personalization(uuid)','EXECUTE') OR has_function_privilege('anon','public.findez_initialize_personalization(uuid)','EXECUTE') THEN RAISE EXCEPTION 'RPC exposed'; END IF;
 END $$;
 ROLLBACK;

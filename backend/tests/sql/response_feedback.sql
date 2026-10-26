-- Run only in an empty disposable database; all identities are synthetic.
\set ON_ERROR_STOP on
CREATE SCHEMA auth;
DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF; IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF; IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role BYPASSRLS; END IF; END $$;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.conversations(id uuid PRIMARY KEY,user_id uuid REFERENCES auth.users ON DELETE CASCADE,world_key text);
CREATE TABLE public.messages(id uuid PRIMARY KEY,conversation_id uuid REFERENCES public.conversations ON DELETE CASCADE,role text,content text,answer_context jsonb);
CREATE TABLE public.app_organization_members(organization_id uuid,user_id uuid);
CREATE TABLE public.personalization_profiles(user_id uuid REFERENCES auth.users ON DELETE CASCADE,generation bigint,enabled boolean);
CREATE FUNCTION public.findez_actor_active(actor uuid) RETURNS boolean LANGUAGE sql AS $$ SELECT EXISTS(SELECT FROM auth.users WHERE id=actor) $$;
CREATE FUNCTION public.findez_personalization_enabled(actor uuid) RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce((SELECT enabled FROM personalization_profiles WHERE user_id=actor),false) $$;
\ir ../../supabase/migrations/082_response_feedback.sql
\ir ../../supabase/migrations/082_response_feedback.sql
CREATE FUNCTION pg_temp.check(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF; RAISE NOTICE 'PASS: %',label; END $$;
INSERT INTO auth.users VALUES('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
INSERT INTO conversations VALUES('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','personal');
INSERT INTO messages VALUES('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','assistant','Synthetic answer','{}');
INSERT INTO personalization_profiles VALUES('10000000-0000-0000-0000-000000000001',3,true);
SELECT public.findez_response_feedback('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,NULL,NULL,0,'{}');
SELECT public.findez_response_feedback('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,NULL,NULL,0,'{}');
SELECT pg_temp.check((SELECT count(*)=1 AND min(revision)=1 AND min(learning_generation)=3 FROM response_feedback),'retry deduplicated and opt-in generation captured');
SELECT public.findez_response_feedback('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',-1,'other','Optional comment',1,'{"execution":"not_observed"}');
SELECT pg_temp.check((SELECT revision=2 AND rating=-1 AND comment='Optional comment' FROM response_feedback),'rating and optional details updated');
DO $$ BEGIN
 BEGIN PERFORM public.findez_response_feedback('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,NULL,NULL,1,'{}'); RAISE EXCEPTION 'stale write accepted'; EXCEPTION WHEN serialization_failure THEN RAISE NOTICE 'PASS: stale revision denied'; END;
 BEGIN PERFORM public.findez_response_feedback('10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,NULL,NULL,0,'{}'); RAISE EXCEPTION 'foreign write accepted'; EXCEPTION WHEN no_data_found THEN RAISE NOTICE 'PASS: foreign message denied'; END;
 BEGIN PERFORM public.findez_response_feedback('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',0,NULL,NULL,2,'{}'); RAISE EXCEPTION 'invalid rating accepted'; EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: invalid rating denied'; END;
END $$;
SELECT pg_temp.check(NOT has_table_privilege('authenticated','response_feedback','SELECT') AND NOT has_table_privilege('authenticated','response_feedback','INSERT'),'no unrestricted client reads or writes');
SELECT pg_temp.check(NOT has_function_privilege('authenticated','findez_response_feedback(uuid,uuid,integer,text,text,bigint,jsonb)','EXECUTE'),'client cannot impersonate service actor');
SELECT pg_temp.check((SELECT relrowsecurity FROM pg_class WHERE oid='response_feedback'::regclass),'RLS enabled');
UPDATE response_feedback SET updated_at=now()-interval '31 days';
SELECT findez_response_feedback_cleanup();
SELECT pg_temp.check((SELECT comment IS NULL FROM response_feedback),'comments expire after 30 days');
UPDATE response_feedback SET updated_at=now()-interval '181 days';
SELECT findez_response_feedback_cleanup();
SELECT pg_temp.check((SELECT count(*)=0 FROM response_feedback),'ratings expire after 180 days');
UPDATE personalization_profiles SET enabled=false,generation=4;
SELECT public.findez_response_feedback('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,NULL,NULL,0,'{}');
SELECT pg_temp.check((SELECT learning_generation IS NULL FROM response_feedback),'opted-out feedback excluded from learning');
DELETE FROM messages;
SELECT pg_temp.check((SELECT count(*)=0 FROM response_feedback),'message deletion cascades');
INSERT INTO messages VALUES('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','assistant','Synthetic answer','{}');
SELECT public.findez_response_feedback('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,NULL,NULL,0,'{}');
DELETE FROM auth.users;
SELECT pg_temp.check((SELECT count(*)=0 FROM response_feedback),'account deletion cascades');

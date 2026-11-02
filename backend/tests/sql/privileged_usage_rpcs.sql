-- ONLY on an isolated restored database. Uses existing references inside a
-- rolled-back transaction; no account details are emitted by the assertions.
\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.assert_ok(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF; END $$;
CREATE TEMP TABLE qa_refs AS SELECT tm.team_id,tm.user_id FROM public.team_memberships tm JOIN auth.users u ON u.id=tm.user_id LIMIT 1;
SELECT pg_temp.assert_ok(EXISTS(SELECT 1 FROM qa_refs),'restore contains membership fixture');
GRANT SELECT ON qa_refs TO authenticated,service_role;
DO $$ DECLARE fn text; who text; BEGIN
 FOREACH fn IN ARRAY ARRAY['increment_chat_usage(uuid,text)','increment_scan_usage(uuid,text)',
 'increment_usage_count(uuid,text,text)','increment_team_chat_usage(uuid,text)',
 'increment_team_scan_usage(uuid,text)','increment_team_import_usage(uuid,text)',
 'consume_api_key_rate_limit(uuid,text,integer)'] LOOP
  FOREACH who IN ARRAY ARRAY['anon','authenticated'] LOOP
   PERFORM pg_temp.assert_ok(NOT has_function_privilege(who,'public.'||fn,'EXECUTE'),who||' cannot call '||fn);
  END LOOP;
  PERFORM pg_temp.assert_ok(has_function_privilege('service_role','public.'||fn,'EXECUTE'),'backend can call '||fn);
 END LOOP;
END $$;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.increment_chat_usage(gen_random_uuid(),'qa'); RAISE EXCEPTION 'anonymous mutation admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_is_team_member(gen_random_uuid(),gen_random_uuid()); RAISE EXCEPTION 'anonymous membership probe admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims',json_build_object('sub',user_id,'role','authenticated')::text,true) FROM qa_refs;
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_ok(public.findez_is_team_member(team_id,user_id),'member can check own membership') FROM qa_refs;
SELECT pg_temp.assert_ok(EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=(SELECT team_id FROM qa_refs)),'roster RLS remains readable');
SELECT set_config('request.jwt.claims',json_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
SELECT pg_temp.assert_ok(NOT public.findez_is_team_member(team_id,user_id),'outsider cannot probe another user') FROM qa_refs;
DO $$ BEGIN
 BEGIN PERFORM public.increment_scan_usage(gen_random_uuid(),'qa'); RAISE EXCEPTION 'authenticated counter forgery admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_ok(public.findez_is_team_member(team_id,user_id),'service membership check remains available') FROM qa_refs;
SELECT pg_temp.assert_ok((SELECT chats_used FROM public.increment_chat_usage((SELECT user_id FROM qa_refs),'qa-final-audit'))=1,'backend chat increment');
SELECT pg_temp.assert_ok((SELECT chats_used FROM public.increment_chat_usage((SELECT user_id FROM qa_refs),'qa-final-audit'))=2,'backend repeated increment');
SELECT pg_temp.assert_ok((SELECT scans_used FROM public.increment_scan_usage((SELECT user_id FROM qa_refs),'qa-final-audit'))=1,'backend scan increment');
SELECT pg_temp.assert_ok(public.increment_usage_count((SELECT user_id FROM qa_refs),'qa','qa-final-audit')=1,'backend usage increment');
SELECT pg_temp.assert_ok((SELECT chats_used FROM public.increment_team_chat_usage((SELECT team_id FROM qa_refs),'qa-final-audit'))=1,'team chat increment');
SELECT pg_temp.assert_ok((SELECT scans_used FROM public.increment_team_scan_usage((SELECT team_id FROM qa_refs),'qa-final-audit'))=1,'team scan increment');
SELECT pg_temp.assert_ok((SELECT imports_used FROM public.increment_team_import_usage((SELECT team_id FROM qa_refs),'qa-final-audit'))=1,'team import increment');
DO $$ DECLARE k uuid; BEGIN
 SELECT id INTO k FROM public.api_keys LIMIT 1;
 IF k IS NOT NULL THEN
  PERFORM pg_temp.assert_ok(public.consume_api_key_rate_limit(k,'qa-final-audit',1),'service rate limit first request');
  PERFORM pg_temp.assert_ok(NOT public.consume_api_key_rate_limit(k,'qa-final-audit',1),'service rate limit still blocks excess');
 END IF;
END $$;
RESET ROLE;
ROLLBACK;
\echo Privileged RPC rejection, membership isolation, roster and service positive controls passed.

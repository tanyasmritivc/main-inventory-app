-- Only on an isolated restored database; all fixture changes roll back.
\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.assert_ok(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF; END $$;
CREATE TEMP TABLE qa_profile AS SELECT id FROM public.profiles LIMIT 1;
GRANT SELECT ON qa_profile TO authenticated,service_role;
SELECT pg_temp.assert_ok(EXISTS(SELECT 1 FROM qa_profile),'existing profile available');
DO $$ DECLARE c text; r text; BEGIN
 FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
  FOREACH c IN ARRAY ARRAY['tier','is_pro','plan','avatar_path','pending_deletion','deletion_scheduled_at','stripe_customer_id','stripe_subscription_id','rc_customer_id','pro_expires_at','subscription_plan','subscription_renews_at','created_at'] LOOP
   PERFORM pg_temp.assert_ok(NOT has_column_privilege(r,'public.profiles',c,'INSERT') AND NOT has_column_privilege(r,'public.profiles',c,'UPDATE'),r||' cannot forge '||c);
  END LOOP;
  PERFORM pg_temp.assert_ok(NOT has_table_privilege(r,'public.profiles','DELETE'),r||' cannot delete profile');
 END LOOP;
END $$;
SELECT set_config('request.jwt.claims',json_build_object('sub',id,'role','authenticated')::text,true) FROM qa_profile;
SET LOCAL ROLE authenticated;
INSERT INTO public.profiles(id,display_name,first_name,last_name,profile_role,organization)
 SELECT id,'QA','Release','Test','QA','QA' FROM qa_profile
 ON CONFLICT(id) DO UPDATE SET display_name=EXCLUDED.display_name,first_name=EXCLUDED.first_name,last_name=EXCLUDED.last_name,profile_role=EXCLUDED.profile_role,organization=EXCLUDED.organization;
SELECT pg_temp.assert_ok((SELECT display_name='QA' FROM public.profiles WHERE id=(SELECT id FROM qa_profile)),'signup profile upsert remains functional');
UPDATE public.profiles SET contact_email='qa@example.invalid',avatar_color='#123456' WHERE id=(SELECT id FROM qa_profile);
DO $$ BEGIN
 BEGIN UPDATE public.profiles SET is_pro=true WHERE id=(SELECT id FROM qa_profile); RAISE EXCEPTION 'entitlement write admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.profiles SET avatar_path='foreign/avatar.jpg' WHERE id=(SELECT id FROM qa_profile); RAISE EXCEPTION 'avatar forgery admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE service_role;
UPDATE public.profiles SET avatar_path='qa/avatar.jpg',tier='pro',is_pro=true WHERE id=(SELECT id FROM qa_profile);
SELECT pg_temp.assert_ok((SELECT is_pro AND tier='pro' FROM public.profiles WHERE id=(SELECT id FROM qa_profile)),'backend profile/entitlement writes retained');
RESET ROLE;
ROLLBACK;
\echo Profile entitlement isolation, native/web upsert and backend positive controls passed.

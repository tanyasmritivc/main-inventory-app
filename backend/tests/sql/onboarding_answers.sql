-- Shares only the disposable test schema created by api_key_rls.sql.
RESET ROLE;
CREATE TABLE IF NOT EXISTS auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users VALUES ('90000000-0000-0000-0000-000000000001'),('90000000-0000-0000-0000-000000000002');
\ir ../../supabase/migrations/041_onboarding_answers.sql
SET ROLE service_role;
INSERT INTO public.onboarding_responses(user_id,use_case,inventory_types,primary_goal,collaboration) VALUES
('90000000-0000-0000-0000-000000000001','household',ARRAY['tools'],'find_items','solo'),
('90000000-0000-0000-0000-000000000002','laboratory',ARRAY['equipment'],'track_stock','others');
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-000000000001"}',false);
SELECT pg_temp.check((SELECT count(*)=1 FROM public.onboarding_responses),'setup answers are owner-readable only');
SELECT pg_temp.check((SELECT use_case='household' FROM public.onboarding_responses),'other user answers stay hidden');
DO $$ BEGIN
  BEGIN UPDATE public.onboarding_responses SET use_case='business'; RAISE EXCEPTION 'direct update accepted';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: direct answer updates are backend-only'; END;
  BEGIN DELETE FROM public.onboarding_responses; RAISE EXCEPTION 'direct deletion accepted';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: direct answer deletion is backend-only'; END;
END $$;
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-000000000001","api_key_id":"key"}',false);
SELECT pg_temp.check((SELECT count(*)=0 FROM public.onboarding_responses),'integration keys cannot read onboarding answers');
RESET ROLE;
SET ROLE anon;
DO $$ BEGIN
  BEGIN PERFORM * FROM public.onboarding_responses; RAISE EXCEPTION 'anonymous answers exposed';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: anonymous answer access denied'; END;
END $$;
RESET ROLE;
DO $$ BEGIN
  BEGIN UPDATE public.onboarding_responses SET inventory_types=ARRAY['not-supported']; RAISE EXCEPTION 'invalid inventory accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: bounded inventory choices'; END;
  BEGIN UPDATE public.onboarding_responses SET use_case='other'; RAISE EXCEPTION 'missing Other label accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: required custom use label'; END;
  BEGIN UPDATE public.onboarding_responses SET inventory_other='Unchosen'; RAISE EXCEPTION 'unselected Other label accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: no stray custom inventory label'; END;
END $$;
DELETE FROM auth.users WHERE id='90000000-0000-0000-0000-000000000001';
SELECT pg_temp.check((SELECT count(*)=0 FROM public.onboarding_responses WHERE user_id='90000000-0000-0000-0000-000000000001'),'account deletion cascades to setup answers');
SELECT pg_temp.check((SELECT count(*)=1 FROM public.onboarding_responses),'account deletion preserves other answers');
DELETE FROM auth.users WHERE id='90000000-0000-0000-0000-000000000002';

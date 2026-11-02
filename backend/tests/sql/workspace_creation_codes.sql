-- Disposable fixtures only. Includes actual production alphabet and collision.
BEGIN;
CREATE TEMP TABLE code_cases AS SELECT public.findez_workspace_join_code() AS code FROM generate_series(1,1000);
SELECT pg_temp.check(NOT EXISTS(SELECT 1 FROM code_cases WHERE code !~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$'),'every generated code satisfies the production alphabet');
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_workspace_join_code()','EXECUTE'),'clients cannot invoke private workspace generator');
DO $$
DECLARE actor uuid:='b0000000-0000-0000-0000-000000000001'; org uuid; ws uuid; i integer; total integer;
BEGIN
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Code fixtures"}')->>'organization_id')::uuid;
 FOR i IN 1..40 LOOP
  ws:=(public.findez_manage_collaboration(actor,'workspace_create',jsonb_build_object('organization_id',org,'name','Code fixture '||i))->>'team_id')::uuid;
  PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=actor AND role='owner'),'workspace and owner membership saved together');
 END LOOP;
 SELECT count(*) INTO total FROM public.teams WHERE organization_id=org;
 PERFORM pg_temp.check(total=40,'repeated workspace creation has no random alphabet failures');
 BEGIN
  PERFORM public.findez_manage_collaboration('b0000000-0000-0000-0000-000000000038','workspace_create',jsonb_build_object('organization_id',org,'name','Forbidden workspace'));
  RAISE EXCEPTION 'Outsider created workspace';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
-- Force a real unique violation on the first generated code, then succeed.
CREATE SEQUENCE public.fixture_workspace_code_counter;
UPDATE public.teams SET join_code='AAAAAA' WHERE team_id=(SELECT team_id FROM public.teams ORDER BY team_id LIMIT 1);
CREATE OR REPLACE FUNCTION public.findez_workspace_join_code() RETURNS text LANGUAGE sql VOLATILE AS $$
 SELECT CASE WHEN nextval('public.fixture_workspace_code_counter')=1 THEN 'AAAAAA' ELSE 'BBBBBB' END;
$$;
DO $$
DECLARE actor uuid:='b0000000-0000-0000-0000-000000000001'; org uuid; ws uuid;
BEGIN
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Collision fixture"}')->>'organization_id')::uuid;
 ws:=(public.findez_manage_collaboration(actor,'workspace_create',jsonb_build_object('organization_id',org,'name','Collision workspace'))->>'team_id')::uuid;
 PERFORM pg_temp.check((SELECT join_code='BBBBBB' FROM public.teams WHERE team_id=ws),'real join code collision retried');
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.teams WHERE organization_id=org),'collision does not duplicate workspace');
END $$;
-- Bound repeated collisions and prove the failed operation leaves no partial row.
CREATE OR REPLACE FUNCTION public.findez_workspace_join_code() RETURNS text LANGUAGE sql VOLATILE AS $$ SELECT 'AAAAAA'::text; $$;
DO $$
DECLARE actor uuid:='b0000000-0000-0000-0000-000000000001'; org uuid;
BEGIN
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Exhausted collision fixture"}')->>'organization_id')::uuid;
 BEGIN
  PERFORM public.findez_manage_collaboration(actor,'workspace_create',jsonb_build_object('organization_id',org,'name','Must not persist'));
  RAISE EXCEPTION 'Repeated collision should fail';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.teams WHERE organization_id=org),'exhausted retries leave no partial workspace');
END $$;
ROLLBACK;

-- Disposable database only; exercise the directory RPC used by the web route.
BEGIN;
SELECT set_config('request.jwt.claims','{}',true);
SELECT set_config('request.headers','{}',true);
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT
 ('d7200000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'directory-'||n||'@example.invalid',now() FROM generate_series(1,6) n;
DO $$
DECLARE owner_id uuid:='d7200000-0000-0000-0000-000000000001';
 admin_id uuid:='d7200000-0000-0000-0000-000000000002';
 editor_id uuid:='d7200000-0000-0000-0000-000000000003';
 viewer_id uuid:='d7200000-0000-0000-0000-000000000004';
 outsider uuid:='d7200000-0000-0000-0000-000000000005';
 member_id uuid:='d7200000-0000-0000-0000-000000000006';
 org uuid; ws uuid; inv uuid; personal uuid; a uuid; value jsonb;
BEGIN
 org:=(public.findez_manage_collaboration(owner_id,'organization_create','{"name":"Directory regression"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members(organization_id,user_id,role) VALUES(org,admin_id,'admin'),(org,editor_id,'member'),(org,viewer_id,'member'),(org,member_id,'member');
 ws:=(public.findez_manage_collaboration(owner_id,'workspace_create',jsonb_build_object('organization_id',org,'name','Directory workspace'))->>'team_id')::uuid;
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,editor_id,'member'),(ws,viewer_id,'viewer');
 INSERT INTO public.app_inventories(owner_user_id,team_id,name,access_mode,directory_visibility) VALUES(owner_id,ws,'Hidden inventory','restricted','hidden') RETURNING inventory_id INTO inv;
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,admin_id,'none');
 INSERT INTO public.app_inventories(owner_user_id,name) VALUES(owner_id,'Personal') RETURNING inventory_id INTO personal;
 FOREACH a IN ARRAY ARRAY[owner_id,admin_id] LOOP
  value:=public.findez_workspace_directory(a,'list',jsonb_build_object('workspace_id',ws));
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(value->'inventories') e WHERE e->>'inventory_id'=inv::text AND (e->>'can_open')::boolean AND (e->>'can_manage')::boolean) THEN RAISE EXCEPTION 'Admin directory did not return hidden inventory'; END IF;
  PERFORM public.findez_workspace_directory(a,'requests',jsonb_build_object('workspace_id',ws));
  PERFORM public.findez_workspace_directory(a,'entry',jsonb_build_object('inventory_id',inv));
 END LOOP;
 FOREACH a IN ARRAY ARRAY[editor_id,viewer_id] LOOP
  value:=public.findez_workspace_directory(a,'list',jsonb_build_object('workspace_id',ws));
  IF value->>'total'<>'0' THEN RAISE EXCEPTION 'Restricted inventory leaked'; END IF;
 END LOOP;
 FOREACH a IN ARRAY ARRAY[outsider,member_id] LOOP
  BEGIN PERFORM public.findez_workspace_directory(a,'list',jsonb_build_object('workspace_id',ws)); RAISE EXCEPTION 'Unassigned account opened directory'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.findez_workspace_directory(a,'requests',jsonb_build_object('workspace_id',ws)); RAISE EXCEPTION 'Unassigned account read access requests'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
 value:=public.findez_workspace_directory(admin_id,'list','{"workspace_id":"personal"}');
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(value->'inventories') e WHERE e->>'inventory_id'=personal::text) THEN RAISE EXCEPTION 'Private inventory leaked'; END IF;
 UPDATE public.app_organization_members SET role='member' WHERE organization_id=org AND user_id=admin_id;
 BEGIN PERFORM public.findez_workspace_directory(admin_id,'list',jsonb_build_object('workspace_id',ws)); RAISE EXCEPTION 'Demoted admin retained access'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.app_organization_members SET role='admin' WHERE organization_id=org AND user_id=admin_id;
 UPDATE auth.users SET banned_until=now()+interval '1 hour' WHERE id=admin_id;
 BEGIN PERFORM public.findez_workspace_directory(admin_id,'list',jsonb_build_object('workspace_id',ws)); RAISE EXCEPTION 'Suspended admin retained access'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE auth.users SET banned_until=NULL WHERE id=admin_id;
 DELETE FROM public.app_organization_members WHERE organization_id=org AND user_id=admin_id;
 BEGIN PERFORM public.findez_workspace_directory(admin_id,'list',jsonb_build_object('workspace_id',ws)); RAISE EXCEPTION 'Removed admin retained access'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;

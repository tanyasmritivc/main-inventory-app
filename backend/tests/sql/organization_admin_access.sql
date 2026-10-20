-- Disposable database only. Run after the previous permission-policy fixtures.
\ir ../../supabase/migrations/022_team_board.sql
\ir ../../supabase/migrations/068_organization_admin_access.sql
\ir ../../supabase/migrations/068_organization_admin_access.sql
CREATE OR REPLACE FUNCTION pg_temp.check_org_access(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAILED: %',label; END IF; END $$;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT
 ('d6200000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'orgaccess'||n||'@example.invalid',now() FROM generate_series(1,5) n ON CONFLICT DO NOTHING;
DO $$
DECLARE owner_id uuid:='d6200000-0000-0000-0000-000000000001';
 admin_id uuid:='d6200000-0000-0000-0000-000000000002';
 editor uuid:='d6200000-0000-0000-0000-000000000003';
 viewer uuid:='d6200000-0000-0000-0000-000000000004';
 outsider uuid:='d6200000-0000-0000-0000-000000000005';
 org uuid; ws uuid; inv uuid; personal uuid; task uuid; r record; expected text;
BEGIN
 org:=(public.findez_manage_collaboration(owner_id,'organization_create','{"name":"Admin access test"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members(organization_id,user_id,role) VALUES(org,admin_id,'admin'),(org,editor,'member'),(org,viewer,'member');
 ws:=(public.findez_manage_collaboration(owner_id,'workspace_create',jsonb_build_object('organization_id',org,'name','Access test workspace'))->>'team_id')::uuid;
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,editor,'member'),(ws,viewer,'viewer');
 INSERT INTO public.app_inventories(owner_user_id,team_id,name,access_mode) VALUES(owner_id,ws,'Access test inventory','restricted') RETURNING inventory_id INTO inv;
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,owner_id,'none'),(inv,admin_id,'none'),(inv,editor,'editor'),(inv,viewer,'viewer');
 PERFORM pg_temp.check_org_access(public.findez_workspace_role(ws,admin_id)='mentor','org admin opens workspace without explicit membership');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,owner_id)='owner','org owner overrides explicit none');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,admin_id)='admin','org admin overrides restricted and explicit none');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,editor)='editor','ordinary Editor custom permission');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,viewer)='viewer','Viewer remains read-only');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,outsider) IS NULL,'other organization cannot access');
 INSERT INTO public.app_inventories(owner_user_id,name) VALUES(editor,'Private inventory') RETURNING inventory_id INTO personal;
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(personal,admin_id) IS NULL,'organization admin cannot access personal inventory');
 UPDATE public.app_organization_members SET role='member' WHERE organization_id=org AND user_id=admin_id;
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,admin_id) IS NULL,'admin demotion immediately removes automatic access');
 UPDATE public.app_organization_members SET role='admin' WHERE organization_id=org AND user_id=admin_id;
 UPDATE auth.users SET banned_until=now()+interval '1 hour' WHERE id=admin_id;
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,admin_id) IS NULL,'banned admin cannot access');
 UPDATE auth.users SET banned_until=NULL WHERE id=admin_id;
 PERFORM pg_temp.check_org_access(public.findez_can_invite_access(admin_id,'organization',org,'admin'),'org admin may grant admin');
 PERFORM pg_temp.check_org_access(public.findez_can_invite_access(admin_id,'workspace',ws,'admin'),'org admin may grant workspace admin');
 BEGIN PERFORM public.findez_delete_empty_organization(admin_id,org,'Admin access test'); RAISE EXCEPTION 'Admin deleted organization'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',false);
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',editor)::text,false);
 UPDATE public.app_inventories SET name='Editor renamed' WHERE inventory_id=inv;
 UPDATE public.teams SET name='Editor workspace' WHERE team_id=ws;
 BEGIN UPDATE public.app_inventories SET access_mode='workspace' WHERE inventory_id=inv; RAISE EXCEPTION 'Editor changed access'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN DELETE FROM public.app_inventories WHERE inventory_id=inv; RAISE EXCEPTION 'Editor deleted inventory'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',viewer)::text,false);
 BEGIN UPDATE public.app_inventories SET name='Viewer renamed' WHERE inventory_id=inv; RAISE EXCEPTION 'Viewer renamed inventory'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.teams SET name='Viewer renamed' WHERE team_id=ws; RAISE EXCEPTION 'Viewer renamed workspace'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',admin_id)::text,false);
 UPDATE public.app_organizations SET name='Admin renamed organization' WHERE organization_id=org;
 INSERT INTO public.team_board_tasks(team_id,created_by,assigned_to,assigned_by,title) VALUES(ws,editor,viewer,outsider,'Assignment attribution') RETURNING task_id INTO task;
 PERFORM pg_temp.check_org_access((SELECT assigned_by=admin_id FROM public.team_board_tasks WHERE task_id=task),'assignment records actual actor, not supplied actor');
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',editor)::text,false);
 UPDATE public.team_board_tasks SET assigned_to=admin_id WHERE task_id=task;
 PERFORM pg_temp.check_org_access((SELECT assigned_by=editor FROM public.team_board_tasks WHERE task_id=task),'reassignment updates actual actor');
 UPDATE public.team_board_tasks SET assigned_by=outsider,status='doing' WHERE task_id=task;
 PERFORM pg_temp.check_org_access((SELECT assigned_by=editor FROM public.team_board_tasks WHERE task_id=task),'status edit cannot forge attribution');
 UPDATE public.team_board_tasks SET assigned_to=NULL WHERE task_id=task;
 PERFORM pg_temp.check_org_access((SELECT assigned_by IS NULL FROM public.team_board_tasks WHERE task_id=task),'unassignment clears attribution');
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',admin_id)::text,false);
 UPDATE public.teams SET join_code='ACXZYR' WHERE team_id=ws;
 PERFORM pg_temp.check_org_access((SELECT join_code_created_by=admin_id FROM public.teams WHERE team_id=ws),'link records issuer');
 PERFORM set_config('request.jwt.claims','{}',false);
 PERFORM set_config('request.headers','{}',false);
 BEGIN PERFORM public.findez_transfer_resource_owner(admin_id,'organization',org,owner_id,'Admin renamed organization'); RAISE EXCEPTION 'Transfer demoted current owner'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM public.findez_transfer_resource_owner(admin_id,'organization',org,editor,'Admin renamed organization');
 PERFORM pg_temp.check_org_access((SELECT role='owner' FROM public.app_organization_members WHERE organization_id=org AND user_id=editor),'admin transfer assigns new owner');
 PERFORM pg_temp.check_org_access((SELECT role='admin' FROM public.app_organization_members WHERE organization_id=org AND user_id=owner_id),'admin transfer demotes previous owner, not actor');
END $$;

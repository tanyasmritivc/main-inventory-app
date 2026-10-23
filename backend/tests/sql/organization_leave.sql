-- Only loaded by the disposable permission fixture.
CREATE TABLE IF NOT EXISTS public.team_members (member_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),share_id uuid REFERENCES public.team_shares(share_id),member_user_id uuid NOT NULL);
\ir ../../supabase/migrations/069_leave_organization.sql
\ir ../../supabase/migrations/069_leave_organization.sql
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT
 ('d6900000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'orgleave'||n||'@example.invalid',now() FROM generate_series(1,5) n;
DO $$
DECLARE owner_id uuid:='d6900000-0000-0000-0000-000000000001';
 member uuid:='d6900000-0000-0000-0000-000000000002';
 admin_id uuid:='d6900000-0000-0000-0000-000000000003';
 outsider uuid:='d6900000-0000-0000-0000-000000000004';
 ws_owner uuid:='d6900000-0000-0000-0000-000000000005';
 org uuid; other_org uuid; ws uuid; other_ws uuid; owned_ws uuid; inv uuid; personal uuid; share uuid; task uuid; result jsonb;
BEGIN
 org:=(public.findez_manage_collaboration(owner_id,'organization_create','{"name":"Leave test"}')->>'organization_id')::uuid;
 other_org:=(public.findez_manage_collaboration(owner_id,'organization_create','{"name":"Other organization"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members VALUES(org,member,'member'),(org,admin_id,'admin'),(org,ws_owner,'admin'),(other_org,member,'member');
 ws:=(public.findez_manage_collaboration(owner_id,'workspace_create',jsonb_build_object('organization_id',org,'name','Team work'))->>'team_id')::uuid;
 other_ws:=(public.findez_manage_collaboration(owner_id,'workspace_create',jsonb_build_object('organization_id',other_org,'name','Unrelated work'))->>'team_id')::uuid;
 owned_ws:=(public.findez_manage_collaboration(ws_owner,'workspace_create',jsonb_build_object('organization_id',org,'name','Owned work'))->>'team_id')::uuid;
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,member,'viewer'),(other_ws,member,'member');
 INSERT INTO public.app_inventories(owner_user_id,team_id,name,access_mode) VALUES(owner_id,ws,'Restricted collection','restricted') RETURNING inventory_id INTO inv;
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,member,'viewer'),(inv,admin_id,'none');
 INSERT INTO public.app_inventories(owner_user_id,name) VALUES(member,'Personal collection') RETURNING inventory_id INTO personal;
 INSERT INTO public.team_shares(owner_user_id,inventory_id) VALUES(owner_id,inv) RETURNING share_id INTO share;
 INSERT INTO public.team_members(share_id,member_user_id) VALUES(share,member),(share,admin_id);
 INSERT INTO public.team_board_tasks(team_id,created_by,assigned_to,title) VALUES(ws,member,member,'Retained task') RETURNING task_id INTO task;
 INSERT INTO public.app_access_invitations(scope,resource_id,resource_name,organization_id,recipient_email,invited_by,invited_by_name,role,code_hash)
 VALUES('organization',org,'Leave test',org,'orgleave2@example.invalid',owner_id,'Owner','member',repeat('6',64));
 BEGIN PERFORM public.findez_leave_organization(outsider,org,'Leave test'); RAISE EXCEPTION 'Outsider left'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_leave_organization(owner_id,org,'Leave test'); RAISE EXCEPTION 'Owner left'; EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN PERFORM public.findez_leave_organization(ws_owner,org,'Leave test'); RAISE EXCEPTION 'Workspace owner left'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 BEGIN PERFORM public.findez_leave_organization(member,org,'Wrong name'); RAISE EXCEPTION 'Wrong confirmation'; EXCEPTION WHEN serialization_failure THEN NULL; END;
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,member)='viewer','failed leave preserves Viewer');
 result:=public.findez_leave_organization(member,org,'Leave test');
 PERFORM pg_temp.check_org_access(result->>'left'='true' AND result->>'organization_id'=org::text,'exact leave receipt');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,member) IS NULL,'inventory denied after leave');
 PERFORM pg_temp.check_org_access(public.findez_workspace_role(ws,member) IS NULL,'workspace denied after leave');
 PERFORM pg_temp.check_org_access(NOT EXISTS(SELECT 1 FROM public.app_inventory_members WHERE inventory_id=inv AND user_id=member),'custom grant removed');
 PERFORM pg_temp.check_org_access(NOT EXISTS(SELECT 1 FROM public.team_members WHERE share_id=share AND member_user_id=member),'explicit Space share revoked');
 PERFORM pg_temp.check_org_access(EXISTS(SELECT 1 FROM public.team_board_tasks WHERE task_id=task AND created_by=member),'task content and attribution retained');
 PERFORM pg_temp.check_org_access((SELECT status='cancelled' FROM public.app_access_invitations WHERE code_hash=repeat('6',64)),'old pending invitation cannot restore access');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(personal,member)='owner','personal preserved');
 PERFORM pg_temp.check_org_access(public.findez_workspace_role(other_ws,member)='member','other organization preserved');
 PERFORM pg_temp.check_org_access(public.findez_leave_organization(member,org,'Leave test')=result,'lost-response retry');
 PERFORM public.findez_leave_organization(admin_id,org,'Leave test');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,admin_id) IS NULL,'automatic admin access revoked');
 PERFORM pg_temp.check_org_access((SELECT count(*)=3 FROM public.teams WHERE organization_id IN (org,other_org)),'workspace contents retained');
 PERFORM pg_temp.check_org_access(EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=inv),'inventory retained');
 INSERT INTO public.app_organization_members VALUES(org,member,'member');
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,member,'viewer');
 PERFORM pg_temp.check_org_access(public.findez_inventory_role(inv,member) IS NULL,'rejoin cannot resurrect restricted grant');
 PERFORM pg_temp.check_org_access(NOT has_function_privilege('authenticated','public.findez_leave_organization(uuid,uuid,text)','EXECUTE'),'RPC service-only');
END $$;

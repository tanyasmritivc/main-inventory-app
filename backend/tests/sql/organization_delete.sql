-- Run after the collaboration fixtures, only in a disposable database.
\ir ../../supabase/migrations/047_empty_organization_delete.sql
SELECT pg_temp.check(NOT has_function_privilege('anon','public.findez_delete_empty_organization(uuid,uuid,text)','EXECUTE'),'anonymous cannot delete organizations directly');
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_delete_empty_organization(uuid,uuid,text)','EXECUTE'),'authenticated cannot forge the delete actor');
SELECT pg_temp.check(has_function_privilege('service_role','public.findez_delete_empty_organization(uuid,uuid,text)','EXECUTE'),'only trusted backend can invoke deletion');
DO $$
DECLARE owner_id uuid:='b0000000-0000-0000-0000-000000000001';
 admin_id uuid:='b0000000-0000-0000-0000-000000000002';
 outsider uuid:='b0000000-0000-0000-0000-000000000003';
 org uuid; workspace uuid; saved jsonb; baseline bigint; invitation uuid;
BEGIN
 org:=(public.findez_manage_collaboration(owner_id,'organization_create','{"name":"Delete fixture"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members VALUES(org,admin_id,'admin');
 SELECT count(*) INTO baseline FROM public.app_access_audit WHERE action='organization_delete';
 BEGIN PERFORM public.findez_delete_empty_organization(admin_id,org,'Delete fixture'); RAISE EXCEPTION 'admin deleted organization';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_delete_empty_organization(outsider,org,'Delete fixture'); RAISE EXCEPTION 'outsider deleted organization';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_delete_empty_organization(NULL,org,'Delete fixture'); RAISE EXCEPTION 'missing actor deleted organization';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_delete_empty_organization(owner_id,org,'Old name'); RAISE EXCEPTION 'stale name deleted organization';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 workspace:=(public.findez_manage_collaboration(owner_id,'workspace_create',jsonb_build_object('organization_id',org,'name','Retained workspace'))->>'team_id')::uuid;
 -- Being absent from the owner's directory cannot make a workspace disposable.
 DELETE FROM public.team_memberships WHERE team_id=workspace AND user_id=owner_id;
 BEGIN PERFORM public.findez_delete_empty_organization(owner_id,org,'Delete fixture'); RAISE EXCEPTION 'nonempty organization deleted';
 EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.teams WHERE team_id=workspace),'unassigned workspace survives blocked deletion');
 PERFORM pg_temp.check((SELECT count(*)=2 FROM public.app_organization_members WHERE organization_id=org),'blocked deletion preserves members');
 PERFORM pg_temp.check((SELECT count(*)=baseline FROM public.app_access_audit WHERE action='organization_delete'),'rejected deletion has no successful audit');
 -- The fixture deliberately detaches its synthetic workspace without deleting it.
 UPDATE public.teams SET organization_id=NULL WHERE team_id=workspace;
 INSERT INTO public.app_access_invitations(scope,resource_id,resource_name,organization_id,recipient_email,invited_by,invited_by_name,role,code_hash)
 VALUES('organization',org,'Delete fixture',org,'delete-fixture@example.invalid',owner_id,'Fixture owner','member',repeat('f',64)) RETURNING invitation_id INTO invitation;
 saved:=public.findez_delete_empty_organization(owner_id,org,'Delete fixture');
 PERFORM pg_temp.check(saved=jsonb_build_object('deleted',true,'organization_id',org),'successful deletion has an exact receipt');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organizations WHERE organization_id=org),'empty organization removed');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org),'memberships removed transactionally');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_access_invitations WHERE invitation_id=invitation),'obsolete invitation removed');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.teams WHERE team_id=workspace AND organization_id IS NULL),'other workspace content survives');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_access_audit WHERE organization_id=org AND action='organization_delete' AND actor_id=owner_id AND target_id=org AND changes->>'members_removed'='2' AND changes->>'invitations_removed'='1'),'deletion audit survives with actor and counts');
 BEGIN PERFORM public.findez_delete_empty_organization(owner_id,org,'Delete fixture'); RAISE EXCEPTION 'replayed deletion succeeded';
 EXCEPTION WHEN no_data_found THEN NULL; END;
END $$;

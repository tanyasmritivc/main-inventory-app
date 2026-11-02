-- Run last in the disposable composed schema: this changes the target policy.
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS banned_until timestamptz;
\ir ../../supabase/migrations/054_consistent_resource_permissions.sql
\ir ../../supabase/migrations/054_consistent_resource_permissions.sql
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT
 ('d4000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'permission'||n||'@example.invalid',now() FROM generate_series(1,7) n;
CREATE TEMP TABLE permission_demo(key text PRIMARY KEY,id uuid);
DO $$
DECLARE actor uuid:='d4000000-0000-0000-0000-000000000001';
 admin_id uuid:='d4000000-0000-0000-0000-000000000002';
 editor uuid:='d4000000-0000-0000-0000-000000000003';
 viewer uuid:='d4000000-0000-0000-0000-000000000004';
 outsider uuid:='d4000000-0000-0000-0000-000000000005';
 org uuid; ws uuid; inv uuid; empty_inv uuid; space_id uuid; role_pair record; mode text; assigned text; expected text; entry jsonb; receipt jsonb;
BEGIN
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Permission organization"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members(organization_id,user_id,role)
  VALUES(org,admin_id,'admin'),(org,editor,'member'),(org,viewer,'member'),(org,outsider,'member');
 ws:=(public.findez_manage_collaboration(actor,'workspace_create',jsonb_build_object('organization_id',org,'name','Permission workspace'))->>'team_id')::uuid;
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,admin_id,'mentor'),(ws,editor,'member'),(ws,viewer,'viewer');
 INSERT INTO public.app_inventories(owner_user_id,team_id,name,access_mode) VALUES(actor,ws,'Permission inventory','workspace') RETURNING inventory_id INTO inv;
 INSERT INTO permission_demo VALUES('owner',actor),('admin',admin_id),('editor',editor),('viewer',viewer),('org',org),('workspace',ws),('inventory',inv);
 FOR mode IN SELECT unnest(ARRAY['legacy','workspace','restricted']) LOOP
  UPDATE public.app_inventories SET access_mode=mode,default_role='viewer' WHERE inventory_id=inv;
  FOR role_pair IN SELECT * FROM (VALUES(actor,'owner'),(admin_id,'admin'),(editor,'editor'),(viewer,'viewer')) r(person,role_name) LOOP
   expected:=CASE WHEN mode='restricted' THEN NULL ELSE role_pair.role_name END;
   PERFORM pg_temp.check(public.findez_inventory_role(inv,role_pair.person) IS NOT DISTINCT FROM expected,'inherited role matrix '||mode||' '||role_pair.role_name);
   FOREACH assigned IN ARRAY ARRAY['admin','editor','viewer','none'] LOOP
    INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,role_pair.person,assigned)
     ON CONFLICT(inventory_id,user_id) DO UPDATE SET role=excluded.role;
    PERFORM pg_temp.check(public.findez_inventory_role(inv,role_pair.person) IS NOT DISTINCT FROM nullif(assigned,'none'),'custom role wins over '||role_pair.role_name||' in '||mode||': '||assigned);
   END LOOP;
   DELETE FROM public.app_inventory_members WHERE inventory_id=inv AND user_id=role_pair.person;
  END LOOP;
 END LOOP;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,outsider) IS NULL,'organization membership grants no workspace content');
 UPDATE public.app_inventories SET access_mode='workspace' WHERE inventory_id=inv;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,editor)='editor','new inherited inventory does not downgrade Editor to Viewer');
 UPDATE public.team_memberships SET role='viewer' WHERE team_id=ws AND user_id=editor;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,editor)='viewer','workspace role change immediately updates inheritance');
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,editor,'editor');
 UPDATE public.team_memberships SET role='member' WHERE team_id=ws AND user_id=editor;
 UPDATE public.team_memberships SET role='viewer' WHERE team_id=ws AND user_id=editor;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,editor)='editor','custom role survives workspace role changes');
 DELETE FROM public.app_inventory_members WHERE inventory_id=inv AND user_id=editor;
 UPDATE public.team_memberships SET role='member' WHERE team_id=ws AND user_id=editor;
 UPDATE public.app_inventories SET access_mode='restricted' WHERE inventory_id=inv;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,actor) IS NULL AND public.findez_can_administer_inventory(inv,actor),'workspace owner administration is separate from restricted content');
 PERFORM pg_temp.check(public.findez_inventory_role(inv,admin_id) IS NULL AND public.findez_can_administer_inventory(inv,admin_id),'workspace admin administration is separate from restricted content');
 entry:=public.findez_directory_entry(inv,admin_id);
 PERFORM pg_temp.check(entry->>'can_open'='false' AND entry->>'can_manage'='true' AND NOT entry ? 'item_count','administration-only directory omits contents and counts');
 PERFORM pg_temp.check(public.findez_directory_entry(inv,editor) IS NULL,'unassigned restricted inventory is not discoverable to editor');
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,editor,'none');
 PERFORM pg_temp.check(public.findez_directory_entry(inv,editor) IS NULL,'No access is not discoverable');
 -- The administrator's explicit self grant requires consent and preserves the
 -- before-assignment snapshot, instead of treating admin authority as content.
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,admin_id,'none');
 receipt:=public.findez_access_invitation(admin_id,'change',jsonb_build_object('scope','inventory','resource_id',inv,'user_id',admin_id,'role','admin','code_hash',repeat('d',64)));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,admin_id) IS NULL,'self invitation alone grants no contents');
 PERFORM public.findez_access_invitation(admin_id,'accept',jsonb_build_object('invitation_id',receipt->>'invitation_id'));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,admin_id)='admin','explicit administrator consent grants requested contents');
 UPDATE public.app_inventory_members SET role='editor' WHERE inventory_id=inv AND user_id=editor;
 INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(actor,inv,'Protected Space') RETURNING id INTO space_id;
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',false);
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',editor)::text,false);
 BEGIN DELETE FROM public.spaces WHERE id=space_id;
  RAISE EXCEPTION 'editor deleted entire Space'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.spaces WHERE id=space_id),'service-role route cannot bypass admin-only Space deletion');
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',admin_id)::text,false);
 DELETE FROM public.spaces WHERE id=space_id;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.spaces WHERE id=space_id),'content admin can delete Space');
 PERFORM set_config('request.jwt.claims','{}',false);
 PERFORM set_config('request.headers','{}',false);
 receipt:=public.findez_create_inventory(actor,ws,'New inherited inventory','workspace');
 PERFORM pg_temp.check(public.findez_inventory_role((receipt->>'inventory_id')::uuid,editor)='editor','atomic inventory creation inherits Editor');
 receipt:=public.findez_create_inventory(admin_id,ws,'New custom inventory','restricted');
 PERFORM pg_temp.check(public.findez_inventory_role((receipt->>'inventory_id')::uuid,admin_id)='admin'
  AND public.findez_inventory_role((receipt->>'inventory_id')::uuid,actor) IS NULL,'custom creation grants creator explicit access without exposing contents to workspace owner');
 -- Concurrent assignment changes cannot be silently overwritten by a stale invite.
 receipt:=public.findez_access_invitation(actor,'change',jsonb_build_object('scope','inventory','resource_id',inv,'user_id',viewer,'role','editor','code_hash',repeat('e',64)));
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,viewer,'viewer');
 BEGIN PERFORM public.findez_access_invitation(viewer,'accept',jsonb_build_object('invitation_id',receipt->>'invitation_id'));
  RAISE EXCEPTION 'stale invitation replaced newer content access'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,viewer)='viewer','stale acceptance cannot replace deliberate newer Viewer assignment');
 -- Administrative deletion does not require reading inventory contents.
 INSERT INTO public.app_inventories(owner_user_id,team_id,name,access_mode) VALUES(actor,ws,'Empty administration-only','restricted') RETURNING inventory_id INTO empty_inv;
 PERFORM public.findez_delete_empty_inventory(admin_id,empty_inv,'Empty administration-only');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=empty_inv),'workspace admin can delete an empty restricted inventory without content access');
 -- Account and parent membership precede every content role.
 UPDATE auth.users SET banned_until=now()+interval '1 hour' WHERE id=admin_id;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,admin_id) IS NULL AND NOT public.findez_can_administer_inventory(inv,admin_id),'suspension rejects content and administration immediately');
 UPDATE auth.users SET banned_until=NULL WHERE id=admin_id;
 DELETE FROM public.app_organization_members WHERE organization_id=org AND user_id=viewer;
 PERFORM pg_temp.check(public.findez_workspace_role(ws,viewer) IS NULL AND public.findez_inventory_role(inv,viewer) IS NULL,'lost organization membership invalidates stale workspace and custom grants');
 INSERT INTO public.app_organization_members VALUES(org,viewer,'member');
 DELETE FROM public.team_memberships WHERE team_id=ws AND user_id=viewer;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,viewer) IS NULL AND NOT EXISTS(SELECT 1 FROM public.app_inventory_members WHERE inventory_id=inv AND user_id=viewer),'workspace removal removes custom access, too');
 -- Only current owners may transfer, with an exact confirmation and current recipient.
 BEGIN PERFORM public.findez_transfer_resource_owner(admin_id,'organization',org,editor,'Permission organization');
  RAISE EXCEPTION 'admin transferred ownership'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_transfer_resource_owner(actor,'workspace',ws,editor,'Wrong name');
  RAISE EXCEPTION 'transfer accepted wrong confirmation'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.findez_transfer_resource_owner(actor,'organization',org,editor,'Permission organization');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=editor AND role='owner'),'organization transfer retains a designated owner');
 PERFORM public.findez_transfer_resource_owner(actor,'workspace',ws,editor,'Permission workspace');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=editor AND role='owner'),'workspace transfer retains a designated owner');
 BEGIN
  UPDATE public.team_memberships SET role='viewer' WHERE team_id=ws AND user_id=editor;
  SET CONSTRAINTS permission_workspace_owner IMMEDIATE;
  RAISE EXCEPTION 'last owner was demoted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 SET CONSTRAINTS permission_workspace_owner DEFERRED;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=editor AND role='owner'),'failed last-owner demotion rolls back');
END $$;
-- Direct JWT and API-key access, independent of HTTP and client controls.
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
INSERT INTO public.spaces(id,user_id,name,inventory_id)
 SELECT 'd4100000-0000-0000-0000-000000000001',i.owner_user_id,'Direct permission Space',i.inventory_id
 FROM public.app_inventories i WHERE i.inventory_id=(SELECT id FROM permission_demo WHERE key='inventory');
INSERT INTO public.items(item_id,user_id,name,category,quantity,location,space_id,inventory_id)
 SELECT 'd4200000-0000-0000-0000-000000000001',i.owner_user_id,'Direct permission part','Hardware',1,'Direct permission Space',
 'd4100000-0000-0000-0000-000000000001',i.inventory_id FROM public.app_inventories i WHERE i.inventory_id=(SELECT id FROM permission_demo WHERE key='inventory');
INSERT INTO public.app_inventory_members(inventory_id,user_id,role)
 SELECT id,'d4000000-0000-0000-0000-000000000003','editor' FROM permission_demo WHERE key='inventory'
 ON CONFLICT(inventory_id,user_id) DO UPDATE SET role=excluded.role;
GRANT SELECT,DELETE ON public.spaces TO authenticated;
ALTER TABLE public.spaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY permission_fixture_allow_space_delete ON public.spaces FOR DELETE TO authenticated USING(true);
CREATE POLICY permission_fixture_allow_space_read ON public.spaces FOR SELECT TO authenticated USING(true);
SET ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"d4000000-0000-0000-0000-000000000003","role":"authenticated"}',false);
SELECT pg_temp.check((SELECT count(*)=1 FROM public.items WHERE item_id='d4200000-0000-0000-0000-000000000001'),'direct JWT Editor reads content');
UPDATE public.items SET quantity=2 WHERE item_id='d4200000-0000-0000-0000-000000000001';
DELETE FROM public.spaces WHERE id='d4100000-0000-0000-0000-000000000001';
RESET ROLE;
SELECT pg_temp.check((SELECT quantity=2 FROM public.items WHERE item_id='d4200000-0000-0000-0000-000000000001'),'direct JWT Editor edits items');
SELECT pg_temp.check(EXISTS(SELECT 1 FROM public.spaces WHERE id='d4100000-0000-0000-0000-000000000001'),'direct JWT Editor cannot delete a Space');
UPDATE public.app_inventory_members SET role='none' WHERE inventory_id=(SELECT id FROM permission_demo WHERE key='inventory') AND user_id='d4000000-0000-0000-0000-000000000003';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=0 FROM public.items WHERE item_id='d4200000-0000-0000-0000-000000000001'),'No access defeats direct JWT ownership');
SELECT pg_temp.check(NOT public.findez_inventory_policy('00000000-0000-0000-0000-000000000000',false),'unknown inventory is fail closed');
SELECT set_config('request.jwt.claims','{"sub":"d4000000-0000-0000-0000-000000000005","role":"authenticated"}',false);
SELECT pg_temp.check((SELECT count(*)=0 FROM public.items WHERE item_id='d4200000-0000-0000-0000-000000000001'),'organization membership cannot bypass direct inventory RLS');
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',false);
DO $$ DECLARE ws uuid; BEGIN
 ws:=(public.findez_create_legacy_workspace('d4000000-0000-0000-0000-000000000006','{"name":"Atomic standalone workspace","program":"custom","custom_category":"Test"}')->>'team_id')::uuid;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id='d4000000-0000-0000-0000-000000000006' AND role='owner'),'standalone creation atomically retains Owner');
 BEGIN
  UPDATE public.teams SET owner_user_id='d4000000-0000-0000-0000-000000000007' WHERE team_id=ws;
  SET CONSTRAINTS permission_workspace_parent_owner IMMEDIATE;
  RAISE EXCEPTION 'parent owner changed without membership';
 EXCEPTION WHEN check_violation THEN NULL; END;
 SET CONSTRAINTS permission_workspace_parent_owner DEFERRED;
END $$;
UPDATE public.app_inventory_members SET role='admin' WHERE inventory_id=(SELECT id FROM permission_demo WHERE key='inventory') AND user_id='d4000000-0000-0000-0000-000000000003';
INSERT INTO public.api_keys(id,workspace_id,org_id,name,key_prefix,key_hash,scopes,created_by)
 SELECT 'd4300000-0000-0000-0000-000000000001',id,'d4000000-0000-0000-0000-000000000003','Permission read key','qa','qa-permission-hash',ARRAY['items:read'],'d4000000-0000-0000-0000-000000000003' FROM permission_demo WHERE key='workspace';
SELECT set_config('request.jwt.claims',jsonb_build_object('sub','d4300000-0000-0000-0000-000000000001','api_key_id','d4300000-0000-0000-0000-000000000001','api_workspace_id',(SELECT id FROM permission_demo WHERE key='workspace'),'api_org_id','d4000000-0000-0000-0000-000000000003','api_scopes','["items:read"]'::jsonb)::text,false);
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=1 FROM public.items WHERE item_id='d4200000-0000-0000-0000-000000000001'),'API key can read a currently authorized owner inventory');
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',false);
UPDATE public.app_inventory_members SET role='none' WHERE inventory_id=(SELECT id FROM permission_demo WHERE key='inventory') AND user_id='d4000000-0000-0000-0000-000000000003';
SELECT set_config('request.jwt.claims',jsonb_build_object('sub','d4300000-0000-0000-0000-000000000001','api_key_id','d4300000-0000-0000-0000-000000000001','api_workspace_id',(SELECT id FROM permission_demo WHERE key='workspace'),'api_org_id','d4000000-0000-0000-0000-000000000003','api_scopes','["items:read"]'::jsonb)::text,false);
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=0 FROM public.items WHERE item_id='d4200000-0000-0000-0000-000000000001'),'No access also defeats API-key content access');
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',false);
DO $$ DECLARE org uuid; actor uuid:='d4000000-0000-0000-0000-000000000006'; admin_id uuid:='d4000000-0000-0000-0000-000000000007'; target uuid:='d4000000-0000-0000-0000-000000000005'; BEGIN
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Organization admin removal policy"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members VALUES(org,admin_id,'admin'),(org,target,'admin');
 PERFORM public.findez_manage_collaboration(admin_id,'organization_member',jsonb_build_object('organization_id',org,'user_id',target,'role','none'));
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=target),'organization Admin can remove a non-owner Admin');
 BEGIN PERFORM public.findez_manage_collaboration(admin_id,'organization_member',jsonb_build_object('organization_id',org,'user_id',actor,'role','none'));
  RAISE EXCEPTION 'Admin removed Owner'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
-- Legacy service queries carry the real actor and cannot use stale role checks.
SELECT set_config('request.jwt.claims','{}',false);
INSERT INTO public.team_memberships(team_id,user_id,role)
 SELECT id,'d4000000-0000-0000-0000-000000000005','member' FROM permission_demo WHERE key='workspace';
SELECT set_config('request.jwt.claims','{"role":"service_role"}',false);
SELECT set_config('request.headers','{"x-findez-actor":"d4000000-0000-0000-0000-000000000005"}',false);
DO $$ BEGIN
 BEGIN UPDATE public.team_memberships SET role='mentor' WHERE team_id=(SELECT id FROM permission_demo WHERE key='workspace') AND user_id='d4000000-0000-0000-0000-000000000005';
  RAISE EXCEPTION 'Editor promoted self'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.app_inventories SET directory_description='unauthorized' WHERE inventory_id=(SELECT id FROM permission_demo WHERE key='inventory');
  RAISE EXCEPTION 'Editor administered inventory'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.headers','{"x-findez-actor":"d4000000-0000-0000-0000-000000000003"}',false);
DO $$ BEGIN
 BEGIN UPDATE public.team_memberships SET role='owner' WHERE team_id=(SELECT id FROM permission_demo WHERE key='workspace') AND user_id='d4000000-0000-0000-0000-000000000005';
  RAISE EXCEPTION 'unconfirmed direct Owner grant'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
DO $$ DECLARE inv uuid; invite jsonb; BEGIN
 inv:=(public.findez_create_inventory('d4000000-0000-0000-0000-000000000003',(SELECT id FROM permission_demo WHERE key='workspace'),'Assignment revision test','restricted')->>'inventory_id')::uuid;
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,'d4000000-0000-0000-0000-000000000002','none');
 invite:=public.findez_access_invitation('d4000000-0000-0000-0000-000000000002','change',jsonb_build_object('scope','inventory','resource_id',inv,'user_id','d4000000-0000-0000-0000-000000000002','role','admin','code_hash',repeat('4',64)));
 UPDATE public.app_inventory_members SET role='none' WHERE inventory_id=inv AND user_id='d4000000-0000-0000-0000-000000000002';
 BEGIN PERFORM public.findez_access_invitation('d4000000-0000-0000-0000-000000000002','accept',jsonb_build_object('invitation_id',invite->>'invitation_id'));
  RAISE EXCEPTION 'reasserted No access was overridden by stale invitation'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(public.findez_inventory_role(inv,'d4000000-0000-0000-0000-000000000002') IS NULL,'reasserting No access invalidates an older consent link');
END $$;

-- Disposable regression fixture: never run against production.
\ir ../../supabase/migrations/070_resource_removal_choices.sql
\ir ../../supabase/migrations/070_resource_removal_choices.sql
BEGIN;
ALTER TABLE public.items ADD COLUMN IF NOT EXISTS bin_id uuid REFERENCES public.bins(id), ADD COLUMN IF NOT EXISTS workspace_id uuid REFERENCES public.teams(team_id);
CREATE OR REPLACE FUNCTION pg_temp.check_removal(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAILED: %',label; END IF; END $$;
SELECT set_config('request.jwt.claims','{}',true);
SELECT set_config('request.headers','{}',true);
DO $$
DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); o uuid; w uuid; i uuid; s uuid; dest uuid; it uuid; bi uuid; r jsonb; other uuid; n text;
BEGIN
 INSERT INTO auth.users(id,email,email_confirmed_at) VALUES(a,a||'@example.invalid',now()),(b,b||'@example.invalid',now()),(c,c||'@example.invalid',now());
 o:=(public.findez_manage_collaboration(a,'organization_create','{"name":"Remove choices"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members VALUES(o,b,'admin'),(o,c,'member');
 w:=(public.findez_manage_collaboration(a,'workspace_create',jsonb_build_object('organization_id',o,'name','Workshop'))->>'team_id')::uuid;
 i:=(public.findez_create_inventory(a,w,'Parts','workspace')->>'inventory_id')::uuid;
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(w,c,'viewer');
 INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(a,i,'Shelf') RETURNING id INTO s;
 INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(a,i,'Bench') RETURNING id INTO dest;
 INSERT INTO public.bins(user_id,inventory_id,space_id,name) VALUES(a,i,s,'Bin') RETURNING id INTO bi;
 INSERT INTO public.items(user_id,inventory_id,space_id,bin_id,name,category,quantity,location) VALUES(a,i,s,bi,'Screw','Supplies',4,'Shelf') RETURNING item_id INTO it;
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',b)::text,true);
 BEGIN PERFORM public.findez_remove_organization_member(b,o,a); RAISE EXCEPTION 'Admin removed Owner'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_remove_resource(b,'organization',o,'Remove choices','delete'); RAISE EXCEPTION 'Admin deleted organization'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_remove_resource(c,'inventory',i,'Parts','delete'); RAISE EXCEPTION 'Viewer deleted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_remove_resource(b,'inventory',i,'Old title','delete'); RAISE EXCEPTION 'Stale name deleted'; EXCEPTION WHEN serialization_failure THEN NULL; END;
 r:=public.findez_removal_preview(b,'space',s);
 PERFORM pg_temp.check_removal(r->>'items'='1' AND r->>'can_move'='true','preview counts');
 r:=public.findez_remove_resource(b,'space',s,'Shelf','move',dest);
 PERFORM pg_temp.check_removal(r->>'deleted'='true' AND NOT EXISTS(SELECT 1 FROM public.spaces WHERE id=s),'source Space removed');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.items WHERE item_id=it AND space_id=dest AND location='Bench' AND quantity=4),'move item intact');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.bins WHERE id=bi AND space_id=dest),'bin intact');
 PERFORM pg_temp.check_removal(public.findez_remove_resource(b,'space',s,'Shelf','move',dest)=r,'retry receipt');
 PERFORM public.findez_remove_organization_member(b,o,c);
 PERFORM pg_temp.check_removal(NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=w AND user_id=c),'workspace memberships automatically revoked');
 PERFORM pg_temp.check_removal(public.findez_inventory_role(i,c) IS NULL,'removed member cannot read');
 -- Nonempty inventory moves intact; no record ID or physical owner changes.
 r:=public.findez_remove_resource(b,'inventory',i,'Parts','move');
 PERFORM pg_temp.check_removal(r->>'moved'='true' AND r->>'deleted'='false','inventory move receipt');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=i AND team_id IS NULL AND owner_user_id=a),'inventory now personal');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.items WHERE item_id=it AND inventory_id=i),'original item retained');
 PERFORM pg_temp.check_removal(public.findez_inventory_role(i,b) IS NULL,'old organization admin cannot read Personal');
 PERFORM set_config('request.headers','{}',true);
 -- Move a Personal inventory into an authorized workspace, preserving IDs.
 other:=(public.findez_manage_collaboration(a,'workspace_create',jsonb_build_object('organization_id',o,'name','Destination'))->>'team_id')::uuid;
 r:=public.findez_remove_resource(a,'inventory',i,'Parts','move',other);
 PERFORM pg_temp.check_removal((SELECT team_id=other FROM public.app_inventories WHERE inventory_id=i),'inventory destination workspace');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.items WHERE item_id=it AND inventory_id=i AND workspace_id=other),'workspace move retains item');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.team_spaces WHERE space_id=dest AND team_id=other),'workspace Space link retained');
 -- Removing this populated workspace can preserve all inventories in Personal.
 PERFORM public.findez_remove_resource(a,'workspace',other,'Destination','move');
 PERFORM pg_temp.check_removal((SELECT team_id IS NULL FROM public.app_inventories WHERE inventory_id=i),'workspace preserve moves inventory to Personal');
 -- Remove whole populated workspace and confirm unrelated Personal is untouched.
 PERFORM set_config('request.headers','{}',true);
 other:=(public.findez_create_inventory(a,w,'Delete contents','workspace')->>'inventory_id')::uuid;
 INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(a,other,'Discard') RETURNING id INTO s;
 INSERT INTO public.items(user_id,inventory_id,space_id,name,category,quantity,location) VALUES(a,other,s,'Discard item','Supplies',2,'Discard');
 r:=public.findez_remove_resource(b,'workspace',w,'Workshop','delete');
 PERFORM pg_temp.check_removal(NOT EXISTS(SELECT 1 FROM public.teams WHERE team_id=w),'workspace deleted');
 PERFORM pg_temp.check_removal(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=other),'children deleted');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.app_inventory_deletions WHERE inventory_id=other),'durable cleanup receipt');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.items WHERE item_id=it),'other inventory preserved');
 -- Admin removes a peer even if that member owns workspaces: ownership stays
 -- with the designated org Owner and all old assignments are revoked.
 w:=(public.findez_manage_collaboration(b,'workspace_create',jsonb_build_object('organization_id',o,'name','Member owned'))->>'team_id')::uuid;
 PERFORM public.findez_remove_organization_member(a,o,b);
 PERFORM pg_temp.check_removal((SELECT owner_user_id=a FROM public.teams WHERE team_id=w),'departing workspace owner replaced');
 PERFORM pg_temp.check_removal(NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=w AND user_id=b),'removed admin assignments revoked');
 -- Organization delete no longer needs workspaces removed beforehand.
 w:=(public.findez_manage_collaboration(a,'workspace_create',jsonb_build_object('organization_id',o,'name','Last workshop'))->>'team_id')::uuid;
 r:=public.findez_remove_resource(a,'organization',o,'Remove choices','delete');
 PERFORM pg_temp.check_removal(NOT EXISTS(SELECT 1 FROM public.app_organizations WHERE organization_id=o),'organization deleted');
 PERFORM pg_temp.check_removal(NOT EXISTS(SELECT 1 FROM public.teams WHERE team_id=w),'organization descendants deleted');
 -- Keeping an organization's workspaces preserves all content and direct members.
 o:=(public.findez_manage_collaboration(a,'organization_create','{"name":"Keep organization contents"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members VALUES(o,b,'member'),(o,c,'member');
 w:=(public.findez_manage_collaboration(a,'workspace_create',jsonb_build_object('organization_id',o,'name','Keep workshop'))->>'team_id')::uuid;
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(w,b,'mentor'),(w,c,'mentor');
 PERFORM public.findez_manage_collaboration(b,'workspace_member',jsonb_build_object('team_id',w,'user_id',c,'role','none'));
 PERFORM pg_temp.check_removal(NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=w AND user_id=c),'workspace Admin removes peer Admin');
 other:=(public.findez_create_inventory(a,w,'Keep inventory','workspace')->>'inventory_id')::uuid;
 PERFORM public.findez_remove_resource(a,'organization',o,'Keep organization contents','move');
 PERFORM pg_temp.check_removal((SELECT organization_id IS NULL FROM public.teams WHERE team_id=w),'workspace preserved outside org');
 PERFORM pg_temp.check_removal(EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=other AND team_id=w),'inventory preserved under workspace');
 PERFORM pg_temp.check_removal(public.findez_workspace_role(w,b)='mentor','direct workspace member keeps access');
 -- Workspace Admin can delete the preserved populated workspace.
 PERFORM public.findez_remove_resource(b,'workspace',w,'Keep workshop','delete');
 PERFORM pg_temp.check_removal(NOT EXISTS(SELECT 1 FROM public.teams WHERE team_id=w),'workspace Admin deletion');
 PERFORM pg_temp.check_removal(NOT has_function_privilege('authenticated','public.findez_remove_resource(uuid,text,uuid,text,text,uuid)','EXECUTE'),'service-only write');
END $$;
ROLLBACK;

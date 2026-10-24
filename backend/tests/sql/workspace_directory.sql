-- Disposable fixture only: discovery metadata never grants content access.
SELECT set_config('request.jwt.claims','{}',false),set_config('request.headers','{}',false);
\ir ../../supabase/migrations/046_workspace_inventory_directory.sql
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_workspace_directory(uuid,text,jsonb)','EXECUTE'),'browser clients cannot forge directory actors');
SELECT pg_temp.check(NOT has_table_privilege('authenticated','public.app_inventory_access_requests','SELECT'),'access requests are not a public membership directory');
DO $$
DECLARE owner_id uuid:=(SELECT id FROM access_demo WHERE key='owner');
 ws uuid:=(SELECT id FROM access_demo WHERE key='robotics');
 inv uuid:=(SELECT id FROM access_demo WHERE key='components');
 member_id uuid:='b0000000-0000-0000-0000-000000000015';
 removed uuid:=(SELECT id FROM access_demo WHERE key='student');
 hidden uuid:=gen_random_uuid(); req uuid; result jsonb; entry jsonb; granted bigint;
BEGIN
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,team_id,name,access_mode,directory_visibility,directory_description)
 VALUES(hidden,owner_id,ws,'Internal finance equipment','restricted','hidden','Private');
 result:=public.findez_workspace_directory(member_id,'list',jsonb_build_object('workspace_id',ws));
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM jsonb_array_elements(result->'inventories') x WHERE x->>'inventory_id'=inv::text),'workspace members discover visible restricted inventories');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(result->'inventories') x WHERE x->>'inventory_id'=hidden::text),'hidden inventories absent from directory');
 entry:=(public.findez_workspace_directory(member_id,'entry',jsonb_build_object('inventory_id',inv)))->'inventory';
 PERFORM pg_temp.check(entry->>'can_open'='false' AND NOT entry ? 'item_count' AND NOT entry ? 'owner_user_id' AND NOT entry ? 'created_by_user_id','restricted metadata excludes counts and ownership details');
 PERFORM pg_temp.check(public.findez_inventory_role(inv,member_id) IS NULL,'directory visibility does not grant inventory role');
 BEGIN PERFORM public.findez_workspace_directory(member_id,'entry',jsonb_build_object('inventory_id',hidden)); RAISE EXCEPTION 'hidden direct lookup leaked'; EXCEPTION WHEN no_data_found THEN NULL; END;
 result:=public.findez_workspace_directory(member_id,'list',jsonb_build_object('workspace_id',ws,'query','Internal finance'));
 PERFORM pg_temp.check((result->>'total')::int=0,'hidden names and descriptions are not searchable');
 BEGIN PERFORM public.findez_workspace_directory(removed,'list',jsonb_build_object('workspace_id',ws)); RAISE EXCEPTION 'removed member discovered workspace'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_workspace_directory(member_id,'settings',jsonb_build_object('inventory_id',inv,'directory_visibility','workspace','description','Forbidden')); RAISE EXCEPTION 'member changed visibility'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 result:=public.findez_workspace_directory(owner_id,'settings',jsonb_build_object('inventory_id',inv,'directory_visibility','workspace','description','  Electrical components  '));
 PERFORM pg_temp.check(result->>'description'='Electrical components','approved directory descriptions persist without changing item data');
 result:=public.findez_workspace_directory(member_id,'request',jsonb_build_object('inventory_id',inv));req:=(result->>'request_id')::uuid;
 PERFORM pg_temp.check(result->>'status'='pending' AND public.findez_inventory_role(inv,member_id) IS NULL,'request grants no access');
 PERFORM pg_temp.check(public.findez_workspace_directory(member_id,'request',jsonb_build_object('inventory_id',inv))->>'request_id'=req::text,'duplicate request is idempotent');
 BEGIN PERFORM public.findez_workspace_directory(member_id,'approve',jsonb_build_object('request_id',req)); RAISE EXCEPTION 'self-approved'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 result:=public.findez_workspace_directory(owner_id,'requests',jsonb_build_object('workspace_id',ws));
 PERFORM pg_temp.check(jsonb_array_length(result)=1 AND NOT result->0 ? 'requester_user_id','administrators receive pending requests without recipient emails');
 PERFORM public.findez_workspace_directory(owner_id,'approve',jsonb_build_object('request_id',req));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,member_id)='viewer','approval grants only explicitly requested viewer access');
 DELETE FROM public.app_inventory_members WHERE inventory_id=inv AND user_id=member_id;
 PERFORM public.findez_workspace_directory(owner_id,'approve',jsonb_build_object('request_id',req));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,member_id) IS NULL,'approved replay cannot restore revoked access');
 result:=public.findez_workspace_directory(member_id,'request',jsonb_build_object('inventory_id',inv));req:=(result->>'request_id')::uuid;
 PERFORM public.findez_workspace_directory(member_id,'cancel',jsonb_build_object('request_id',req));
 PERFORM public.findez_workspace_directory(owner_id,'approve',jsonb_build_object('request_id',req));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,member_id) IS NULL,'cancelled request cannot later grant access');
 result:=public.findez_workspace_directory(member_id,'request',jsonb_build_object('inventory_id',inv));req:=(result->>'request_id')::uuid;
 UPDATE public.app_inventory_access_requests SET expires_at=now()-interval '1 second' WHERE request_id=req;
 BEGIN PERFORM public.findez_workspace_directory(owner_id,'approve',jsonb_build_object('request_id',req)); RAISE EXCEPTION 'expired approval'; EXCEPTION WHEN check_violation THEN NULL; END;
 result:=public.findez_workspace_directory(member_id,'request',jsonb_build_object('inventory_id',inv));req:=(result->>'request_id')::uuid;
 DELETE FROM public.team_memberships WHERE team_id=ws AND user_id=member_id;
 BEGIN PERFORM public.findez_workspace_directory(owner_id,'approve',jsonb_build_object('request_id',req)); RAISE EXCEPTION 'removed requester gained access'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_access_audit WHERE inventory_id=inv AND action='directory_approve'),'approvals retain an audit trail');
END $$;

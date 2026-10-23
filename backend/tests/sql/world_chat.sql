-- Synthetic fixture only. No production account or records are used.
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
\ir ../../supabase/migrations/073_world_chat.sql
\ir ../../supabase/migrations/073_world_chat.sql
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_world_structure_action(uuid,text,uuid,text,jsonb)','EXECUTE'),'world writes are service-only');
CREATE FUNCTION pg_temp.world_proposal(actor uuid, world text, plan jsonb) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE c uuid:=gen_random_uuid(); a uuid:=gen_random_uuid();
BEGIN
 INSERT INTO public.conversations(id,user_id,title,world_key) VALUES(c,actor,'Synthetic world',world);
 INSERT INTO public.messages(conversation_id,role,content,answer_context) VALUES(c,'assistant','Review this plan',
  jsonb_build_object('world_actions',jsonb_build_array(jsonb_build_object('id',a,'world',world,'status','pending','plan',plan,'expires_at',now()+interval '30 minutes'))));
 RETURN a;
END $$;
CREATE FUNCTION pg_temp.world_confirm(actor uuid,world text,a uuid,decision text) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.findez_world_structure_action(actor,world,a,decision,'{"d4000000-0000-0000-0000-000000000003":null,"d4000000-0000-0000-0000-000000000004":null}'::jsonb)
$$;
DO $$
DECLARE actor uuid:='d4000000-0000-0000-0000-000000000003'; member uuid:='d4000000-0000-0000-0000-000000000004';
 org uuid; ws uuid; a uuid; b uuid; inv uuid; place uuid; cid uuid; item_action uuid:=gen_random_uuid(); result jsonb; replay jsonb; plan jsonb; before_hash text; after_hash text;
BEGIN
 SELECT md5(coalesce(string_agg(to_jsonb(i)::text,'' ORDER BY item_id),'')) INTO before_hash FROM public.items i;
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"World chat QA"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members(organization_id,user_id,role) VALUES(org,member,'admin');
 plan:='{"workspace_name":"Workshop","inventories":[{"name":"Hardware","spaces":["Bolts","Motors"]}]}'::jsonb;
 a:=pg_temp.world_proposal(member,org::text,plan);
 result:=pg_temp.world_confirm(member,org::text,a,'confirm');
 replay:=pg_temp.world_confirm(member,org::text,a,'confirm');
 PERFORM pg_temp.check(result=replay AND result->>'status'='confirmed','world confirm replay returns same receipt');
 inv:=(result->'receipt'->'inventories'->0->>'inventory_id')::uuid;
 ws:=(result->'receipt'->>'workspace_id')::uuid;
 PERFORM pg_temp.check((SELECT count(*)=2 FROM public.spaces WHERE inventory_id=inv),'organization Admin creates reviewed Spaces');
 b:=pg_temp.world_proposal(member,org::text,plan);
 result:=pg_temp.world_confirm(member,org::text,b,'confirm');
 PERFORM pg_temp.check((result->'receipt'->'inventories'->0->>'inventory_id')::uuid=inv,'existing exact structure is reused');
 PERFORM pg_temp.check((SELECT count(*)=2 FROM public.spaces WHERE inventory_id=inv),'reuse does not duplicate Spaces');
 SELECT md5(coalesce(string_agg(to_jsonb(i)::text,'' ORDER BY item_id),'')) INTO after_hash FROM public.items i;
 PERFORM pg_temp.check(before_hash=after_hash,'structure creation preserves every existing item byte');
 a:=pg_temp.world_proposal(member,org::text,plan);
 BEGIN PERFORM pg_temp.world_confirm(actor,org::text,a,'confirm'); RAISE EXCEPTION 'foreign author approved'; EXCEPTION WHEN no_data_found THEN NULL; END;
 BEGIN PERFORM pg_temp.world_confirm(member,'personal',a,'confirm'); RAISE EXCEPTION 'wrong world approved'; EXCEPTION WHEN no_data_found THEN NULL; END;
 PERFORM pg_temp.world_confirm(member,org::text,a,'cancel');
 PERFORM pg_temp.check(pg_temp.world_confirm(member,org::text,a,'confirm')->>'status'='cancelled','cancelled review cannot save');
 a:=pg_temp.world_proposal(member,org::text,jsonb_build_object('workspace_id',ws,'inventories',jsonb_build_array(
  jsonb_build_object('name','Rollback test','spaces',jsonb_build_array('Good','')))));
 BEGIN PERFORM pg_temp.world_confirm(member,org::text,a,'confirm'); RAISE EXCEPTION 'invalid plan saved'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE team_id=ws AND name='Rollback test'),'invalid second Space rolls back complete structure');
 a:=pg_temp.world_proposal(member,org::text,plan);
 DELETE FROM public.app_organization_members WHERE organization_id=org AND user_id=member;
 BEGIN PERFORM pg_temp.world_confirm(member,org::text,a,'confirm'); RAISE EXCEPTION 'removed member approved'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.app_organization_members(organization_id,user_id,role) VALUES(org,member,'admin');
 -- Organization-wide chat still uses the existing atomic item action.
 SELECT id INTO place FROM public.spaces WHERE inventory_id=inv AND name='Bolts';
 cid:=gen_random_uuid();
 INSERT INTO public.conversations(id,user_id,title,world_key) VALUES(cid,member,'World item review',org::text);
 INSERT INTO public.messages(conversation_id,role,content,answer_context) VALUES(cid,'assistant','Review addition',
  jsonb_build_object('pending_actions',jsonb_build_array(jsonb_build_object('id',item_action,'world',org,'version',1,'inventory_id',inv,'operation','add','status','pending','expires_at',now()+interval '30 minutes',
   'items',jsonb_build_array(jsonb_build_object('name','World bolt','category','Hardware','quantity',3,'location','Bolts','space_id',place))))));
 result:=public.findez_chat_item_action(member,inv,item_action,'confirm',100000);
 replay:=public.findez_chat_item_action(member,inv,item_action,'confirm',100000);
 PERFORM pg_temp.check(result=replay AND result->>'status'='confirmed','world item addition is durable and replay safe');
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.items WHERE inventory_id=inv AND name='World bolt'),'world item confirmation writes exactly once');
 -- Quotas fail atomically; private history requires both author and membership.
 a:=pg_temp.world_proposal(member,org::text,jsonb_build_object('workspace_id',ws,'inventories',jsonb_build_array(jsonb_build_object('name','Over quota','spaces',jsonb_build_array('New')))));
 BEGIN PERFORM public.findez_world_structure_action(member,org::text,a,'confirm',jsonb_build_object(member::text,0,actor::text,0)); RAISE EXCEPTION 'quota bypass'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE team_id=ws AND name='Over quota'),'Space limit rolls back whole proposal');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true);
 PERFORM pg_temp.check(NOT public.findez_read_world_conversation(cid),'organization Owner cannot read another author private chat');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',member,'role','authenticated')::text,true);
 PERFORM pg_temp.check(public.findez_read_world_conversation(cid),'author can read their organization chat');
 PERFORM set_config('request.jwt.claims','{}',true);
 DELETE FROM public.app_organization_members WHERE organization_id=org AND user_id=member;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',member,'role','authenticated')::text,true);
 PERFORM pg_temp.check(NOT public.findez_read_world_conversation(cid),'removed member cannot read organization chat');
 PERFORM set_config('request.jwt.claims','{}',true);
 INSERT INTO public.app_organization_members(organization_id,user_id,role) VALUES(org,member,'admin');
 -- Authenticated direct writes cannot forge world proposals.
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',member,'role','authenticated')::text,true);
 BEGIN INSERT INTO public.conversations(user_id,title,world_key) VALUES(member,'Forged',org::text); RAISE EXCEPTION 'client forged world'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claims','{}',true);
END $$;

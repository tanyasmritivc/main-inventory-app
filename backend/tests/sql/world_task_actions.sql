-- Empty disposable fixture only. Includes production permission/snapshot functions.
\ir ../../supabase/migrations/077_world_task_actions.sql
\ir ../../supabase/migrations/077_world_task_actions.sql
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_world_task_action(uuid,text,uuid,text,jsonb,jsonb)','EXECUTE'),'composite actions service-only');
DO $$
DECLARE actor uuid:='d4000000-0000-0000-0000-000000000003'; a uuid; plan jsonb; r jsonb; inv uuid; item uuid; before_count integer; snapshot jsonb;
 limits jsonb:='{"d4000000-0000-0000-0000-000000000003":null}';
BEGIN
 plan:='{"workspace_id":"personal","inventories":[{"name":"Atomic test","spaces":["Storage"],"items":[{"name":"AA batteries","category":"Other","quantity":10,"location":"Storage"}],"moves":[]}]}';
 a:=pg_temp.world_proposal(actor,'personal',plan);
 UPDATE public.messages SET answer_context=jsonb_set(answer_context,'{world_actions,0,version}','2') WHERE answer_context->'world_actions'->0->>'id'=a::text;
 r:=public.findez_world_task_action(actor,'personal',a,'confirm',limits,limits);
 inv:=(r->'receipt'->'inventories'->0->>'inventory_id')::uuid;
 SELECT item_id INTO STRICT item FROM public.items WHERE inventory_id=inv AND name='AA batteries';
 PERFORM pg_temp.check((SELECT quantity=10 FROM public.items WHERE item_id=item),'one confirmation creates and adds items');
 PERFORM pg_temp.check(r=public.findez_world_task_action(actor,'personal',a,'confirm',limits,limits),'whole task replay identical');
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.items WHERE inventory_id=inv),'retry adds no duplicate');
 PERFORM pg_temp.check(jsonb_array_length(r->'receipt'->'resource_links')=1,'saved structure has real Space link');
 snapshot:=public.findez_world_item_snapshot(actor,inv,item);
 plan:=jsonb_build_object('workspace_id','personal','inventories',jsonb_build_array(jsonb_build_object('name','Atomic garage','spaces',jsonb_build_array('Garage'),
  'moves',jsonb_build_array(jsonb_build_object('inventory_id',inv,'item_id',item,'name','AA batteries','quantity',10,'location','Storage','target_location','Garage','snapshot',snapshot->>'snapshot')))));
 a:=pg_temp.world_proposal(actor,'personal',plan);
 UPDATE public.messages SET answer_context=jsonb_set(answer_context,'{world_actions,0,version}','2') WHERE answer_context->'world_actions'->0->>'id'=a::text;
 r:=public.findez_world_task_action(actor,'personal',a,'confirm',limits,limits);
 PERFORM pg_temp.check((SELECT location='Garage' AND inventory_id<>inv AND quantity=10 FROM public.items WHERE item_id=item),'same identity moves after creating destination');
 -- A stale dependent move rolls back newly created structure as well.
 plan:=jsonb_set(plan,'{inventories,0,name}','"Must roll back"');
 a:=pg_temp.world_proposal(actor,'personal',plan);
 UPDATE public.messages SET answer_context=jsonb_set(answer_context,'{world_actions,0,version}','2') WHERE answer_context->'world_actions'->0->>'id'=a::text;
 BEGIN
  PERFORM public.findez_world_task_action(actor,'personal',a,'confirm',limits,limits);
  RAISE EXCEPTION 'stale move accepted';
 EXCEPTION WHEN no_data_found OR check_violation THEN NULL; END;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE name='Must roll back'),'dependent failure rolls back structure');
 -- A quota failure also rolls back, and cancel never creates anything.
 plan:='{"workspace_id":"personal","inventories":[{"name":"Over quota","spaces":["Storage"],"items":[{"name":"Cable","category":"Other","quantity":1,"location":"Storage"}]}]}';
 a:=pg_temp.world_proposal(actor,'personal',plan);
 UPDATE public.messages SET answer_context=jsonb_set(answer_context,'{world_actions,0,version}','2') WHERE answer_context->'world_actions'->0->>'id'=a::text;
 BEGIN
  PERFORM public.findez_world_task_action(actor,'personal',a,'confirm',limits,jsonb_build_object(actor::text,0));
  RAISE EXCEPTION 'quota bypassed';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE name='Over quota'),'quota failure rolls back structure');
 r:=public.findez_world_task_action(actor,'personal',a,'cancel',limits,limits);
 PERFORM pg_temp.check(r->>'status'='cancelled','cancel remains available after failed confirmation');
 PERFORM pg_temp.check(public.findez_world_task_action(actor,'personal',a,'confirm',limits,limits)->>'status'='cancelled','cancelled task cannot execute');
END $$;

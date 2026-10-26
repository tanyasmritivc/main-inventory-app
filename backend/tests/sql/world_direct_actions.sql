\ir ../../supabase/migrations/078_world_direct_actions.sql
\ir ../../supabase/migrations/078_world_direct_actions.sql
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_world_direct_action(uuid,text,uuid,uuid,jsonb)','EXECUTE'),'direct changes are service-only');
DO $$
DECLARE actor uuid:='d4000000-0000-0000-0000-000000000003'; other_actor uuid:='d4000000-0000-0000-0000-000000000004';
 inv uuid; item uuid:=gen_random_uuid(); cid uuid:=gen_random_uuid(); turn uuid:=gen_random_uuid(); a uuid:=gen_random_uuid();
 snapshot jsonb; action jsonb; r jsonb;
BEGIN
 inv:=public.findez_default_inventory(actor);
 INSERT INTO public.items(item_id,user_id,inventory_id,name,category,quantity,location) VALUES(item,actor,inv,'Direct batteries','Other',8,'Storage');
 INSERT INTO public.conversations(id,user_id,title,world_key) VALUES(cid,actor,'Direct fixture','personal');
 INSERT INTO public.messages(id,conversation_id,role,content) VALUES(turn,cid,'user','I used 3 batteries');
 snapshot:=public.findez_world_item_snapshot(actor,inv,item);
 action:=jsonb_build_object('id',a,'version',2,'world','personal','inventory_id',inv,'operation','edit','direct',true,'turn_id',turn,'status','pending','expires_at',now()+interval '30 minutes',
  'items',jsonb_build_array(jsonb_build_object('item_id',item,'name','Direct batteries','quantity',8,'location','Storage','snapshot',snapshot->>'snapshot','changes',jsonb_build_object('quantity',5),'details',jsonb_build_array('Quantity: 8 -> 5'))));
 r:=public.findez_world_direct_action(actor,'personal',cid,turn,action);
 PERFORM pg_temp.check((SELECT quantity=5 FROM public.items WHERE item_id= item),'explicit quantity change is committed');
 PERFORM pg_temp.check(r=public.findez_world_direct_action(actor,'personal',cid,turn,action),'lost response retry returns same receipt');
 PERFORM pg_temp.check((SELECT quantity=5 FROM public.items WHERE item_id=item),'replay does not decrement twice');
 BEGIN PERFORM public.findez_world_direct_action(other_actor,'personal',cid,turn,action); RAISE EXCEPTION 'foreign actor accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_world_direct_action(actor,'personal',cid,gen_random_uuid(),jsonb_set(action,'{turn_id}',to_jsonb(gen_random_uuid()::text))); RAISE EXCEPTION 'foreign turn accepted'; EXCEPTION WHEN check_violation OR insufficient_privilege THEN NULL; END;
 action:=jsonb_set(action,'{id}',to_jsonb(gen_random_uuid()::text));
 BEGIN PERFORM public.findez_world_direct_action(actor,'personal',cid,turn,action); RAISE EXCEPTION 'stale snapshot accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check((SELECT quantity=5 FROM public.items WHERE item_id=item),'stale attempt leaves stock unchanged');
END $$;

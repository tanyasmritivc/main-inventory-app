SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
CREATE TEMP TABLE tracking_before AS SELECT item_id,to_jsonb(i) AS data FROM public.items i;
\ir ../../supabase/migrations/074_world_item_management.sql
\ir ../../supabase/migrations/074_world_item_management.sql
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_world_item_change(uuid,text,uuid,uuid,text)','EXECUTE'),'advanced chat changes are service only');
SELECT pg_temp.check(NOT has_table_privilege('authenticated','public.app_reorder_requests','SELECT'),'reorder requests require server authorization');
SELECT pg_temp.check(NOT EXISTS(SELECT 1 FROM tracking_before b LEFT JOIN public.items i USING(item_id)
 WHERE i.item_id IS NULL OR b.data IS DISTINCT FROM to_jsonb(i)-ARRAY['unit_price','currency','expires_on','reorder_enabled','reorder_threshold','reorder_quantity','reorder_armed']),
 'tracking migration preserves all existing item fields');
CREATE FUNCTION pg_temp.item_proposal(actor uuid,world text,inv uuid,item uuid,op text,details jsonb) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE cid uuid:=gen_random_uuid(); aid uuid:=gen_random_uuid(); snap jsonb;
BEGIN
 snap:=public.findez_world_item_snapshot(actor,inv,item);
 INSERT INTO public.conversations(id,user_id,title,world_key) VALUES(cid,actor,'Item management QA',world);
 INSERT INTO public.messages(conversation_id,role,content,answer_context) VALUES(cid,'assistant','Review change',
  jsonb_build_object('pending_actions',jsonb_build_array(jsonb_build_object('id',aid,'version',2,'world',world,'inventory_id',inv,'operation',op,'status','pending','expires_at',now()+interval '30 minutes',
   'items',jsonb_build_array(jsonb_build_object('item_id',item,'name',snap->'item'->>'name','quantity',snap->'item'->'quantity','location',snap->'item'->>'location','snapshot',snap->>'snapshot','details',jsonb_build_array('Reviewed test change'))||details)))));
 RETURN aid;
END $$;
DO $$
DECLARE actor uuid:='d4000000-0000-0000-0000-000000000003'; member uuid:='d4000000-0000-0000-0000-000000000004';
 inv uuid; target_inv uuid; shelf uuid; target_shelf uuid; item uuid:=gen_random_uuid(); a uuid; result jsonb; req uuid; c integer; old_quantity integer;
BEGIN
 inv:=public.findez_default_inventory(actor);
 SELECT id INTO shelf FROM public.spaces WHERE inventory_id=inv LIMIT 1;
 IF shelf IS NULL THEN INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(actor,inv,'Tracking source') RETURNING id INTO shelf; END IF;
 INSERT INTO public.app_inventories(owner_user_id,name) VALUES(actor,'Tracking destination') RETURNING inventory_id INTO target_inv;
 INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(actor,target_inv,'Tracking target') RETURNING id INTO target_shelf;
 INSERT INTO public.items(item_id,user_id,inventory_id,space_id,name,category,quantity,location) VALUES(item,actor,inv,shelf,'Tracked bolt','Parts',5,(SELECT name FROM public.spaces WHERE id=shelf));
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'edit','{"changes":{"name":"Renamed bolt","unit_price":3.25,"currency":"USD","expires_on":"2027-12-31","reorder_enabled":true,"reorder_threshold":2,"reorder_quantity":10}}');
 result:=public.findez_world_item_change(actor,'personal',inv,a,'confirm');
 PERFORM pg_temp.check(result=public.findez_world_item_change(actor,'personal',inv,a,'confirm'),'edit receipt replays exactly');
 PERFORM pg_temp.check((SELECT name='Renamed bolt' AND unit_price=3.25 AND expires_on='2027-12-31' AND reorder_enabled FROM public.items WHERE item_id=item),'edit persists price expiry and rule');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_reorder_requests WHERE item_id=item),'above threshold creates no reorder');
 UPDATE public.items SET quantity=2 WHERE item_id=item;
 UPDATE public.items SET quantity=1 WHERE item_id=item;
 SELECT id INTO STRICT req FROM public.app_reorder_requests WHERE item_id=item;
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.app_reorder_requests WHERE item_id=item),'repeated low quantities create one pending request');
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'reorder',jsonb_build_object('request_id',req,'request_status','pending','request_quantity',10,'next_status','approved'));
 PERFORM public.findez_world_item_change(actor,'personal',inv,a,'confirm');
 PERFORM pg_temp.check((SELECT quantity=1 FROM public.items WHERE item_id=item),'approval does not purchase or add stock');
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'reorder',jsonb_build_object('request_id',req,'request_status','approved','request_quantity',10,'next_status','received'));
 result:=public.findez_world_item_change(actor,'personal',inv,a,'confirm');
 PERFORM pg_temp.check(result=public.findez_world_item_change(actor,'personal',inv,a,'confirm'),'receiving receipt is idempotent');
 PERFORM pg_temp.check((SELECT quantity=11 AND reorder_armed FROM public.items WHERE item_id=item),'received quantity added exactly once and rearms');
 UPDATE public.items SET quantity=1 WHERE item_id=item;
 PERFORM pg_temp.check((SELECT count(*)=2 FROM public.app_reorder_requests WHERE item_id=item),'new low-stock cycle creates a new request');
 SELECT id INTO req FROM public.app_reorder_requests WHERE item_id=item AND status='pending';
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'reorder',jsonb_build_object('request_id',req,'request_status','pending','request_quantity',10,'next_status','dismissed'));
 PERFORM public.findez_world_item_change(actor,'personal',inv,a,'confirm');
 UPDATE public.items SET quantity=0 WHERE item_id=item;
 PERFORM pg_temp.check((SELECT count(*)=2 FROM public.app_reorder_requests WHERE item_id=item),'dismissal does not immediately duplicate request');
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'edit','{"changes":{"brand":"New brand"}}');
 UPDATE public.items SET notes='Concurrent change' WHERE item_id=item;
 BEGIN PERFORM public.findez_world_item_change(actor,'personal',inv,a,'confirm'); RAISE EXCEPTION 'stale snapshot accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check((SELECT brand IS NULL FROM public.items WHERE item_id=item),'stale changes do not overwrite newer edits');
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'edit','{"changes":{"brand":"New brand"}}');
 BEGIN PERFORM public.findez_world_item_change(member,'personal',inv,a,'confirm'); RAISE EXCEPTION 'foreign actor accepted'; EXCEPTION WHEN no_data_found THEN NULL; END;
 BEGIN PERFORM public.findez_world_item_change(actor,gen_random_uuid()::text,inv,a,'confirm'); RAISE EXCEPTION 'foreign world accepted'; EXCEPTION WHEN no_data_found THEN NULL; END;
 PERFORM public.findez_world_item_change(actor,'personal',inv,a,'cancel');
 PERFORM pg_temp.check(public.findez_world_item_change(actor,'personal',inv,a,'confirm')->>'status'='cancelled','cancelled edit remains cancelled');
 -- Recheck destinations and expire frozen actions; never let review bypass columns.
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'edit','{"changes":{"inventory_id":"00000000-0000-0000-0000-000000000000"}}');
 BEGIN PERFORM public.findez_world_item_change(actor,'personal',inv,a,'confirm'); RAISE EXCEPTION 'unsafe field accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'edit','{"changes":{"name":"Must not expire"}}');
 UPDATE public.messages SET answer_context=jsonb_set(answer_context,'{pending_actions,0,expires_at}',to_jsonb((now()-interval '1 second')::text))
 WHERE answer_context->'pending_actions'->0->>'id'=a::text;
 BEGIN PERFORM public.findez_world_item_change(actor,'personal',inv,a,'confirm'); RAISE EXCEPTION 'expired card accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'move',jsonb_build_object('target_inventory_id',public.findez_default_inventory(member),'target_space_id',shelf,'target_location','Foreign'));
 BEGIN PERFORM public.findez_world_item_change(actor,'personal',inv,a,'confirm'); RAISE EXCEPTION 'foreign destination accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'move',jsonb_build_object('target_inventory_id',target_inv,'target_space_id',target_shelf,'target_location','Old name'));
 BEGIN PERFORM public.findez_world_item_change(actor,'personal',inv,a,'confirm'); RAISE EXCEPTION 'renamed destination accepted'; EXCEPTION WHEN no_data_found THEN NULL; END;
 PERFORM pg_temp.check((SELECT name='Renamed bolt' AND inventory_id=inv FROM public.items WHERE item_id=item),'invalid expired and foreign actions leave the item unchanged');
 a:=pg_temp.item_proposal(actor,'personal',inv,item,'move',jsonb_build_object('target_inventory_id',target_inv,'target_space_id',target_shelf,'target_location','Tracking target'));
 result:=public.findez_world_item_change(actor,'personal',inv,a,'confirm');
 PERFORM pg_temp.check(result=public.findez_world_item_change(actor,'personal',inv,a,'confirm'),'move receipt replays exactly');
 PERFORM pg_temp.check((SELECT inventory_id=target_inv AND space_id=target_shelf AND unit_price=3.25 FROM public.items WHERE item_id=item),'move retains identity and tracking fields');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.item_events WHERE item_id=item AND inventory_id<>target_inv),'move retains and relocates item history');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_reorder_requests WHERE item_id=item AND inventory_id<>target_inv),'move relocates reorder requests');
 a:=pg_temp.item_proposal(actor,'personal',target_inv,item,'edit','{"changes":{"unit_price":null,"expires_on":null,"reorder_enabled":false}}');
 PERFORM public.findez_world_item_change(actor,'personal',target_inv,a,'confirm');
 PERFORM pg_temp.check((SELECT unit_price IS NULL AND expires_on IS NULL AND NOT reorder_enabled FROM public.items WHERE item_id=item),'optional tracking can be cleared and rule disabled');
 -- Unknown legacy stock remains unknown when editing unrelated details.
 UPDATE public.items SET quantity=-1 WHERE item_id=item;
 a:=pg_temp.item_proposal(actor,'personal',target_inv,item,'edit','{"changes":{"brand":"Known brand"}}');
 result:=public.findez_world_item_change(actor,'personal',target_inv,a,'confirm');
 PERFORM pg_temp.check((SELECT quantity=-1 AND brand='Known brand' FROM public.items WHERE item_id=item),'editing details preserves unknown quantity');
 PERFORM pg_temp.check(result->'items'->0->'quantity'='null'::jsonb,'unknown stock receipt renders without inventing a count');
END $$;

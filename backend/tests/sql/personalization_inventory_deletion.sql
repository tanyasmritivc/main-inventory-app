-- Disposable current-schema clone only. Synthetic records and DDL roll back.
BEGIN;
DO $$
DECLARE actor uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); inv uuid:=gen_random_uuid(); neighbor uuid:=gen_random_uuid(); item uuid:=gen_random_uuid(); other_item uuid:=gen_random_uuid(); r jsonb;
BEGIN
 INSERT INTO auth.users(id) VALUES(actor),(outsider);
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,name) VALUES(inv,actor,'Deletion audit'),(neighbor,actor,'Keep neighbor');
 INSERT INTO public.items(item_id,user_id,inventory_id,name,category,location,quantity) VALUES(item,actor,inv,'Blue pen','Stationery','Desk',2),(other_item,actor,neighbor,'Other pen','Stationery','Desk',3);
 INSERT INTO public.personalization_events(user_id,event_type,source,inventory_id,entity_type,entity_id,dedupe_key) VALUES(actor,'inventory.item_viewed','database',inv,'item',item,'delete-test'),(actor,'inventory.item_viewed','database',neighbor,'item',other_item,'keep-test');
 INSERT INTO public.personalization_aliases(user_id,inventory_id,alias,item_id,operation_id) VALUES(actor,inv,'blue marker',item,gen_random_uuid()),(actor,neighbor,'other marker',other_item,gen_random_uuid());
 INSERT INTO public.personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key) VALUES(actor,inv,'low_stock','item',item,'delete-test'),(actor,neighbor,'low_stock','item',other_item,'keep-test');
 BEGIN PERFORM public.findez_delete_inventory_contents(outsider,inv,'Deletion audit'); RAISE EXCEPTION 'Outsider deletion allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_delete_inventory_contents(actor,inv,'Wrong name'); RAISE EXCEPTION 'Wrong-name deletion allowed'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 -- Unknown future tables must still block deletion, even when empty.
 CREATE TABLE public.audit_unknown_inventory_reference(id uuid,inventory_id uuid REFERENCES public.app_inventories ON DELETE CASCADE);
 BEGIN PERFORM public.findez_delete_inventory_contents(actor,inv,'Deletion audit'); RAISE EXCEPTION 'Unknown dependency allowed'; EXCEPTION WHEN check_violation THEN NULL; END;
 DROP TABLE public.audit_unknown_inventory_reference;
 -- Cross-inventory alias corruption must never cascade into a neighbor.
 INSERT INTO public.personalization_aliases VALUES(actor,neighbor,'cross link',item,now(),gen_random_uuid());
 BEGIN PERFORM public.findez_delete_inventory_contents(actor,inv,'Deletion audit'); RAISE EXCEPTION 'Cross-inventory alias allowed'; EXCEPTION WHEN check_violation THEN NULL; END;
 DELETE FROM public.personalization_aliases WHERE user_id=actor AND alias='cross link';
 r:=public.findez_delete_inventory_contents(actor,inv,'Deletion audit');
 IF NOT coalesce((r->>'deleted')::boolean,false) THEN RAISE EXCEPTION 'Missing receipt'; END IF;
 IF EXISTS(SELECT 1 FROM public.items WHERE inventory_id=inv) OR EXISTS(SELECT 1 FROM public.personalization_events WHERE inventory_id=inv) OR EXISTS(SELECT 1 FROM public.personalization_aliases WHERE inventory_id=inv) OR EXISTS(SELECT 1 FROM public.personalization_notifications WHERE inventory_id=inv) THEN RAISE EXCEPTION 'Owned metadata retained'; END IF;
 IF (SELECT count(*) FROM public.personalization_events WHERE inventory_id=neighbor)<>1 OR (SELECT count(*) FROM public.personalization_aliases WHERE inventory_id=neighbor)<>1 OR (SELECT count(*) FROM public.personalization_notifications WHERE inventory_id=neighbor)<>1 OR NOT EXISTS(SELECT 1 FROM public.items WHERE item_id=other_item AND quantity=3) THEN RAISE EXCEPTION 'Neighbor changed'; END IF;
 IF has_function_privilege('authenticated','public.findez_delete_inventory_contents(uuid,uuid,text)','EXECUTE') OR has_function_privilege('anon','public.findez_delete_inventory_contents(uuid,uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'Client purge RPC exposed'; END IF;
END $$;
ROLLBACK;

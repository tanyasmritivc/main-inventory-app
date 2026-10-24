CREATE OR REPLACE FUNCTION pg_temp.check(p_condition boolean,p_name text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p_condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',p_name; END IF; RAISE NOTICE 'PASS: %',p_name; END $$;
-- This regression intentionally runs AFTER all schema additions, including 074.
\ir ../../supabase/migrations/076_inventory_reorder_deletion.sql
\ir ../../supabase/migrations/076_inventory_reorder_deletion.sql
DO $$
DECLARE actor uuid := 'b0000000-0000-0000-0000-000000000001';
 inv uuid := gen_random_uuid(); other_inv uuid := gen_random_uuid();
 item uuid := gen_random_uuid(); neighbor uuid := gen_random_uuid(); receipt jsonb;
BEGIN
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,name)
 VALUES(inv,actor,'Reorder deletion QA'),(other_inv,actor,'Retained reorder QA');
 INSERT INTO public.items(item_id,user_id,inventory_id,name,category,quantity,location)
 VALUES(item,actor,inv,'Bolt','Other',1,'Shelf'),(neighbor,actor,other_inv,'Nut','Other',2,'Shelf');
 INSERT INTO public.app_reorder_requests(item_id,inventory_id,item_name,quantity,threshold,stock_at_request)
 VALUES(item,inv,'Bolt',5,2,1),(neighbor,other_inv,'Nut',5,3,2);
 BEGIN
  PERFORM public.findez_delete_inventory_contents(actor,inv,'Wrong name');
  RAISE EXCEPTION 'wrong-name deletion accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 receipt := public.findez_delete_inventory_contents(actor,inv,'Reorder deletion QA');
 PERFORM pg_temp.check((receipt->>'deleted')::boolean,'post-074 inventory deletion succeeds');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_reorder_requests WHERE inventory_id=inv),'inventory deletion cascades its reorder metadata');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_reorder_requests WHERE inventory_id=other_inv),'neighbor reorder metadata preserved');
END $$;
-- Unknown future dependencies must still fail closed, even when empty.
CREATE TABLE public.launch_unknown_dependency(inventory_id uuid REFERENCES public.app_inventories ON DELETE CASCADE);
DO $$
DECLARE actor uuid := 'b0000000-0000-0000-0000-000000000001'; inv uuid := gen_random_uuid();
BEGIN
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,name) VALUES(inv,actor,'Unknown dependency QA');
 BEGIN
  PERFORM public.findez_delete_inventory_contents(actor,inv,'Unknown dependency QA');
  RAISE EXCEPTION 'unknown dependency deletion accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=inv),'unknown dependencies still block inventory deletion');
END $$;
DROP TABLE public.launch_unknown_dependency;

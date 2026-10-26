-- Real constraints and authorization in the disposable composed schema only.
\ir ../../supabase/migrations/049_empty_inventory_delete.sql
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_delete_empty_inventory(uuid,uuid,text)','EXECUTE'),'clients cannot forge deletion actors');
SELECT pg_temp.check(NOT has_function_privilege('anon','public.findez_delete_empty_inventory(uuid,uuid,text)','EXECUTE'),'anonymous deletion denied');
DO $$
DECLARE actor uuid:='b0000000-0000-0000-0000-000000000001';
 outsider uuid:='b0000000-0000-0000-0000-000000000003';
 inv uuid:=gen_random_uuid(); other_inv uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); result jsonb;
BEGIN
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,name) VALUES(inv,actor,'Delete inventory fixture'),(other_inv,actor,'Second inventory fixture');
 BEGIN PERFORM public.findez_delete_empty_inventory(outsider,inv,'Delete inventory fixture'); RAISE EXCEPTION 'outsider deleted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_delete_empty_inventory(actor,inv,'Old name'); RAISE EXCEPTION 'stale name deleted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 INSERT INTO public.spaces(id,user_id,inventory_id,name) VALUES(s,actor,inv,'Retained Space');
 BEGIN PERFORM public.findez_delete_empty_inventory(actor,inv,'Delete inventory fixture'); RAISE EXCEPTION 'nonempty deleted'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.spaces WHERE id=s),'blocked deletion retains Space');
 DELETE FROM public.spaces WHERE id=s;
 result:=public.findez_delete_empty_inventory(actor,inv,'Delete inventory fixture');
 PERFORM pg_temp.check(result=jsonb_build_object('deleted',true,'inventory_id',inv),'exact deletion receipt');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=inv),'empty inventory deleted');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=other_inv),'second inventory preserved');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_access_audit WHERE inventory_id=inv AND actor_id=actor AND action='inventory_delete'),'audit survives deletion');
 BEGIN PERFORM public.findez_delete_empty_inventory(actor,inv,'Delete inventory fixture'); RAISE EXCEPTION 'replay succeeded'; EXCEPTION WHEN no_data_found THEN NULL; END;
END $$;
-- A new content table is also protected without changing the deletion function.
CREATE TABLE public.inventory_delete_future_fixture(id uuid DEFAULT gen_random_uuid(),collection uuid REFERENCES public.app_inventories ON DELETE CASCADE);
DO $$ DECLARE actor uuid:='b0000000-0000-0000-0000-000000000001'; inv uuid:=gen_random_uuid(); BEGIN
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,name) VALUES(inv,actor,'Future content fixture');
 INSERT INTO public.inventory_delete_future_fixture(collection) VALUES(inv);
 BEGIN PERFORM public.findez_delete_empty_inventory(actor,inv,'Future content fixture'); RAISE EXCEPTION 'future content lost'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.inventory_delete_future_fixture WHERE collection=inv),'future content FK prevents destructive cascades');
END $$;
DROP TABLE public.inventory_delete_future_fixture;

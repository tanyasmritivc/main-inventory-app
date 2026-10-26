-- Runs only in the disposable composed fixture after migration 050.
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_prepare_account_deletion(uuid,jsonb)','EXECUTE'),'clients cannot choose another account deletion actor');
DO $$
DECLARE actor uuid:=gen_random_uuid(); inv uuid; item uuid:=gen_random_uuid(); org uuid:=gen_random_uuid();
 other_actor uuid:='b0000000-0000-0000-0000-000000000003'; other_inv uuid; loan uuid:=gen_random_uuid(); other_item uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id) VALUES(actor);
 inv:=public.findez_default_inventory(actor);
 INSERT INTO public.items(item_id,user_id,inventory_id,name,category,quantity,location) VALUES(item,actor,inv,'Account fixture','Tools',1,'Unsorted');
 INSERT INTO public.app_organizations(organization_id,owner_user_id,name) VALUES(org,actor,'Account owned org');
 PERFORM pg_temp.check(public.findez_prepare_account_deletion(actor)->>'code'='OWNERSHIP_REQUIRED','account owner preflight blocks before deletion');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.items WHERE item_id=item),'blocked account keeps content');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_account_deletions WHERE actor_id=actor),'blocked account has no cleanup task');
 DELETE FROM public.app_organizations WHERE organization_id=org;
 PERFORM pg_temp.check((public.findez_prepare_account_deletion(actor,'[{"kind":"document","path":"fixture/docs/manual.pdf","owner":"fixture"}]')->>'ready')::boolean,'account prepares without removing identity');
 PERFORM pg_temp.check(NOT public.findez_finish_account_deletion(actor),'file cleanup cannot run while account exists');
 other_inv:=public.findez_default_inventory(other_actor);
 INSERT INTO public.items(item_id,user_id,inventory_id,name,category,quantity,location) VALUES(other_item,other_actor,other_inv,'Retained loan item','Tools',1,'Unsorted');
 INSERT INTO public.checkouts(checkout_id,user_id,item_id,inventory_id) VALUES(loan,actor,other_item,other_inv);
 EXECUTE 'CREATE TABLE public.account_delete_blocker(user_id uuid REFERENCES auth.users(id))';
 EXECUTE 'INSERT INTO public.account_delete_blocker(user_id) VALUES($1)' USING actor;
 BEGIN DELETE FROM auth.users WHERE id=actor; RAISE EXCEPTION 'missing dependency allowed'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.items WHERE item_id=item),'failed Auth transaction keeps inventory content');
 PERFORM pg_temp.check(NOT public.findez_finish_account_deletion(actor),'failed Auth never permits file cleanup');
 EXECUTE 'DROP TABLE public.account_delete_blocker';
 DELETE FROM auth.users WHERE id=actor;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE owner_user_id=actor),'identity removal cascades account inventories');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.checkouts WHERE checkout_id=loan AND user_id IS NULL),'other inventory keeps loan history after borrower removal');
 PERFORM pg_temp.check(public.findez_finish_account_deletion(actor),'remaining account records can finish after identity removal');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.items WHERE item_id=other_item),'account deletion retains other account item');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',actor)::text,true);
 PERFORM pg_temp.check(NOT public.findez_active_storage_account(),'deleted identity token cannot pass storage active-account policy');
END $$;

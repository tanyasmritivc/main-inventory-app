CREATE TABLE IF NOT EXISTS public.checkouts(checkout_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid NOT NULL REFERENCES auth.users(id),item_id uuid REFERENCES public.items(item_id) ON DELETE CASCADE,inventory_id uuid REFERENCES public.app_inventories ON DELETE CASCADE,is_active boolean DEFAULT true);
CREATE TABLE IF NOT EXISTS public.conversation_history(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid,inventory_id uuid REFERENCES public.app_inventories ON DELETE CASCADE,query text);
CREATE TABLE IF NOT EXISTS public.item_events(event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid,image_url text,inventory_id uuid REFERENCES public.app_inventories ON DELETE CASCADE);
\ir ../../supabase/migrations/050_inventory_content_delete.sql
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_delete_inventory_contents(uuid,uuid,text)','EXECUTE'),'clients cannot forge purge actor');
SELECT pg_temp.check(NOT has_table_privilege('anon','public.app_inventory_deletions','SELECT'),'file manifests remain private');
DO $$
DECLARE actor uuid:='b0000000-0000-0000-0000-000000000001'; outsider uuid:='b0000000-0000-0000-0000-000000000003';
 inv uuid:=gen_random_uuid(); other_inv uuid:=gen_random_uuid(); space uuid:=gen_random_uuid(); item uuid:=gen_random_uuid(); r jsonb;
BEGIN
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,name) VALUES(inv,actor,'Purge fixture'),(other_inv,actor,'Neighbor purge fixture');
 INSERT INTO public.spaces(id,user_id,inventory_id,name) VALUES(space,actor,inv,'Purge Space');
 INSERT INTO public.items(item_id,user_id,inventory_id,space_id,name,category,quantity,location,image_url)
 VALUES(item,actor,inv,space,'Purge iron','Tools',1,'Purge Space','https://storage.test/storage/v1/object/public/item-images/'||actor||'/photo.jpg');
 INSERT INTO public.items(user_id,inventory_id,name,category,quantity,location) VALUES(actor,other_inv,'Retained iron','Tools',3,'Elsewhere');
 INSERT INTO public.conversation_history(user_id,inventory_id) VALUES(actor,inv);
 PERFORM set_config('findez.memory_actor',actor::text,true);
 INSERT INTO public.inventory_user_memory(inventory_id,user_id,key,value) VALUES(inv,actor,'old-memory','Old answer');
 BEGIN PERFORM public.findez_delete_inventory_contents(outsider,inv,'Purge fixture'); RAISE EXCEPTION 'outsider purged'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_delete_inventory_contents(actor,inv,'wrong'); RAISE EXCEPTION 'wrong name purged'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 r:=public.findez_delete_inventory_contents(actor,inv,'Purge fixture');
 PERFORM pg_temp.check(r->>'inventory_id'=inv::text AND (r->>'deleted')::boolean,'purge returns exact receipt');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.items WHERE inventory_id=inv),'purge removes saved items');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.spaces WHERE inventory_id=inv),'purge removes saved Spaces');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.conversation_history WHERE inventory_id=inv),'purge removes conversation history');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.inventory_user_memory WHERE inventory_id=inv),'purge removes private inventory memory');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.items WHERE inventory_id=other_inv),'purge retains neighbor records');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_inventory_deletions WHERE inventory_id=inv AND jsonb_array_length(files)=1 AND NOT completed),'file cleanup survives SQL deletion');
END $$;

DO $$ DECLARE actor uuid:='b0000000-0000-0000-0000-000000000001'; team uuid:=gen_random_uuid(); inv uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); BEGIN
 INSERT INTO public.teams(team_id,owner_user_id,name) VALUES(team,actor,'Purge workspace');
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(team,actor,'owner');
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,team_id,name) VALUES(inv,actor,team,'Team purge');
 INSERT INTO public.spaces(id,user_id,inventory_id,name) VALUES(s,actor,inv,'Team purge Space');
 PERFORM public.findez_delete_inventory_contents(actor,inv,'Team purge');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.spaces WHERE id=s),'team Space is deleted rather than moved into Personal');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.teams WHERE team_id=team),'inventory purge keeps workspace');
END $$;

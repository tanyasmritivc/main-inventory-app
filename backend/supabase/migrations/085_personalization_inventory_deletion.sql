-- Inventory-scoped personalization is owned metadata, already defined to cascade.
-- Review only these dependencies; retain the fail-closed guard for future tables.
BEGIN;
DO $$
DECLARE definition text; relation_name text;
 before_text text := '''connector_import_sessions'')';
 after_text text := '''connector_import_sessions'',''personalization_events'',''personalization_aliases'',''personalization_notifications'')';
BEGIN
 FOREACH relation_name IN ARRAY ARRAY['personalization_events','personalization_aliases','personalization_notifications'] LOOP
  IF NOT EXISTS (
   SELECT 1 FROM pg_constraint c
   JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=c.conkey[1]
   WHERE c.contype='f' AND c.conrelid=to_regclass('public.'||relation_name)
    AND c.confrelid='public.app_inventories'::regclass AND c.confdeltype='c'
    AND cardinality(c.conkey)=1 AND a.attname='inventory_id'
  ) THEN RAISE EXCEPTION 'Personalization deletion semantics differ; review before applying'; END IF;
 END LOOP;
 definition:=pg_get_functiondef('public.findez_delete_inventory_contents(uuid,uuid,text)'::regprocedure);
 IF position(after_text IN definition)>0 THEN RETURN; END IF;
 IF position(before_text IN definition)=0 THEN RAISE EXCEPTION 'Inventory deletion guard differs; review before applying'; END IF;
 EXECUTE replace(definition,before_text,after_text);
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

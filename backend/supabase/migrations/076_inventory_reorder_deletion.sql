-- Reorder requests are inventory-owned metadata. Both their item and inventory
-- foreign keys intentionally cascade. Keep the fail-closed dependency guard.
BEGIN;
DO $$
DECLARE definition text; before_text text := '''memory_events'',''app_image_previews'')';
 after_text text := '''memory_events'',''app_image_previews'',''app_reorder_requests'')';
BEGIN
 definition := pg_get_functiondef('public.findez_delete_inventory_contents(uuid,uuid,text)'::regprocedure);
 IF position(after_text IN definition)>0 THEN RETURN; END IF;
 IF position(before_text IN definition)=0 THEN
  RAISE EXCEPTION 'Inventory deletion dependency guard differs; review before applying';
 END IF;
 EXECUTE replace(definition,before_text,after_text);
END $$;
COMMIT;

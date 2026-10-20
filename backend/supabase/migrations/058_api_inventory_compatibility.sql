-- Repair existing integration writes after inventory and private-photo rollout.
-- No grants, policies, records, key scopes, or photo-download access are added.
BEGIN;
DO $$
DECLARE definition text:=pg_get_functiondef('public.findez_assign_inventory()'::regprocedure);
 old_sql text:=$old$(inv.team_id = (nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'api_workspace_id')::uuid
          AND nullif(current_setting('request.jwt.claims', true),'')::jsonb ? 'api_key_id')$old$;
 new_sql text:=$new$(nullif(current_setting('request.jwt.claims', true),'')::jsonb ? 'api_key_id'
          AND public.findez_api_can_access_workspace(inv.team_id))$new$;
BEGIN
 IF position(new_sql IN definition)>0 THEN RETURN; END IF;
 IF position(old_sql IN definition)=0 THEN RAISE EXCEPTION 'Inventory assignment source differs'; END IF;
 EXECUTE replace(definition,old_sql,new_sql);
END $$;

CREATE OR REPLACE FUNCTION public.findez_guard_item_image_reference() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor(); path text;
BEGIN
 FOR path IN SELECT public.findez_record_image_paths(to_jsonb(NEW)) LOOP
  -- An integration may update text/quantity without re-attaching the existing
  -- private photo. The key still needs current write access to this inventory.
  -- New photo references and moves across inventories retain the normal check.
  IF TG_TABLE_NAME='items' AND TG_OP='UPDATE'
   AND nullif(current_setting('request.jwt.claims',true),'')::jsonb ? 'api_key_id'
   AND NEW.inventory_id IS NOT DISTINCT FROM OLD.inventory_id
   AND public.findez_api_can_access_workspace((to_jsonb(NEW)->>'workspace_id')::uuid)
   AND public.findez_inventory_policy(NEW.inventory_id,true)
   AND path IN (SELECT public.findez_record_image_paths(to_jsonb(OLD))) THEN
   CONTINUE;
  END IF;
  IF actor IS NOT NULL AND NOT public.findez_can_read_item_image(actor,path) THEN
   RAISE insufficient_privilege USING message='You do not have access to this image. Upload your own photo.';
  END IF;
 END LOOP;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_guard_item_image_reference() FROM PUBLIC,anon,authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

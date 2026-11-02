-- Disambiguate identically named Spaces across inventories without changing
-- legacy workspace-key update behavior. UUID values remain parameterized.
BEGIN;
DO $$
DECLARE definition text:=pg_get_functiondef('public.assign_api_item_owner()'::regprocedure);
 marker text:='where ts.team_id = new.workspace_id and s.name = new.location;';
 replacement text:=$body$where ts.team_id = new.workspace_id and s.name = new.location
          and (new.inventory_id is null or s.inventory_id=new.inventory_id
           or (tg_op='UPDATE' and public.findez_api_claim('api_organization_id') is null));$body$;
BEGIN
 IF position('api_organization_id' IN definition)=0 THEN
  IF position(marker IN definition)=0 THEN RAISE EXCEPTION 'API item trigger differs'; END IF;
  EXECUTE replace(definition,marker,replacement);
 END IF;
END $$;
DO $$
DECLARE definition text:=pg_get_functiondef('public.api_query_items(uuid,jsonb,text,integer,integer)'::regprocedure);
BEGIN
 IF position('i.inventory_id,i.space_id' IN definition)=0 THEN
  IF position('i.item_id,i.workspace_id' IN definition)=0 THEN RAISE EXCEPTION 'API query projection differs'; END IF;
  definition:=replace(definition,'i.item_id,i.workspace_id','i.item_id,i.workspace_id,i.inventory_id,i.space_id');
  definition:=replace(definition,'''name'',''category'',''location'',''brand'',''part_number'',''barcode'',''quantity'',''source_system'',''external_id''',
   '''name'',''category'',''location'',''brand'',''part_number'',''barcode'',''quantity'',''source_system'',''external_id'',''inventory_id''');
  definition:=replace(definition,'and i.%I %s ($1->%s->>','and i.%I::text %s ($1->%s->>');
  EXECUTE definition;
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

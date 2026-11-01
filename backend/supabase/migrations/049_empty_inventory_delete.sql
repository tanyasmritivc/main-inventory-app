-- Explicit empty-inventory deletion. Never cascade user content from this action.
BEGIN;
CREATE FUNCTION public.findez_delete_empty_inventory(p_actor uuid,p_inventory uuid,p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.app_inventories; ref record; occupied boolean;
BEGIN
 SELECT * INTO inv FROM public.app_inventories WHERE inventory_id=p_inventory FOR UPDATE;
 IF NOT FOUND THEN RAISE no_data_found; END IF;
 -- Hold membership stable until commit, including revocation and role changes.
 IF inv.team_id IS NOT NULL THEN
  PERFORM 1 FROM public.team_memberships WHERE team_id=inv.team_id AND user_id=p_actor FOR SHARE;
 END IF;
 PERFORM 1 FROM public.app_inventory_members WHERE inventory_id=p_inventory AND user_id=p_actor FOR SHARE;
 IF NOT coalesce(public.findez_inventory_role(p_inventory,p_actor) IN ('owner','admin'),false) THEN
  RAISE insufficient_privilege;
 END IF;
 IF p_name IS DISTINCT FROM inv.name THEN RAISE invalid_parameter_value; END IF;
 -- FOR UPDATE conflicts with the FK key-share required by concurrent inserts.
 -- Discover every content FK, including future tables, rather than just items.
 FOR ref IN
  SELECT ns.nspname AS schema_name,cl.relname AS table_name,a.attname AS column_name
  FROM pg_constraint c JOIN pg_class cl ON cl.oid=c.conrelid
  JOIN pg_namespace ns ON ns.oid=cl.relnamespace
  JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=c.conkey[1]
  WHERE c.contype='f' AND c.confrelid='public.app_inventories'::regclass
   AND cardinality(c.conkey)=1
   AND cl.relname NOT IN ('app_inventory_members','app_inventory_access_requests','app_access_invitations','memory_events')
 LOOP
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I.%I WHERE %I=$1)',ref.schema_name,ref.table_name,ref.column_name)
   INTO occupied USING p_inventory;
  IF occupied THEN RAISE check_violation USING message='Inventory contains saved records'; END IF;
 END LOOP;
 INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
 VALUES(p_actor,inv.team_id,p_inventory,'inventory_delete',p_inventory,jsonb_build_object('name',inv.name));
 DELETE FROM public.app_inventories WHERE inventory_id=p_inventory;
 -- Preserve legacy default routing when another inventory remains.
 IF inv.is_default THEN
  UPDATE public.app_inventories SET is_default=true WHERE inventory_id=(
   SELECT inventory_id FROM public.app_inventories WHERE owner_user_id=inv.owner_user_id
    AND team_id IS NOT DISTINCT FROM inv.team_id ORDER BY created_at,inventory_id LIMIT 1 FOR UPDATE
  );
 END IF;
 RETURN jsonb_build_object('deleted',true,'inventory_id',p_inventory);
END $$;
REVOKE ALL ON FUNCTION public.findez_delete_empty_inventory(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_delete_empty_inventory(uuid,uuid,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

-- Retry-safe creation in a caller-selected inventory. No existing rows change.
BEGIN;
CREATE OR REPLACE FUNCTION public.findez_get_or_create_inventory_space(
 p_actor uuid,p_inventory uuid,p_name text,p_limit integer DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.app_inventories; saved public.spaces; created boolean:=false;
BEGIN
 IF p_name IS NULL OR length(btrim(p_name)) NOT BETWEEN 1 AND 100
  OR (p_limit IS NOT NULL AND p_limit<0) THEN RAISE invalid_parameter_value; END IF;
 PERFORM public.findez_lock_inventory_authority(p_inventory,p_actor);
 IF NOT coalesce(public.findez_inventory_role(p_inventory,p_actor) IN ('owner','admin','editor'),false)
 THEN RAISE insufficient_privilege; END IF;
 SELECT * INTO STRICT inv FROM public.app_inventories WHERE inventory_id=p_inventory;
 -- Serialize the owner-wide allowance, including different inventories.
 PERFORM pg_advisory_xact_lock(hashtextextended('findez:space-limit:'||inv.owner_user_id::text,0));
 SELECT * INTO saved FROM public.spaces WHERE inventory_id=p_inventory
  AND user_id=inv.owner_user_id AND lower(btrim(name))=lower(btrim(p_name));
 IF NOT FOUND THEN
  IF p_limit IS NOT NULL AND (SELECT count(*)>=p_limit FROM public.spaces
   WHERE user_id=inv.owner_user_id AND lower(btrim(name))<>'unsorted') THEN
   RAISE check_violation USING MESSAGE='space_limit_reached';
  END IF;
  PERFORM set_config('request.headers',(coalesce(nullif(current_setting('request.headers',true),'')::jsonb,'{}')
   ||jsonb_build_object('x-findez-actor',p_actor))::text,true);
  INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(inv.owner_user_id,p_inventory,btrim(p_name))
   RETURNING * INTO saved;
  created:=true;
  INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
   VALUES(p_actor,inv.team_id,p_inventory,'space_create',saved.id,jsonb_build_object('name',saved.name));
 END IF;
 RETURN jsonb_build_object('id',saved.id,'name',saved.name,'inventory_id',saved.inventory_id,
  'created_at',saved.created_at,'created',created,'confirmed',true);
END $$;
REVOKE ALL ON FUNCTION public.findez_get_or_create_inventory_space(uuid,uuid,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_get_or_create_inventory_space(uuid,uuid,text,integer) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

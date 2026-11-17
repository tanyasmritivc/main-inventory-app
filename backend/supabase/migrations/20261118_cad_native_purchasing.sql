-- Optional native purchasing consent. Existing sessions gain no permissions.
BEGIN;
ALTER TABLE public.cad_device_grants ADD COLUMN allow_purchasing boolean NOT NULL DEFAULT false;
CREATE FUNCTION public.findez_cad_device_approve_purchasing(p_code text,p_actor uuid,p_inventory uuid,p_writes boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF coalesce(findez_inventory_role(p_inventory,p_actor),'') NOT IN ('owner','admin','editor') THEN RETURN false; END IF;
 UPDATE cad_device_grants SET actor_id=p_actor,inventory_id=p_inventory,approved_at=now(),
  allow_cad_writes=p_writes,allow_purchasing=true
 WHERE user_code=p_code AND approved_at IS NULL AND revoked_at IS NULL AND pairing_expires_at>now();
 RETURN FOUND;
END $$;
CREATE FUNCTION public.findez_cad_native_purchase_action(p_actor uuid,p_inventory uuid,p_grant uuid,
 p_request uuid,p_hash text,p_plan uuid,p_action text,p_expected integer,p_data jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 -- Hold the grant row through the stock transaction so concurrent revocation
 -- cannot finish before an already authorized receipt commits.
 PERFORM 1 FROM cad_device_grants WHERE id=p_grant AND actor_id=p_actor
  AND inventory_id=p_inventory AND allow_purchasing AND revoked_at IS NULL
  AND session_expires_at>now() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','forbidden'); END IF;
 RETURN findez_cad_purchase_action(p_actor,p_inventory,p_request,p_hash,p_plan,p_action,p_expected,p_data);
END $$;
REVOKE ALL ON FUNCTION public.findez_cad_device_approve_purchasing(text,uuid,uuid,boolean),
 public.findez_cad_native_purchase_action(uuid,uuid,uuid,uuid,text,uuid,text,integer,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_cad_device_approve_purchasing(text,uuid,uuid,boolean),
 public.findez_cad_native_purchase_action(uuid,uuid,uuid,uuid,text,uuid,text,integer,jsonb) TO service_role;
COMMIT;

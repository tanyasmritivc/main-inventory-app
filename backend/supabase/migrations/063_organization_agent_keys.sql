-- Actual organization binding is distinct from legacy org_id (the issuing user).
-- Existing keys keep their old boundary and receive no new scopes.
BEGIN;
ALTER TABLE public.api_keys ADD COLUMN IF NOT EXISTS organization_id uuid
 REFERENCES public.app_organizations(organization_id) ON DELETE CASCADE;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='api_keys_one_boundary') THEN
  ALTER TABLE public.api_keys ADD CONSTRAINT api_keys_one_boundary
   CHECK(organization_id IS NULL OR workspace_id IS NULL);
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.findez_api_can_access_workspace(p_workspace_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS(SELECT 1 FROM public.api_keys k JOIN public.teams t ON t.team_id=p_workspace_id
  WHERE k.id::text=public.findez_api_claim('api_key_id')
   AND k.org_id::text=public.findez_api_claim('api_org_id')
   AND k.workspace_id::text IS NOT DISTINCT FROM public.findez_api_claim('api_workspace_id')
   AND k.organization_id::text IS NOT DISTINCT FROM public.findez_api_claim('api_organization_id')
   AND (k.workspace_id IS NULL OR k.workspace_id=p_workspace_id)
   AND k.revoked_at IS NULL AND (k.expires_at IS NULL OR k.expires_at>now())
   AND public.findez_actor_active(k.org_id)
   AND CASE WHEN k.organization_id IS NULL THEN t.owner_user_id=k.org_id ELSE
    t.organization_id=k.organization_id
    AND EXISTS(SELECT 1 FROM public.app_organization_members m WHERE m.organization_id=k.organization_id
     AND m.user_id=k.org_id AND m.role IN ('owner','admin'))
    AND public.findez_workspace_role(t.team_id,k.org_id) IS NOT NULL END)
$$;
CREATE OR REPLACE FUNCTION public.findez_api_has_scope(p_scope text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce((nullif(current_setting('request.jwt.claims',true),'')::jsonb->'api_scopes') ? p_scope,false)
  AND EXISTS(SELECT 1 FROM public.api_keys k WHERE k.id::text=public.findez_api_claim('api_key_id')
   AND k.org_id::text=public.findez_api_claim('api_org_id') AND p_scope=ANY(k.scopes)
   AND k.revoked_at IS NULL AND (k.expires_at IS NULL OR k.expires_at>now()))
$$;
-- Preserve the existing legacy path, using the actual delegated actor for new keys.
DO $$
DECLARE definition text:=pg_get_functiondef('public.findez_inventory_policy(uuid,boolean)'::regprocedure);
 old text:='  role_name:=public.findez_inventory_role(p_inventory,inv.owner_user_id);';
 replacement text:=$body$  IF public.findez_api_claim('api_organization_id') IS NOT NULL THEN
   role_name:=public.findez_inventory_role(p_inventory,public.findez_api_claim('api_org_id')::uuid);
   RETURN public.findez_api_can_access_workspace(inv.team_id)
    AND role_name IS NOT NULL AND (NOT p_write OR role_name IN ('owner','admin','editor'));
  END IF;
  role_name:=public.findez_inventory_role(p_inventory,inv.owner_user_id);$body$;
BEGIN
 IF position('api_organization_id' IN definition)=0 THEN
  IF position(old IN definition)=0 THEN RAISE EXCEPTION 'Inventory permission function differs'; END IF;
  EXECUTE replace(definition,old,replacement);
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.findez_api_has_scope(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.findez_api_has_scope(text) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

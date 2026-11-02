-- New personal inventories use workspace mode even though they have no Team.
-- Keep owner/Shared Space authorization in force; restrictive/explicit grants
-- and every Team inventory retain the independent inventory permission fence.
-- No customer records are rewritten. Direct membership writes must not bypass
-- the authenticated, code-validated join route.
BEGIN;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.team_members,public.team_shares FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.team_members,public.team_shares TO service_role;

-- Break the existing team_shares <-> team_members RLS recursion while
-- retaining owner roster reads. The caller can only test their own ownership.
CREATE OR REPLACE FUNCTION public.findez_owns_space_share(p_share uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.team_shares
  WHERE share_id=p_share AND owner_user_id=auth.uid())
$$;
REVOKE ALL ON FUNCTION public.findez_owns_space_share(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.findez_owns_space_share(uuid) TO authenticated,service_role;
DROP POLICY IF EXISTS owner_see_members ON public.team_members;
CREATE POLICY owner_see_members ON public.team_members FOR SELECT TO authenticated
 USING(public.findez_owns_space_share(share_id));

CREATE OR REPLACE FUNCTION public.findez_inventory_fences(p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(jsonb_build_object('inventory_id',i.inventory_id,
  'team_id',i.team_id,'role',public.findez_inventory_role(i.inventory_id,p_actor))),'[]'::jsonb)
 FROM public.app_inventories i WHERE i.team_id IS NOT NULL OR i.access_mode='restricted'
 OR EXISTS(SELECT 1 FROM public.app_inventory_members m WHERE m.inventory_id=i.inventory_id)
$$;

CREATE OR REPLACE FUNCTION public.findez_inventory_policy(p_inventory uuid,p_write boolean) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.app_inventories; role_name text; claims jsonb; actor uuid;
BEGIN
 SELECT * INTO inv FROM public.app_inventories WHERE inventory_id=p_inventory;
 IF NOT FOUND THEN RETURN false; END IF;
 claims:=nullif(current_setting('request.jwt.claims',true),'')::jsonb;
 IF claims ? 'api_key_id' THEN
  role_name:=public.findez_inventory_role(p_inventory,inv.owner_user_id);
  RETURN public.findez_api_can_access_workspace(inv.team_id)
   AND public.findez_workspace_role(inv.team_id,inv.owner_user_id)='owner'
   AND role_name IS NOT NULL AND (NOT p_write OR role_name IN ('owner','admin','editor'));
 END IF;
 actor:=public.findez_request_actor();
 IF NOT public.findez_actor_active(actor) THEN RETURN false; END IF;
 -- Preserve the original row-level owner/Shared Space policies for private
 -- personal inventories without custom grants. This does not expose a whole inventory to a recipient.
 IF inv.team_id IS NULL AND inv.access_mode IN ('legacy','workspace') AND NOT EXISTS(
  SELECT 1 FROM public.app_inventory_members WHERE inventory_id=p_inventory) THEN RETURN true; END IF;
 role_name:=public.findez_inventory_role(p_inventory,actor);
 RETURN coalesce(role_name IS NOT NULL AND (NOT p_write OR role_name IN ('owner','admin','editor')),false);
END $$;

CREATE OR REPLACE FUNCTION public.findez_shared_item_image(p_actor uuid,p_item jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE allowed boolean;
BEGIN
 IF to_regclass('public.team_members') IS NULL OR NOT EXISTS(SELECT 1 FROM public.app_inventories
  WHERE inventory_id=(p_item->>'inventory_id')::uuid AND team_id IS NULL AND access_mode IN ('legacy','workspace')
  AND NOT EXISTS(SELECT 1 FROM public.app_inventory_members m WHERE m.inventory_id=(p_item->>'inventory_id')::uuid)) THEN RETURN false; END IF;
 EXECUTE $query$SELECT EXISTS(SELECT 1 FROM public.team_shares s JOIN public.team_members m USING(share_id)
  WHERE m.member_user_id=$1 AND coalesce(to_jsonb(s)->>'is_active','true')='true'
  AND s.owner_user_id=($2->>'user_id')::uuid
  AND s.inventory_id=($2->>'inventory_id')::uuid
  AND (s.expires_at IS NULL OR s.expires_at>now())
  AND (s.space_id=($2->>'space_id')::uuid OR s.space_id IS NULL AND s.share_name=$2->>'location'))$query$
 INTO allowed USING p_actor,p_item;
 RETURN coalesce(allowed,false);
END $$;
REVOKE ALL ON FUNCTION public.findez_shared_item_image(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_shared_item_image(uuid,jsonb) TO service_role;


-- The old owner-wide index predates multiple inventories. Keep case-insensitive
-- uniqueness inside an inventory while allowing e.g. a Shelf in two inventories.
CREATE UNIQUE INDEX IF NOT EXISTS spaces_inventory_owner_name_ci
 ON public.spaces(inventory_id,user_id,lower(btrim(name)));
DROP INDEX IF EXISTS public.idx_spaces_user_name_ci;
COMMIT;

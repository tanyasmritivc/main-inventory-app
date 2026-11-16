-- Connected Fusion workspace. Additive; no inventory/schema mutations.
-- Independent of the unactivated Onshape and inventory-intelligence candidates.
BEGIN;
CREATE TABLE public.cad_device_grants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_hash text NOT NULL UNIQUE CHECK(device_hash ~ '^[a-f0-9]{64}$'),
 user_code text NOT NULL UNIQUE CHECK(user_code ~ '^[A-HJ-NP-Z2-9]{10}$'),
 created_at timestamptz NOT NULL DEFAULT now(),
 pairing_expires_at timestamptz NOT NULL DEFAULT now() + interval '10 minutes',
 actor_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
 inventory_id uuid REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 approved_at timestamptz,
 token_hash text UNIQUE CHECK(token_hash ~ '^[a-f0-9]{64}$'),
 session_expires_at timestamptz,
 revoked_at timestamptz,
 CHECK((actor_id IS NULL) = (inventory_id IS NULL)),
 CHECK((approved_at IS NULL) = (actor_id IS NULL)),
 CHECK((token_hash IS NULL) = (session_expires_at IS NULL)),
 CHECK(token_hash IS NULL OR approved_at IS NOT NULL)
);
CREATE INDEX cad_device_grants_actor ON public.cad_device_grants(actor_id);
CREATE INDEX cad_device_grants_inventory ON public.cad_device_grants(inventory_id);
ALTER TABLE public.cad_device_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cad_device_grants FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.cad_device_grants TO service_role;

CREATE FUNCTION public.findez_cad_device_approve(p_code text,p_actor uuid,p_inventory uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF public.findez_inventory_role(p_inventory,p_actor) IS NULL THEN RETURN false; END IF;
 UPDATE cad_device_grants SET actor_id=p_actor, inventory_id=p_inventory, approved_at=now()
 WHERE user_code=p_code AND approved_at IS NULL AND revoked_at IS NULL AND pairing_expires_at>now();
 RETURN FOUND;
END $$;
CREATE FUNCTION public.findez_cad_device_exchange(p_device text,p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE g cad_device_grants;
BEGIN
 IF p_token !~ '^[a-f0-9]{64}$' THEN RETURN jsonb_build_object('status','expired'); END IF;
 SELECT * INTO g FROM cad_device_grants WHERE device_hash=p_device FOR UPDATE;
 IF NOT FOUND OR g.revoked_at IS NOT NULL OR g.token_hash IS NOT NULL OR g.pairing_expires_at<=now()
 THEN RETURN jsonb_build_object('status','expired'); END IF;
 IF g.approved_at IS NULL THEN RETURN jsonb_build_object('status','pending'); END IF;
 IF public.findez_inventory_role(g.inventory_id,g.actor_id) IS NULL
 THEN RETURN jsonb_build_object('status','expired'); END IF;
 UPDATE cad_device_grants SET token_hash=p_token,session_expires_at=now()+interval '8 hours' WHERE id=g.id;
 RETURN jsonb_build_object('status','connected','inventory_id',g.inventory_id,'actor_id',g.actor_id,'expires_in',28800);
END $$;
REVOKE ALL ON FUNCTION public.findez_cad_device_approve(text,uuid,uuid),
 public.findez_cad_device_exchange(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_cad_device_approve(text,uuid,uuid),
 public.findez_cad_device_exchange(text,text) TO service_role;
COMMIT;

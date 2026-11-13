-- Candidate only. Apply after review/approval; existing inventory is unchanged.
BEGIN;
CREATE TABLE public.cad_oauth_states (
  actor_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  state_hash text NOT NULL CHECK (state_hash ~ '^[a-f0-9]{64}$'),
  expires_at timestamptz NOT NULL
);
CREATE TABLE public.cad_onshape_connections (
  actor_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  generation uuid NOT NULL,
  tokens text, -- Fernet ciphertext, never browser-readable
  expires_at timestamptz,
  refresh_until timestamptz,
  CHECK ((tokens IS NULL) = (expires_at IS NULL))
);
CREATE TABLE public.cad_match_corrections (
  inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
  identity_hash text NOT NULL CHECK (identity_hash ~ '^[a-f0-9]{64}$'),
  decision text NOT NULL CHECK (decision IN ('match','no_match')),
  item_id uuid REFERENCES public.items(item_id) ON DELETE SET NULL,
  item_fingerprint text,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (inventory_id,identity_hash),
  CHECK (decision <> 'no_match' OR (item_id IS NULL AND item_fingerprint IS NULL))
);
CREATE INDEX cad_match_corrections_item ON public.cad_match_corrections(item_id) WHERE item_id IS NOT NULL;
CREATE INDEX cad_match_corrections_reviewer ON public.cad_match_corrections(reviewed_by);
ALTER TABLE public.cad_oauth_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cad_onshape_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cad_match_corrections ENABLE ROW LEVEL SECURITY;
-- No browser policies: all operations go through authenticated FastAPI. Reads
-- use explicit actor/inventory filters; the save RPC rechecks inventory roles.
REVOKE ALL ON public.cad_oauth_states, public.cad_onshape_connections, public.cad_match_corrections FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.cad_oauth_states, public.cad_onshape_connections, public.cad_match_corrections TO service_role;

CREATE FUNCTION public.findez_cad_begin_connection(p_actor uuid,p_state text,p_generation uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('cad:'||p_actor::text,0));
 DELETE FROM public.cad_oauth_states WHERE actor_id=p_actor AND state_hash=p_state AND expires_at>now();
 IF NOT FOUND THEN RETURN false; END IF;
 INSERT INTO public.cad_onshape_connections(actor_id,generation) VALUES(p_actor,p_generation)
 ON CONFLICT(actor_id) DO UPDATE SET generation=excluded.generation,tokens=NULL,expires_at=NULL,refresh_until=NULL;
 RETURN true;
END $$;
CREATE FUNCTION public.findez_cad_disconnect(p_actor uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('cad:'||p_actor::text,0));
 DELETE FROM public.cad_oauth_states WHERE actor_id=p_actor;
 DELETE FROM public.cad_onshape_connections WHERE actor_id=p_actor;
 RETURN true;
END $$;

CREATE FUNCTION public.findez_cad_refresh_lease(p_actor uuid,p_generation uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 UPDATE public.cad_onshape_connections SET refresh_until=now()+interval '90 seconds'
 WHERE actor_id=p_actor AND generation=p_generation
 AND (refresh_until IS NULL OR refresh_until<now()) AND expires_at<=now();
 RETURN FOUND;
END $$;

CREATE FUNCTION public.findez_cad_save_correction(p_actor uuid,p_inventory uuid,p_identity text,
 p_decision text,p_item uuid,p_fingerprint text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF coalesce(public.findez_inventory_role(p_inventory,p_actor),'') NOT IN ('owner','admin','editor') THEN
  RETURN false;
 END IF;
 IF p_identity !~ '^[a-f0-9]{64}$' THEN RETURN false; END IF;
 IF p_decision='reset' THEN
  DELETE FROM public.cad_match_corrections WHERE inventory_id=p_inventory AND identity_hash=p_identity;
  RETURN true;
 END IF;
 IF p_decision='match' THEN
  PERFORM 1 FROM public.items WHERE item_id=p_item AND inventory_id=p_inventory FOR KEY SHARE;
  IF NOT FOUND OR p_fingerprint IS NULL OR p_fingerprint !~ '^[a-f0-9]{64}$' THEN RETURN false; END IF;
 ELSIF p_decision<>'no_match' OR p_item IS NOT NULL OR p_fingerprint IS NOT NULL THEN RETURN false;
 END IF;
 INSERT INTO public.cad_match_corrections(inventory_id,identity_hash,decision,item_id,item_fingerprint,reviewed_by)
 VALUES(p_inventory,p_identity,p_decision,p_item,p_fingerprint,p_actor)
 ON CONFLICT(inventory_id,identity_hash) DO UPDATE SET decision=excluded.decision,
 item_id=excluded.item_id,item_fingerprint=excluded.item_fingerprint,reviewed_by=excluded.reviewed_by,reviewed_at=now();
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.findez_cad_refresh_lease(uuid,uuid),
 public.findez_cad_begin_connection(uuid,text,uuid), public.findez_cad_disconnect(uuid),
 public.findez_cad_save_correction(uuid,uuid,text,text,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_cad_refresh_lease(uuid,uuid),
 public.findez_cad_begin_connection(uuid,text,uuid), public.findez_cad_disconnect(uuid),
 public.findez_cad_save_correction(uuid,uuid,text,text,uuid,text) TO service_role;
COMMIT;

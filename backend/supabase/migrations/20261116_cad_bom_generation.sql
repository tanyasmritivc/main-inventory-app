-- Candidate. Independent of Onshape. Apply only after rehearsal and approval.
BEGIN;
ALTER TABLE public.cad_device_grants ADD COLUMN allow_cad_writes boolean NOT NULL DEFAULT false;
CREATE FUNCTION public.findez_cad_device_approve_writes(p_code text,p_actor uuid,p_inventory uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF coalesce(public.findez_inventory_role(p_inventory,p_actor),'') NOT IN ('owner','admin','editor') THEN RETURN false; END IF;
 UPDATE cad_device_grants SET actor_id=p_actor,inventory_id=p_inventory,approved_at=now(),allow_cad_writes=true
 WHERE user_code=p_code AND approved_at IS NULL AND revoked_at IS NULL AND pairing_expires_at>now();
 RETURN FOUND;
END $$;
-- Passing a grant binds every native write to its current role, expiry and approval.
CREATE FUNCTION public.findez_cad_can_write(p_actor uuid,p_inventory uuid,p_grant uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce(public.findez_inventory_role(p_inventory,p_actor),'') IN ('owner','admin','editor')
 AND (p_grant IS NULL OR EXISTS(SELECT 1 FROM cad_device_grants WHERE id=p_grant AND actor_id=p_actor
 AND inventory_id=p_inventory AND allow_cad_writes AND revoked_at IS NULL AND session_expires_at>now()));
$$;
CREATE TABLE IF NOT EXISTS public.cad_match_corrections (
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
CREATE INDEX IF NOT EXISTS cad_match_corrections_item ON public.cad_match_corrections(item_id) WHERE item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS cad_match_corrections_reviewer ON public.cad_match_corrections(reviewed_by);

ALTER TABLE public.cad_match_corrections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cad_match_corrections FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.cad_match_corrections TO service_role;
CREATE OR REPLACE FUNCTION public.findez_cad_save_correction(p_actor uuid,p_inventory uuid,p_identity text,
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

CREATE FUNCTION public.findez_cad_save_review(p_actor uuid,p_inventory uuid,p_grant uuid,p_identity text,
 p_decision text,p_item uuid,p_fingerprint text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NOT findez_cad_can_write(p_actor,p_inventory,p_grant) THEN RETURN false; END IF;
 RETURN findez_cad_save_correction(p_actor,p_inventory,p_identity,p_decision,p_item,p_fingerprint);
END $$;
REVOKE ALL ON FUNCTION public.findez_cad_save_review(uuid,uuid,uuid,text,text,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_cad_save_review(uuid,uuid,uuid,text,text,uuid,text) TO service_role;
CREATE TABLE public.cad_projects (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 source_key text NOT NULL CHECK(source_key ~ '^[a-f0-9]{64}$'),
 name text NOT NULL CHECK(length(name) BETWEEN 1 AND 512),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(inventory_id,source_key), UNIQUE(id,inventory_id)
);
CREATE TABLE public.cad_bom_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 inventory_id uuid NOT NULL,
 project_id uuid NOT NULL,
 version integer NOT NULL CHECK(version>0),
 request_id uuid NOT NULL,
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 snapshot jsonb NOT NULL CHECK(octet_length(snapshot::text)<=10485760),
 comparison jsonb NOT NULL CHECK(octet_length(comparison::text)<=20971520),
 created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(project_id,inventory_id) REFERENCES public.cad_projects(id,inventory_id) ON DELETE CASCADE,
 UNIQUE(project_id,version), UNIQUE(inventory_id,request_id)
);
CREATE INDEX cad_bom_versions_actor ON public.cad_bom_versions(created_by);
CREATE FUNCTION public.findez_cad_save_version(p_actor uuid,p_inventory uuid,p_grant uuid,p_source text,
 p_name text,p_request uuid,p_hash text,p_snapshot jsonb,p_comparison jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE project uuid; existing cad_bom_versions; number integer; saved uuid;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('cad-bom:'||p_inventory::text,0));
 IF NOT findez_cad_can_write(p_actor,p_inventory,p_grant) THEN RETURN jsonb_build_object('error','forbidden'); END IF;
 SELECT * INTO existing FROM cad_bom_versions WHERE inventory_id=p_inventory AND request_id=p_request;
 IF FOUND THEN
  IF existing.request_hash<>p_hash OR existing.created_by IS DISTINCT FROM p_actor THEN RETURN jsonb_build_object('error','conflict'); END IF;
  RETURN jsonb_build_object('id',existing.id,'project_id',existing.project_id,'version',existing.version,'created_at',existing.created_at,'replayed',true);
 END IF;
 IF (SELECT count(*) FROM cad_projects WHERE inventory_id=p_inventory)>=500
 AND NOT EXISTS(SELECT 1 FROM cad_projects WHERE inventory_id=p_inventory AND source_key=p_source)
 THEN RETURN jsonb_build_object('error','limit'); END IF;
 SELECT id INTO project FROM cad_projects WHERE inventory_id=p_inventory AND source_key=p_source;
 SELECT coalesce(max(version),0)+1 INTO number FROM cad_bom_versions WHERE project_id=project;
 IF number>200 THEN RETURN jsonb_build_object('error','limit'); END IF;
 INSERT INTO cad_projects(inventory_id,source_key,name) VALUES(p_inventory,p_source,p_name)
 ON CONFLICT(inventory_id,source_key) DO UPDATE SET name=excluded.name RETURNING id INTO project;
 INSERT INTO cad_bom_versions(inventory_id,project_id,version,request_id,request_hash,snapshot,comparison,created_by)
 VALUES(p_inventory,project,number,p_request,p_hash,p_snapshot,p_comparison,p_actor) RETURNING id INTO saved;
 RETURN jsonb_build_object('id',saved,'project_id',project,'version',number,'created_at',now(),'replayed',false);
END $$;
CREATE TABLE public.cad_generation_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 request_id uuid NOT NULL,
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 specification jsonb NOT NULL CHECK(octet_length(specification::text)<=70000),
 provider_id uuid UNIQUE,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(inventory_id,actor_id,request_id)
);
CREATE INDEX cad_generation_jobs_actor ON public.cad_generation_jobs(actor_id);
CREATE FUNCTION public.findez_cad_begin_generation(p_actor uuid,p_inventory uuid,p_grant uuid,p_request uuid,p_hash text,p_spec jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE job cad_generation_jobs;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('cad-generate:'||p_actor::text,0));
 IF NOT findez_cad_can_write(p_actor,p_inventory,p_grant) THEN RETURN jsonb_build_object('error','forbidden'); END IF;
 SELECT * INTO job FROM cad_generation_jobs WHERE actor_id=p_actor AND inventory_id=p_inventory AND request_id=p_request;
 IF FOUND THEN
  IF job.request_hash<>p_hash THEN RETURN jsonb_build_object('error','conflict'); END IF;
  RETURN to_jsonb(job);
 END IF;
 IF (SELECT count(*) FROM cad_generation_jobs WHERE actor_id=p_actor AND created_at>now()-interval '1 day')>=20
 THEN RETURN jsonb_build_object('error','limit'); END IF;
 INSERT INTO cad_generation_jobs(inventory_id,actor_id,request_id,request_hash,specification)
 VALUES(p_inventory,p_actor,p_request,p_hash,p_spec) RETURNING * INTO job;
 RETURN to_jsonb(job);
END $$;
ALTER TABLE public.cad_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cad_bom_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cad_generation_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cad_projects,public.cad_bom_versions,public.cad_generation_jobs FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.cad_projects,public.cad_bom_versions,public.cad_generation_jobs TO service_role;
REVOKE ALL ON FUNCTION public.findez_cad_device_approve_writes(text,uuid,uuid),public.findez_cad_can_write(uuid,uuid,uuid),
 public.findez_cad_save_correction(uuid,uuid,text,text,uuid,text),
 public.findez_cad_save_version(uuid,uuid,uuid,text,text,uuid,text,jsonb,jsonb),
 public.findez_cad_begin_generation(uuid,uuid,uuid,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_cad_device_approve_writes(text,uuid,uuid),public.findez_cad_can_write(uuid,uuid,uuid),
 public.findez_cad_save_correction(uuid,uuid,text,text,uuid,text),
 public.findez_cad_save_version(uuid,uuid,uuid,text,text,uuid,text,jsonb,jsonb),
 public.findez_cad_begin_generation(uuid,uuid,uuid,uuid,text,jsonb) TO service_role;
COMMIT;

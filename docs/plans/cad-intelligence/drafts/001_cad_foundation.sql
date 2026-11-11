-- DESIGN ARTIFACT ONLY. NEVER APPLY FROM THIS DIRECTORY.
-- Verified FK target names/types against public-schema metadata on 2026-11-10.
-- Runtime RPCs, encrypted secrets, pairing and stock guards are NOT implemented.
BEGIN;
DO $$ BEGIN
  RAISE EXCEPTION 'UNAPPLIED CAD DESIGN: promotion and migration rehearsal required';
END $$;

CREATE TABLE public.cad_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('fusion', 'onshape')),
  connection_mode text NOT NULL CHECK (connection_mode IN ('desktop_push', 'provider_oauth')),
  external_account_id text NOT NULL,
  display_name text NOT NULL,
  encrypted_credentials_ref text, -- opaque locator only, never bearer credentials
  scopes text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','connected','expired','revoked','error')),
  last_connected_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, inventory_id)
);
CREATE UNIQUE INDEX cad_connection_live_identity ON public.cad_connections
  (inventory_id, actor_id, provider, external_account_id) WHERE status <> 'revoked';
CREATE INDEX cad_connection_actor ON public.cad_connections (actor_id, created_at DESC);

CREATE TABLE public.cad_projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  connection_id uuid,
  provider text NOT NULL CHECK (provider IN ('fusion','onshape')),
  external_document_id text NOT NULL, -- unsaved:<session UUID> when no saved file
  external_workspace_id text,
  project_key text NOT NULL, -- separates intentional projects for the same design
  project_name text NOT NULL CHECK (length(btrim(project_name)) BETWEEN 1 AND 120),
  document_name text NOT NULL,
  project_kit_id uuid UNIQUE REFERENCES public.project_kits(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','disconnected')),
  sharing_consent_at timestamptz NOT NULL,
  source_metadata jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(source_metadata)='object'),
  last_analyzed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, inventory_id),
  UNIQUE (inventory_id, provider, external_document_id, project_key),
  FOREIGN KEY (connection_id, inventory_id) REFERENCES public.cad_connections(id, inventory_id)
    ON DELETE SET NULL (connection_id)
);
CREATE INDEX cad_projects_inventory_recent ON public.cad_projects (inventory_id, updated_at DESC, id);
CREATE INDEX cad_projects_connection ON public.cad_projects (connection_id);

CREATE TABLE public.cad_assemblies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  project_id uuid NOT NULL,
  external_assembly_id text NOT NULL,
  name text NOT NULL,
  configuration_key text NOT NULL,
  configuration jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(configuration)='object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, inventory_id),
  UNIQUE (project_id, external_assembly_id, configuration_key),
  FOREIGN KEY (project_id, inventory_id) REFERENCES public.cad_projects(id, inventory_id) ON DELETE CASCADE
);

CREATE TABLE public.cad_bom_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  assembly_id uuid NOT NULL,
  extraction_id uuid NOT NULL,
  snapshot_version integer NOT NULL CHECK (snapshot_version > 0),
  schema_version integer NOT NULL CHECK (schema_version=1),
  source_revision_kind text NOT NULL CHECK (source_revision_kind IN ('saved_version','microversion','unsaved_session')),
  source_revision_id text NOT NULL,
  source_dirty boolean NOT NULL,
  content_sha256 text NOT NULL CHECK (content_sha256 ~ '^[a-f0-9]{64}$'),
  adapter_version text NOT NULL,
  host_version text NOT NULL,
  completeness text NOT NULL CHECK (completeness IN ('complete','partial','invalid')),
  component_count integer NOT NULL CHECK (component_count BETWEEN 0 AND 10000),
  occurrence_count integer NOT NULL CHECK (occurrence_count BETWEEN 0 AND 50000),
  totals_by_unit jsonb NOT NULL CHECK (jsonb_typeof(totals_by_unit)='object'),
  graph jsonb NOT NULL CHECK (jsonb_typeof(graph)='object'),
  source_metadata jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(source_metadata)='object'),
  warnings jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(warnings)='array'),
  extracted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  extracted_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, inventory_id),
  UNIQUE (assembly_id, snapshot_version),
  UNIQUE (assembly_id, extraction_id),
  FOREIGN KEY (assembly_id, inventory_id) REFERENCES public.cad_assemblies(id, inventory_id) ON DELETE CASCADE
);
CREATE INDEX cad_snapshot_recent ON public.cad_bom_snapshots (assembly_id, created_at DESC, id);

CREATE TABLE public.cad_bom_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  snapshot_id uuid NOT NULL,
  line_key text NOT NULL,
  definition_key text NOT NULL,
  occurrence_keys text[] NOT NULL DEFAULT '{}',
  component_name text NOT NULL,
  part_number text,
  manufacturer text,
  sku text,
  barcode text,
  identifiers jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(identifiers)='array'),
  quantity_required numeric(18,6) NOT NULL CHECK (quantity_required > 0 AND quantity_required <= 1000000000),
  unit text NOT NULL CHECK (length(unit) BETWEEN 1 AND 40),
  counting_mode text NOT NULL CHECK (counting_mode IN ('occurrences','provider_aggregate','explicit')),
  procurement_policy text NOT NULL CHECK (procurement_policy IN ('purchase','fabricate','assembly','exclude','review')),
  critical boolean NOT NULL DEFAULT false,
  dimensions jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(dimensions)='object'),
  material jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(material)='object'),
  attributes jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(attributes)='object'),
  source_metadata jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(source_metadata)='object'),
  kit_item_id uuid REFERENCES public.project_kit_items(id) ON DELETE SET NULL,
  UNIQUE (id, snapshot_id, inventory_id),
  UNIQUE (snapshot_id, line_key),
  FOREIGN KEY (snapshot_id, inventory_id) REFERENCES public.cad_bom_snapshots(id, inventory_id) ON DELETE CASCADE
);
CREATE INDEX cad_bom_kit_line ON public.cad_bom_items (kit_item_id);
CREATE INDEX cad_bom_identifier ON public.cad_bom_items (inventory_id, manufacturer, part_number);

CREATE TABLE public.cad_analyses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  snapshot_id uuid NOT NULL,
  analysis_version integer NOT NULL CHECK (analysis_version > 0),
  matcher_version text NOT NULL,
  inventory_as_of timestamptz NOT NULL,
  inventory_fingerprint text NOT NULL CHECK (inventory_fingerprint ~ '^[a-f0-9]{64}$'),
  inventory_evidence jsonb NOT NULL CHECK (jsonb_typeof(inventory_evidence)='object'),
  status text NOT NULL CHECK (status IN ('complete','partial','needs_review')),
  coverage_by_unit jsonb NOT NULL CHECK (jsonb_typeof(coverage_by_unit)='object'),
  summary jsonb NOT NULL CHECK (jsonb_typeof(summary)='object'),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, snapshot_id, inventory_id),
  UNIQUE (snapshot_id, analysis_version),
  FOREIGN KEY (snapshot_id, inventory_id) REFERENCES public.cad_bom_snapshots(id, inventory_id) ON DELETE CASCADE
);
CREATE INDEX cad_analysis_recent ON public.cad_analyses (inventory_id, created_at DESC, id);

CREATE TABLE public.cad_item_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  snapshot_id uuid NOT NULL,
  analysis_id uuid NOT NULL,
  bom_item_id uuid NOT NULL,
  inventory_item_id uuid REFERENCES public.items(item_id) ON DELETE SET NULL,
  candidate_key text NOT NULL, -- immutable item key or 'no-match'; remains after item deletion
  match_type text NOT NULL CHECK (match_type IN ('exact','probable','alternative','none')),
  review_status text NOT NULL CHECK (review_status IN ('unreviewed','confirmed','rejected','stale')),
  confidence numeric(6,5) CHECK (confidence >= 0 AND confidence <= 1),
  evidence jsonb NOT NULL CHECK (jsonb_typeof(evidence)='object'),
  quantity_available numeric(18,6) NOT NULL CHECK (quantity_available >= 0 AND quantity_available <= 1000000000),
  quantity_assigned numeric(18,6) NOT NULL CHECK (quantity_assigned >= 0 AND quantity_assigned <= quantity_available),
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  UNIQUE (analysis_id, bom_item_id, candidate_key),
  FOREIGN KEY (analysis_id, snapshot_id, inventory_id) REFERENCES public.cad_analyses(id, snapshot_id, inventory_id) ON DELETE CASCADE,
  FOREIGN KEY (bom_item_id, snapshot_id, inventory_id) REFERENCES public.cad_bom_items(id, snapshot_id, inventory_id) ON DELETE CASCADE
);
CREATE INDEX cad_matches_item ON public.cad_item_matches (inventory_item_id);
CREATE INDEX cad_matches_review ON public.cad_item_matches (analysis_id, review_status, id);

CREATE TABLE public.cad_build_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  project_id uuid NOT NULL,
  idempotency_key uuid NOT NULL,
  payload_sha256 text NOT NULL CHECK (payload_sha256 ~ '^[a-f0-9]{64}$'),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  build_kind text NOT NULL CHECK (build_kind IN ('partial','final','reversal')),
  -- Frozen analysis/revision/item/reservation/event IDs and before/after evidence.
  -- JSON references survive deletion; no historical live-stock join is needed.
  analysis_evidence jsonb NOT NULL CHECK (jsonb_typeof(analysis_evidence)='object'),
  consumption jsonb NOT NULL CHECK (jsonb_typeof(consumption)='array'),
  released_allocations jsonb NOT NULL CHECK (jsonb_typeof(released_allocations)='array'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id, idempotency_key),
  FOREIGN KEY (project_id, inventory_id) REFERENCES public.cad_projects(id, inventory_id) ON DELETE CASCADE
);
CREATE INDEX cad_build_recent ON public.cad_build_records (project_id, created_at DESC, id);

CREATE TABLE public.cad_operation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  project_id uuid NOT NULL,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  operation text NOT NULL CHECK (operation IN ('extract','analyze','allocate','release','consume','purge')),
  idempotency_key uuid NOT NULL,
  payload_sha256 text NOT NULL CHECK (payload_sha256 ~ '^[a-f0-9]{64}$'),
  status text NOT NULL CHECK (status IN ('pending','running','succeeded','failed','cancelled')),
  lease_id uuid,
  lease_expires_at timestamptz,
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  result jsonb,
  safe_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id, operation, idempotency_key),
  FOREIGN KEY (project_id, inventory_id) REFERENCES public.cad_projects(id, inventory_id) ON DELETE CASCADE
);
CREATE INDEX cad_pending_operation ON public.cad_operation_requests (status, lease_expires_at)
  WHERE status IN ('pending','running');
CREATE INDEX cad_operation_actor ON public.cad_operation_requests (actor_id, created_at DESC);

-- Do not grant this view to end users: the existing reservation RLS model is
-- legacy-sensitive. The repository must authorize the project before querying.
CREATE VIEW public.inventory_allocations WITH (security_invoker = true) AS
SELECT r.id, p.id AS cad_project_id, p.inventory_id, r.kit_id, r.kit_item_id,
       r.inventory_item_id, r.quantity AS quantity_allocated,
       'active'::text AS allocation_status, r.created_by_user_id, r.created_at
FROM public.cad_projects p
JOIN public.project_kit_reservations r
  ON r.kit_id = p.project_kit_id AND r.inventory_id = p.inventory_id;
REVOKE ALL ON public.inventory_allocations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.inventory_allocations TO service_role;

-- Reference checks avoid adding composite keys to existing inventory tables.
-- They supplement, NOT replace, actor checks and row locks in future write RPCs.
CREATE FUNCTION public.cad_validate_legacy_reference() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
DECLARE target_inventory uuid; target_kit uuid; expected_kit uuid;
BEGIN
  IF TG_TABLE_NAME = 'cad_projects' THEN
    IF NEW.connection_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.cad_connections c WHERE c.id=NEW.connection_id
        AND c.inventory_id=NEW.inventory_id AND c.provider=NEW.provider
    ) THEN RAISE EXCEPTION 'CAD_CONNECTION_SCOPE_MISMATCH'; END IF;
    IF NEW.project_kit_id IS NOT NULL THEN
      SELECT inventory_id INTO target_inventory FROM public.project_kits WHERE id=NEW.project_kit_id;
      IF target_inventory IS DISTINCT FROM NEW.inventory_id THEN
        RAISE EXCEPTION 'CAD_KIT_SCOPE_MISMATCH';
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'cad_bom_items' THEN
    IF NEW.kit_item_id IS NULL THEN RETURN NEW; END IF;
    SELECT inventory_id, kit_id INTO target_inventory, target_kit
      FROM public.project_kit_items WHERE id=NEW.kit_item_id;
    SELECT p.project_kit_id INTO expected_kit FROM public.cad_projects p
      JOIN public.cad_assemblies a ON a.project_id=p.id
      JOIN public.cad_bom_snapshots s ON s.assembly_id=a.id WHERE s.id=NEW.snapshot_id;
    IF target_inventory IS DISTINCT FROM NEW.inventory_id OR expected_kit IS NULL
       OR target_kit IS DISTINCT FROM expected_kit THEN RAISE EXCEPTION 'CAD_KIT_LINE_MISMATCH'; END IF;
  ELSIF TG_TABLE_NAME = 'cad_item_matches' THEN
    IF NEW.inventory_item_id IS NULL THEN RETURN NEW; END IF;
    SELECT inventory_id INTO target_inventory FROM public.items WHERE item_id=NEW.inventory_item_id;
    IF target_inventory IS DISTINCT FROM NEW.inventory_id THEN RAISE EXCEPTION 'CAD_ITEM_SCOPE_MISMATCH'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cad_validate_legacy_reference() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER cad_projects_reference BEFORE INSERT OR UPDATE ON public.cad_projects
  FOR EACH ROW EXECUTE FUNCTION public.cad_validate_legacy_reference();
CREATE TRIGGER cad_bom_reference BEFORE INSERT OR UPDATE ON public.cad_bom_items
  FOR EACH ROW EXECUTE FUNCTION public.cad_validate_legacy_reference();
CREATE TRIGGER cad_match_reference BEFORE INSERT OR UPDATE ON public.cad_item_matches
  FOR EACH ROW EXECUTE FUNCTION public.cad_validate_legacy_reference();

-- Shared reads use strict inventory role, not the legacy permissive helper.
-- Explicitly deny integration API-key identities until a CAD scope exists.
DO $$
DECLARE relation_name text;
BEGIN
  FOREACH relation_name IN ARRAY ARRAY[
    'cad_connections','cad_projects','cad_assemblies','cad_bom_snapshots',
    'cad_bom_items','cad_analyses','cad_item_matches','cad_build_records','cad_operation_requests'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', relation_name);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated', relation_name);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO service_role', relation_name);
    IF relation_name NOT IN ('cad_connections','cad_operation_requests') THEN
      EXECUTE format('GRANT SELECT ON public.%I TO authenticated', relation_name);
      EXECUTE format($policy$
        CREATE POLICY cad_inventory_read ON public.%I FOR SELECT TO authenticated USING (
          auth.uid() IS NOT NULL
          AND NOT (coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb) ? 'api_key_id')
          AND public.findez_inventory_role(inventory_id,auth.uid()) IS NOT NULL
        )
      $policy$, relation_name);
    END IF;
  END LOOP;
END $$;

-- NO mutation RPC, provider authentication or inventory update is activated here.
-- Snapshot immutability, service-role authorization, deletion choreography and
-- item move races require the reviewed runtime transaction layer before promotion.
ROLLBACK;

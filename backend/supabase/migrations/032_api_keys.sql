BEGIN;
-- A dedicated login, never a table owner, service role, or member of authenticated.
CREATE ROLE findez_api LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE SCHEMA api_private;
REVOKE ALL ON SCHEMA api_private FROM PUBLIC;
GRANT USAGE ON SCHEMA public, api_private TO findez_api;
CREATE TABLE public.organizations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE public.organization_memberships (
 org_id uuid REFERENCES public.organizations(id), user_id uuid NOT NULL,
 role text NOT NULL CHECK (role IN ('admin','member')), PRIMARY KEY(org_id,user_id));
CREATE TABLE public.workspaces (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), org_id uuid NOT NULL REFERENCES public.organizations(id),
 name text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(id,org_id));
CREATE TABLE public.workspace_memberships (
 workspace_id uuid REFERENCES public.workspaces(id), user_id uuid NOT NULL,
 PRIMARY KEY(workspace_id,user_id));
ALTER TABLE public.items ADD COLUMN workspace_id uuid REFERENCES public.workspaces(id),
 ADD COLUMN source_system text, ADD COLUMN external_id text;
CREATE UNIQUE INDEX items_external_identity ON public.items(workspace_id,source_system,external_id);
CREATE INDEX items_api_workspace ON public.items(workspace_id,item_id);
CREATE TABLE public.api_keys (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid,
 org_id uuid NOT NULL REFERENCES public.organizations(id), name text NOT NULL CHECK(length(name) BETWEEN 1 AND 120),
 key_prefix text NOT NULL CHECK(length(key_prefix)=20), key_hash text NOT NULL,
 scopes text[] NOT NULL, created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 last_used_at timestamptz, expires_at timestamptz, revoked_at timestamptz,
 FOREIGN KEY(workspace_id,org_id) REFERENCES public.workspaces(id,org_id),
 CHECK(cardinality(scopes)>0 AND array_position(scopes,NULL) IS NULL AND
 ((workspace_id IS NULL AND scopes <@ ARRAY['org:read','org:write']) OR
 (workspace_id IS NOT NULL AND scopes <@ ARRAY['items:read','items:write','import:write','workspace:read']))));
CREATE INDEX api_keys_prefix ON public.api_keys(key_prefix);
CREATE TABLE api_private.rate_windows (
 key_id uuid PRIMARY KEY REFERENCES public.api_keys(id), window_start timestamptz NOT NULL,
 requests integer NOT NULL, bulk_requests integer NOT NULL);
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;
-- Default privileges in Supabase can expose new objects; explicitly close them.
REVOKE ALL ON public.organizations,public.organization_memberships,public.workspaces,
 public.workspace_memberships,public.api_keys FROM PUBLIC,anon,authenticated,findez_api;
REVOKE ALL ON ALL TABLES IN SCHEMA api_private FROM PUBLIC,anon,authenticated,findez_api;
CREATE FUNCTION api_private.claims() RETURNS jsonb LANGUAGE sql STABLE
 SET search_path = pg_catalog AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
CREATE FUNCTION api_private.managed_orgs() RETURNS TABLE(org_id uuid)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
 SELECT m.org_id FROM public.organization_memberships m
 WHERE api_private.claims()->>'auth_kind'='session'
 AND m.user_id=(api_private.claims()->>'sub')::uuid AND m.role='admin' $$;
CREATE FUNCTION api_private.lookup_key(prefix text) RETURNS SETOF public.api_keys
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
 SELECT * FROM public.api_keys WHERE key_prefix=prefix $$;
-- Re-read key authority in the database: caller-supplied org/workspace claims are never trusted.
CREATE FUNCTION api_private.allowed(target uuid, operation text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
 SELECT EXISTS(SELECT 1 FROM public.api_keys k JOIN public.workspaces w ON w.org_id=k.org_id
 WHERE k.id=(api_private.claims()->>'api_key_id')::uuid AND w.id=target
 AND api_private.claims()->>'auth_kind'='api_key'
 AND k.revoked_at IS NULL AND (k.expires_at IS NULL OR k.expires_at>statement_timestamp())
 AND k.key_prefix LIKE ('findez_' || (api_private.claims()->>'environment') || '_sk_%')
 AND (k.workspace_id IS NULL OR k.workspace_id=w.id)
 AND ((k.workspace_id IS NULL AND
   CASE WHEN operation IN ('items:write','import:write') THEN 'org:write' ELSE 'org:read' END=ANY(k.scopes))
 OR (k.workspace_id IS NOT NULL AND operation=ANY(k.scopes)))) $$;
-- Restrictive guard defeats legacy permissive PUBLIC policies, including user_id = auth.uid().
CREATE POLICY api_items_guard ON public.items AS RESTRICTIVE FOR ALL TO findez_api
 USING(api_private.allowed(workspace_id,api_private.claims()->>'api_scope'))
 WITH CHECK(api_private.allowed(workspace_id,api_private.claims()->>'api_scope'));
CREATE POLICY api_items_write_insert_guard ON public.items AS RESTRICTIVE FOR INSERT TO findez_api
 WITH CHECK(api_private.claims()->>'api_scope' IN ('items:write','import:write') AND user_id=(api_private.claims()->>'sub')::uuid);
CREATE POLICY api_items_write_update_guard ON public.items AS RESTRICTIVE FOR UPDATE TO findez_api
 USING(api_private.claims()->>'api_scope' IN ('items:write','import:write'))
 WITH CHECK(api_private.claims()->>'api_scope' IN ('items:write','import:write'));
CREATE POLICY api_items_select ON public.items FOR SELECT TO findez_api
 USING(api_private.claims()->>'api_scope' IN ('items:read','workspace:read','items:write','import:write'));
CREATE POLICY api_items_insert ON public.items FOR INSERT TO findez_api
 WITH CHECK(api_private.claims()->>'api_scope' IN ('items:write','import:write') AND user_id=(api_private.claims()->>'sub')::uuid);
CREATE POLICY api_items_update ON public.items FOR UPDATE TO findez_api
 USING(api_private.claims()->>'api_scope' IN ('items:write','import:write'))
 WITH CHECK(api_private.claims()->>'api_scope' IN ('items:write','import:write'));
CREATE POLICY api_workspace_read ON public.workspaces FOR SELECT TO findez_api
 USING(api_private.allowed(id,api_private.claims()->>'api_scope'));
GRANT SELECT ON public.items,public.workspaces TO findez_api;
GRANT INSERT(user_id,workspace_id,name,category,quantity,location,notes,barcode,source_system,external_id),
 UPDATE(name,category,quantity,location,notes,barcode) ON public.items TO findez_api;
CREATE FUNCTION api_private.create_key(target_org uuid, target_workspace uuid, label text, prefix text, hash text, permissions text[], expiry timestamptz)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
 DECLARE result uuid;
 BEGIN
 IF NOT EXISTS(SELECT 1 FROM api_private.managed_orgs() WHERE org_id=target_org) THEN
 RAISE insufficient_privilege; END IF;
 INSERT INTO public.api_keys(org_id,workspace_id,name,key_prefix,key_hash,scopes,created_by,expires_at)
 VALUES(target_org,target_workspace,label,prefix,hash,permissions,(api_private.claims()->>'sub')::uuid,expiry)
 RETURNING id INTO result;
 RETURN result;
 END $$;
CREATE FUNCTION api_private.list_keys(target_org uuid)
 RETURNS TABLE(id uuid,workspace_id uuid,name text,key_prefix text,scopes text[],created_at timestamptz,last_used_at timestamptz,expires_at timestamptz,revoked_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
 SELECT k.id,k.workspace_id,k.name,k.key_prefix,k.scopes,k.created_at,k.last_used_at,k.expires_at,k.revoked_at
 FROM public.api_keys k WHERE k.org_id=target_org
 AND EXISTS(SELECT 1 FROM api_private.managed_orgs() m WHERE m.org_id=target_org) ORDER BY k.created_at DESC $$;
CREATE FUNCTION api_private.revoke_key(target_org uuid,target_key uuid) RETURNS boolean
 LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
 BEGIN
 IF NOT EXISTS(SELECT 1 FROM api_private.managed_orgs() WHERE org_id=target_org) THEN
 RAISE insufficient_privilege; END IF;
 UPDATE public.api_keys SET revoked_at=coalesce(revoked_at,now()) WHERE id=target_key AND org_id=target_org;
 RETURN FOUND;
 END $$;
CREATE FUNCTION api_private.admit_request(is_bulk boolean) RETURNS text
 LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
 DECLARE k public.api_keys; r api_private.rate_windows; minute timestamptz=date_trunc('minute',clock_timestamp());
 BEGIN
 SELECT * INTO k FROM public.api_keys WHERE id=(api_private.claims()->>'api_key_id')::uuid;
 IF NOT FOUND OR api_private.claims()->>'auth_kind' IS DISTINCT FROM 'api_key'
 OR k.revoked_at IS NOT NULL OR (k.expires_at IS NOT NULL AND k.expires_at<=clock_timestamp()) THEN RETURN 'inactive'; END IF;
 INSERT INTO api_private.rate_windows VALUES(k.id,minute,1,is_bulk::integer)
 ON CONFLICT(key_id) DO UPDATE SET
 window_start=minute,
 requests=CASE WHEN rate_windows.window_start=minute THEN rate_windows.requests+1 ELSE 1 END,
 bulk_requests=CASE WHEN rate_windows.window_start=minute THEN rate_windows.bulk_requests+is_bulk::integer ELSE is_bulk::integer END
 RETURNING * INTO r;
 IF r.requests>120 OR r.bulk_requests>10 THEN RETURN 'limited'; END IF;
 UPDATE public.api_keys SET last_used_at=clock_timestamp() WHERE id=k.id
 AND (last_used_at IS NULL OR last_used_at<clock_timestamp()-interval '5 minutes');
 RETURN 'ok';
 END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA api_private FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api_private TO findez_api;
COMMIT;

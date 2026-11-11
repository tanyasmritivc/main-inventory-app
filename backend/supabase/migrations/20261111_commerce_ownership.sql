-- Owner-scoped connections. Apply after commerce connectors and purchase email.
-- Existing non-Gmail connections become PRIVATE personal records, never team records.
BEGIN;
ALTER TABLE public.commerce_connections ADD COLUMN IF NOT EXISTS scope_type text NOT NULL DEFAULT 'legacy_inventory';
ALTER TABLE public.commerce_connections ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.commerce_connections ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.app_organizations(organization_id) ON DELETE CASCADE;
ALTER TABLE public.commerce_connections ALTER COLUMN inventory_id DROP NOT NULL;
ALTER TABLE public.commerce_connections ALTER COLUMN actor_id DROP NOT NULL;
ALTER TABLE public.commerce_connections DROP CONSTRAINT IF EXISTS commerce_connections_actor_id_fkey;
ALTER TABLE public.commerce_connections ADD CONSTRAINT commerce_connections_actor_id_fkey FOREIGN KEY(actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;
UPDATE public.commerce_connections SET owner_user_id=actor_id WHERE scope_type='legacy_inventory' AND owner_user_id IS NULL;
-- Never restore revoked inventory access by promoting old records.
-- Keep Gmail's inventory contract intact. Its records remain private and visible
-- under Previous inventory connections until that separate integration is upgraded.
UPDATE public.commerce_connections c SET scope_type='personal',inventory_id=NULL
 WHERE scope_type='legacy_inventory'
 AND coalesce(public.findez_inventory_role(c.inventory_id,c.actor_id),'') IN ('owner','admin','editor')
 AND NOT EXISTS(SELECT FROM public.commerce_gmail_accounts g WHERE g.connection_id=c.id);
ALTER TABLE public.commerce_connections DROP CONSTRAINT IF EXISTS commerce_connection_owner;
ALTER TABLE public.commerce_connections ADD CONSTRAINT commerce_connection_owner CHECK (
 (scope_type='personal' AND owner_user_id IS NOT NULL AND organization_id IS NULL AND inventory_id IS NULL) OR
 (scope_type='organization' AND owner_user_id IS NULL AND organization_id IS NOT NULL AND inventory_id IS NULL) OR
 (scope_type='legacy_inventory' AND inventory_id IS NOT NULL AND organization_id IS NULL));
-- Legacy Gmail/old clients still create actor-owned rows. Keep their owner FK
-- populated so deleting that user removes private records rather than orphaning them.
CREATE OR REPLACE FUNCTION public.findez_commerce_legacy_owner() RETURNS trigger
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 IF NEW.scope_type='legacy_inventory' THEN NEW.owner_user_id:=NEW.actor_id; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS commerce_legacy_owner ON public.commerce_connections;
CREATE TRIGGER commerce_legacy_owner BEFORE INSERT ON public.commerce_connections
 FOR EACH ROW EXECUTE FUNCTION public.findez_commerce_legacy_owner();
REVOKE ALL ON FUNCTION public.findez_commerce_legacy_owner() FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS commerce_personal_owner ON public.commerce_connections(owner_user_id,scope_type);
CREATE INDEX IF NOT EXISTS commerce_organization_owner ON public.commerce_connections(organization_id) WHERE organization_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.findez_commerce_can_access(c public.commerce_connections,p_actor uuid,p_disconnect boolean DEFAULT false) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT p_actor IS NOT NULL AND CASE c.scope_type
 WHEN 'personal' THEN c.owner_user_id=p_actor
 WHEN 'organization' THEN EXISTS(SELECT FROM public.app_organization_members WHERE organization_id=c.organization_id AND user_id=p_actor AND role IN ('owner','admin'))
 ELSE c.actor_id=p_actor AND (p_disconnect OR coalesce(public.findez_inventory_role(c.inventory_id,p_actor),'') IN ('owner','admin','editor')) END
$$;
REVOKE ALL ON FUNCTION public.findez_commerce_can_access(public.commerce_connections,uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_commerce_can_access(public.commerce_connections,uuid,boolean) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_commerce_start_scoped(p_actor uuid,p_scope text,p_organization uuid,p_provider text,
 p_account text,p_region text,p_marketplace text,p_state_hash text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.commerce_connections;
BEGIN
 IF p_actor IS NULL OR p_scope NOT IN ('personal','organization') OR
 (p_scope='personal' AND p_organization IS NOT NULL) OR
 (p_scope='organization' AND (p_organization IS NULL OR NOT EXISTS(SELECT FROM public.app_organization_members
 WHERE organization_id=p_organization AND user_id=p_actor AND role IN ('owner','admin')))) THEN
  RAISE EXCEPTION 'commerce_access_denied' USING ERRCODE='42501'; END IF;
 -- Reuse a migrated import as well as a newly created one. Older separate sources
 -- are retained with their original IDs and records rather than silently deleted.
 IF p_scope='organization' THEN
  PERFORM 1 FROM public.app_organization_members WHERE organization_id=p_organization AND user_id=p_actor AND role IN ('owner','admin') FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'commerce_access_denied' USING ERRCODE='42501'; END IF;
 END IF;
 IF p_provider='amazon_consumer' THEN
  SELECT * INTO c FROM public.commerce_connections WHERE scope_type=p_scope AND provider=p_provider AND status='connected'
   AND ((p_scope='personal' AND owner_user_id=p_actor) OR (p_scope='organization' AND organization_id=p_organization))
   ORDER BY created_at,id LIMIT 1 FOR UPDATE;
  IF FOUND THEN RETURN to_jsonb(c); END IF;
 END IF;
 DELETE FROM public.commerce_connections WHERE status='pending' AND state_expires_at<now();
 INSERT INTO public.commerce_connections(actor_id,owner_user_id,scope_type,organization_id,provider,external_account,region,marketplace,status,state_hash,state_expires_at)
 VALUES(p_actor,CASE WHEN p_scope='personal' THEN p_actor ELSE NULL END,p_scope,p_organization,p_provider,p_account,p_region,p_marketplace,
 CASE WHEN p_provider='amazon_consumer' THEN 'connected' ELSE 'pending' END,p_state_hash,now()+interval '10 minutes') RETURNING * INTO c;
 RETURN to_jsonb(c);
END $$;
REVOKE ALL ON FUNCTION public.findez_commerce_start_scoped(uuid,text,uuid,text,text,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_commerce_start_scoped(uuid,text,uuid,text,text,text,text,text) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_commerce_transition(p_actor uuid,p_connection uuid,p_action text,p_payload jsonb DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.commerce_connections; r jsonb; v_lease uuid;
BEGIN
 SELECT * INTO c FROM public.commerce_connections WHERE id=p_connection FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'commerce_not_found' USING ERRCODE='P0002'; END IF;
 IF c.scope_type='organization' THEN
  PERFORM 1 FROM public.app_organization_members WHERE organization_id=c.organization_id AND user_id=p_actor AND role IN ('owner','admin') FOR SHARE;
 END IF;
 IF NOT public.findez_commerce_can_access(c,p_actor,p_action='disconnect') THEN
  RAISE EXCEPTION 'commerce_access_denied' USING ERRCODE='42501'; END IF;
 IF p_action='disconnect' THEN
  IF coalesce((p_payload->>'purge')::boolean,false) THEN
   DELETE FROM public.commerce_connections WHERE id=c.id;
  ELSE
   UPDATE public.commerce_connections SET status='disconnected',token_ciphertext=NULL,state_hash=NULL,
    state_expires_at=NULL,lease_id=NULL,lease_expires_at=NULL,updated_at=now() WHERE id=c.id;
  END IF;
  RETURN jsonb_build_object('status','disconnected','purged',coalesce((p_payload->>'purge')::boolean,false));
 END IF;

 IF p_action='oauth_claim' THEN
  IF c.status<>'pending' OR c.state_hash IS NULL OR c.state_hash IS DISTINCT FROM p_payload->>'state_hash' OR c.state_expires_at<=now() THEN
   RAISE EXCEPTION 'commerce_oauth_expired' USING ERRCODE='40001'; END IF;
  v_lease:=gen_random_uuid();
  UPDATE public.commerce_connections SET status='authorizing',state_hash=NULL,lease_id=v_lease,
   lease_expires_at=now()+interval '120 seconds',updated_at=now() WHERE id=c.id RETURNING * INTO c;
 ELSIF p_action='sync_claim' THEN
  IF c.status<>'connected' OR (c.lease_id IS NOT NULL AND c.lease_expires_at>now()) THEN
   RAISE EXCEPTION 'commerce_busy_or_disconnected' USING ERRCODE='40001'; END IF;
  v_lease:=gen_random_uuid();
  UPDATE public.commerce_connections SET lease_id=v_lease,lease_expires_at=now()+interval '120 seconds',updated_at=now()
   WHERE id=c.id RETURNING * INTO c;
 ELSE
  IF c.lease_id IS NULL OR c.lease_id IS DISTINCT FROM (p_payload->>'lease_id')::uuid OR c.lease_expires_at<=now() THEN
   RAISE EXCEPTION 'commerce_stale_claim' USING ERRCODE='40001'; END IF;
  IF p_action IN ('oauth_finish','tokens') THEN
   IF (p_action='oauth_finish' AND c.status<>'authorizing') OR (p_action='tokens' AND c.status<>'connected') THEN
    RAISE EXCEPTION 'commerce_invalid_state' USING ERRCODE='40001'; END IF;
   IF coalesce(length(p_payload->>'token_ciphertext'),0)=0 THEN RAISE EXCEPTION 'commerce_missing_tokens'; END IF;
   UPDATE public.commerce_connections SET token_ciphertext=p_payload->>'token_ciphertext',
    scopes=coalesce(p_payload->'scopes',scopes),status='connected',last_error=NULL,
    lease_id=CASE WHEN p_action='oauth_finish' THEN NULL ELSE lease_id END,
    lease_expires_at=CASE WHEN p_action='oauth_finish' THEN NULL ELSE lease_expires_at END,
    updated_at=now() WHERE id=c.id RETURNING * INTO c;
  ELSIF p_action='commit' THEN
   IF c.status<>'connected' OR jsonb_typeof(p_payload->'records') IS DISTINCT FROM 'array' OR jsonb_array_length(p_payload->'records')>10000 THEN
    RAISE EXCEPTION 'commerce_invalid_batch'; END IF;
   IF coalesce(p_payload->>'resource','') NOT IN ('catalog','orders','stock','purchases') THEN RAISE EXCEPTION 'commerce_invalid_resource'; END IF;
   -- Catalog/stock are complete snapshots. An incomplete fetch must never call this.
   IF p_payload->>'resource' IN ('catalog','stock') THEN
    DELETE FROM public.commerce_source_records WHERE connection_id=c.id AND resource=p_payload->>'resource';
   END IF;
   FOR r IN SELECT value FROM jsonb_array_elements(p_payload->'records') LOOP
    IF (c.provider='amazon_consumer' AND r->>'kind'<>'purchase_line') OR
       (c.provider<>'amazon_consumer' AND r->>'kind'='purchase_line') THEN RAISE EXCEPTION 'commerce_wrong_direction'; END IF;
    IF c.provider='shopify' AND r->>'kind'='sale_line' AND EXISTS(
     SELECT 1 FROM public.commerce_order_redactions WHERE shop=c.external_account
      AND order_hash=encode(sha256(convert_to(r->>'order_id','UTF8')),'hex')) THEN CONTINUE; END IF;
    INSERT INTO public.commerce_source_records(connection_id,kind,external_id,resource,data,observed_at)
    VALUES(c.id,r->>'kind',r->>'external_id',p_payload->>'resource',r,now())
    ON CONFLICT(connection_id,kind,external_id) DO UPDATE SET data=excluded.data,resource=excluded.resource,observed_at=excluded.observed_at;
   END LOOP;
   UPDATE public.commerce_connections SET last_sync_at=now(),last_error=NULL,lease_id=NULL,lease_expires_at=NULL,updated_at=now()
    WHERE id=c.id RETURNING * INTO c;
  ELSIF p_action='fail' THEN
   UPDATE public.commerce_connections SET status=CASE WHEN status='authorizing' THEN 'disconnected' ELSE status END,
    last_error='Sync or authorization failed. Retry or reconnect.',lease_id=NULL,lease_expires_at=NULL,updated_at=now()
    WHERE id=c.id RETURNING * INTO c;
  ELSE RAISE EXCEPTION 'commerce_invalid_action'; END IF;
 END IF;
 RETURN to_jsonb(c);
END $$;
REVOKE ALL ON FUNCTION public.findez_commerce_start(uuid,uuid,text,text,text,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.findez_commerce_transition(uuid,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_commerce_start(uuid,uuid,text,text,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.findez_commerce_transition(uuid,uuid,text,jsonb) TO service_role;


COMMIT;

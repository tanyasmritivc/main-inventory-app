-- Additive, service-only commerce evidence. Does not change items or reservations.
BEGIN;
CREATE TABLE IF NOT EXISTS public.commerce_connections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 provider text NOT NULL CHECK(provider IN ('shopify','amazon_seller','amazon_consumer')),
 external_account text NOT NULL CHECK(length(external_account) BETWEEN 1 AND 200),
 region text NOT NULL DEFAULT '', marketplace text NOT NULL DEFAULT '',
 status text NOT NULL CHECK(status IN ('pending','authorizing','connected','disconnected')),
 state_hash text, state_expires_at timestamptz, token_ciphertext text,
 lease_id uuid, lease_expires_at timestamptz,
 scopes jsonb NOT NULL DEFAULT '[]',
 last_sync_at timestamptz, last_error text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
-- Shopify issues one current offline token per app/store. Do not silently steal a
-- connection by attaching the same store to another actor or inventory.
CREATE UNIQUE INDEX IF NOT EXISTS commerce_live_account ON public.commerce_connections(provider, external_account)
 WHERE status <> 'disconnected';
CREATE INDEX IF NOT EXISTS commerce_actor_inventory ON public.commerce_connections(actor_id,inventory_id);
CREATE TABLE IF NOT EXISTS public.commerce_webhook_receipts (
 event_hash text PRIMARY KEY, shop text NOT NULL, topic text NOT NULL, received_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.commerce_order_redactions (
 shop text NOT NULL, order_hash text NOT NULL, PRIMARY KEY(shop,order_hash)
);
CREATE TABLE IF NOT EXISTS public.commerce_privacy_exports (
 connection_id uuid NOT NULL REFERENCES public.commerce_connections(id) ON DELETE CASCADE,
 request_id text NOT NULL, records jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(connection_id,request_id)
);
CREATE TABLE IF NOT EXISTS public.commerce_source_records (
 connection_id uuid NOT NULL REFERENCES public.commerce_connections(id) ON DELETE CASCADE,
 kind text NOT NULL CHECK(kind IN ('catalog_variant','merchant_stock','sale_line','purchase_line')),
 external_id text NOT NULL CHECK(length(external_id) BETWEEN 1 AND 500),
 resource text NOT NULL CHECK(resource IN ('catalog','orders','stock','purchases')),
 data jsonb NOT NULL CHECK(jsonb_typeof(data)='object' AND (data->'physically_verified') IS NOT DISTINCT FROM 'false'::jsonb),
 observed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(connection_id,kind,external_id)
);
ALTER TABLE public.commerce_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerce_source_records ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.commerce_connections,public.commerce_source_records FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.commerce_connections,public.commerce_source_records TO service_role;
ALTER TABLE public.commerce_webhook_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerce_order_redactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerce_privacy_exports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.commerce_webhook_receipts,public.commerce_order_redactions,public.commerce_privacy_exports FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.commerce_webhook_receipts,public.commerce_order_redactions,public.commerce_privacy_exports TO service_role;

CREATE OR REPLACE FUNCTION public.findez_commerce_start(p_actor uuid,p_inventory uuid,p_provider text,
 p_account text,p_region text,p_marketplace text,p_state_hash text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.commerce_connections;
BEGIN
 IF coalesce(public.findez_inventory_role(p_inventory,p_actor),'') NOT IN ('owner','admin','editor') THEN
  RAISE EXCEPTION 'commerce_access_denied' USING ERRCODE='42501'; END IF;
 DELETE FROM public.commerce_connections WHERE status='pending' AND state_expires_at<now();
 INSERT INTO public.commerce_connections(actor_id,inventory_id,provider,external_account,region,marketplace,status,state_hash,state_expires_at)
 VALUES(p_actor,p_inventory,p_provider,p_account,p_region,p_marketplace,
 CASE WHEN p_provider='amazon_consumer' THEN 'connected' ELSE 'pending' END,p_state_hash,now()+interval '10 minutes') RETURNING * INTO c;
 RETURN to_jsonb(c);
END $$;

-- Every mutation takes the connection row lock. Claims serialize token rotation,
-- OAuth exchanges and syncs across workers; disconnect wins against late commits.
CREATE OR REPLACE FUNCTION public.findez_commerce_transition(p_actor uuid,p_connection uuid,p_action text,p_payload jsonb DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.commerce_connections; r jsonb; v_lease uuid;
BEGIN
 SELECT * INTO c FROM public.commerce_connections WHERE id=p_connection AND actor_id=p_actor FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'commerce_not_found' USING ERRCODE='P0002'; END IF;
 IF p_action='disconnect' THEN
  IF coalesce((p_payload->>'purge')::boolean,false) THEN
   DELETE FROM public.commerce_connections WHERE id=c.id;
  ELSE
   UPDATE public.commerce_connections SET status='disconnected',token_ciphertext=NULL,state_hash=NULL,
    state_expires_at=NULL,lease_id=NULL,lease_expires_at=NULL,updated_at=now() WHERE id=c.id;
  END IF;
  RETURN jsonb_build_object('status','disconnected','purged',coalesce((p_payload->>'purge')::boolean,false));
 END IF;
 IF coalesce(public.findez_inventory_role(c.inventory_id,p_actor),'') NOT IN ('owner','admin','editor') THEN
  RAISE EXCEPTION 'commerce_access_denied' USING ERRCODE='42501'; END IF;
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

-- Called only after verifying Shopify's raw-body signature and payload shop.
-- Do not store webhook bodies, customer names, email addresses or addresses.
CREATE OR REPLACE FUNCTION public.findez_commerce_shopify_event(p_shop text,p_topic text,p_event_hash text,
 p_triggered_at timestamptz,p_order_ids jsonb DEFAULT '[]',p_request_id text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.commerce_connections; oid text; inserted integer;
BEGIN
 IF p_topic NOT IN ('app/uninstalled','customers/data_request','customers/redact','shop/redact') THEN
  RAISE EXCEPTION 'commerce_unknown_topic'; END IF;
 -- Share the connection lock with sync commit. A privacy event that arrives
 -- during a provider fetch either redacts after commit or suppresses its rows.
 PERFORM 1 FROM public.commerce_connections WHERE provider='shopify' AND external_account=p_shop ORDER BY id FOR UPDATE;
 INSERT INTO public.commerce_webhook_receipts(event_hash,shop,topic) VALUES(p_event_hash,p_shop,p_topic) ON CONFLICT DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF inserted=0 THEN RETURN '{"duplicate":true}'::jsonb; END IF;
 IF p_topic='app/uninstalled' THEN
  UPDATE public.commerce_connections SET status='disconnected',token_ciphertext=NULL,state_hash=NULL,
   lease_id=NULL,lease_expires_at=NULL,updated_at=now()
   WHERE provider='shopify' AND external_account=p_shop AND created_at<=p_triggered_at;
 ELSIF p_topic='shop/redact' THEN
  DELETE FROM public.commerce_connections WHERE provider='shopify' AND external_account=p_shop AND status='disconnected';
  IF NOT EXISTS(SELECT FROM public.commerce_connections WHERE provider='shopify' AND external_account=p_shop) THEN
   DELETE FROM public.commerce_order_redactions WHERE shop=p_shop;
   DELETE FROM public.commerce_webhook_receipts WHERE shop=p_shop;
  END IF;
 ELSIF p_topic='customers/redact' THEN
  FOR oid IN SELECT value FROM jsonb_array_elements_text(p_order_ids) LOOP
   INSERT INTO public.commerce_order_redactions(shop,order_hash) VALUES(p_shop,encode(sha256(convert_to(oid,'UTF8')),'hex')) ON CONFLICT DO NOTHING;
  END LOOP;
  DELETE FROM public.commerce_source_records r USING public.commerce_connections target
   WHERE target.id=r.connection_id AND target.provider='shopify' AND target.external_account=p_shop AND p_order_ids ? (r.data->>'order_id');
  -- Old data exports must not retain a copy of redacted order lines.
  DELETE FROM public.commerce_privacy_exports e USING public.commerce_connections target
   WHERE target.id=e.connection_id AND target.provider='shopify' AND target.external_account=p_shop;
 ELSE
  FOR c IN SELECT * FROM public.commerce_connections WHERE provider='shopify' AND external_account=p_shop LOOP
   INSERT INTO public.commerce_privacy_exports(connection_id,request_id,records)
   SELECT c.id,p_request_id,coalesce(jsonb_agg(r.data),'[]'::jsonb) FROM public.commerce_source_records r
    WHERE r.connection_id=c.id AND p_order_ids ? (r.data->>'order_id')
   ON CONFLICT(connection_id,request_id) DO NOTHING;
  END LOOP;
 END IF;
 RETURN '{"received":true}'::jsonb;
END $$;
REVOKE ALL ON FUNCTION public.findez_commerce_shopify_event(text,text,text,timestamptz,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_commerce_shopify_event(text,text,text,timestamptz,jsonb,text) TO service_role;
COMMIT;

-- Optional read-only commerce cache. Never writes items, Spaces or physical stock.
BEGIN;
CREATE TABLE public.shopify_connections (
  connection_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
  shop_domain text NOT NULL UNIQUE CHECK (shop_domain ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.myshopify\.com$'),
  shop_gid text UNIQUE, shop_name text,
  generation uuid NOT NULL DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','connected','reconnect_required','disconnected','uninstalled')),
  granted_scopes text[] NOT NULL DEFAULT '{}',
  installed_at timestamptz, authorization_started_at timestamptz,
  pending_uninstall_gid text, pending_uninstall_at timestamptz,
  last_attempt_at timestamptz, last_success_at timestamptz,
  error_code text CHECK (error_code IN ('network','throttled','api_error','api_version','reconnect','worker_error','retry_exhausted')),
  sync_requested boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.shopify_credentials (
  connection_id uuid PRIMARY KEY REFERENCES public.shopify_connections ON DELETE CASCADE,
  encrypted_tokens text NOT NULL,
  access_expires_at timestamptz NOT NULL,
  refresh_expires_at timestamptz NOT NULL
);
CREATE TABLE public.shopify_oauth_states (
  state_hash text PRIMARY KEY,
  connection_id uuid NOT NULL REFERENCES public.shopify_connections ON DELETE CASCADE,
  generation uuid NOT NULL,
  actor_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  expires_at timestamptz NOT NULL DEFAULT now() + interval '10 minutes',
  consumed_at timestamptz
);
CREATE TABLE public.shopify_sync_jobs (
  job_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id uuid NOT NULL UNIQUE REFERENCES public.shopify_connections ON DELETE CASCADE,
  generation uuid NOT NULL,
  cursor jsonb NOT NULL DEFAULT '{"stage":"variants"}',
  attempts integer NOT NULL DEFAULT 0,
  lease_id uuid, lease_until timestamptz,
  available_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.shopify_variants (
  connection_id uuid NOT NULL REFERENCES public.shopify_connections ON DELETE CASCADE,
  variant_gid text NOT NULL, product_gid text NOT NULL,
  product_title text NOT NULL, variant_title text NOT NULL,
  product_status text NOT NULL, options jsonb NOT NULL,
  sku text, barcodes jsonb NOT NULL, image_url text,
  inventory_item_gid text NOT NULL, tracked boolean NOT NULL,
  source_updated_at timestamptz NOT NULL,
  synced_at timestamptz NOT NULL DEFAULT now(), seen_run uuid NOT NULL,
  deleted_at timestamptz,
  PRIMARY KEY (connection_id,variant_gid)
);
CREATE INDEX shopify_inventory_item_lookup ON public.shopify_variants(connection_id,inventory_item_gid);
CREATE TABLE public.shopify_inventory_levels (
  connection_id uuid NOT NULL REFERENCES public.shopify_connections ON DELETE CASCADE,
  inventory_item_gid text NOT NULL, location_gid text NOT NULL,
  location_name text NOT NULL, location_active boolean NOT NULL,
  quantities jsonb NOT NULL, source_updated_at timestamptz NOT NULL,
  synced_at timestamptz NOT NULL DEFAULT now(), seen_run uuid NOT NULL,
  PRIMARY KEY(connection_id,inventory_item_gid,location_gid)
);
CREATE TABLE public.shopify_webhook_receipts (
  delivery_id uuid PRIMARY KEY,
  connection_id uuid REFERENCES public.shopify_connections ON DELETE CASCADE,
  topic text NOT NULL, event_id text, received_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.shopify_audit (
  audit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  connection_id uuid NOT NULL REFERENCES public.shopify_connections ON DELETE CASCADE,
  actor_id uuid REFERENCES auth.users ON DELETE SET NULL,
  action text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);

-- App JWT reads only; API-key JWTs cannot inherit connected-store access.
CREATE FUNCTION public.shopify_member(p_connection uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'api_key_id','') = ''
    AND EXISTS(SELECT 1 FROM shopify_connections c JOIN team_memberships m USING(team_id)
      WHERE c.connection_id=p_connection AND m.user_id=auth.uid());
$$;
REVOKE ALL ON FUNCTION public.shopify_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shopify_member(uuid) TO authenticated, service_role;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['shopify_connections','shopify_credentials','shopify_oauth_states',
    'shopify_sync_jobs','shopify_variants','shopify_inventory_levels','shopify_webhook_receipts','shopify_audit'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
  END LOOP;
END $$;
GRANT USAGE, SELECT ON SEQUENCE public.shopify_audit_audit_id_seq TO service_role;
GRANT SELECT ON public.shopify_connections, public.shopify_variants, public.shopify_inventory_levels TO authenticated;
CREATE POLICY shopify_connection_read ON public.shopify_connections FOR SELECT TO authenticated USING (public.shopify_member(connection_id));
CREATE POLICY shopify_variant_read ON public.shopify_variants FOR SELECT TO authenticated USING (public.shopify_member(connection_id));
CREATE POLICY shopify_level_read ON public.shopify_inventory_levels FOR SELECT TO authenticated USING (public.shopify_member(connection_id));

-- Service-only atomic operations. Explicit actor checks complement backend auth.
CREATE FUNCTION public.shopify_begin_auth(p_team uuid,p_actor uuid,p_shop text,p_state_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
  IF NOT EXISTS(SELECT 1 FROM teams WHERE team_id=p_team AND owner_user_id=p_actor) THEN
    RAISE EXCEPTION 'owner required'; END IF;
  INSERT INTO shopify_connections(team_id,shop_domain) VALUES(p_team,p_shop)
    ON CONFLICT(shop_domain) DO NOTHING;
  SELECT * INTO c FROM shopify_connections WHERE shop_domain=p_shop FOR UPDATE;
  IF c.team_id<>p_team THEN RAISE EXCEPTION 'store already assigned'; END IF;
  IF EXISTS(SELECT 1 FROM shopify_sync_jobs WHERE connection_id=c.connection_id AND lease_until>now())
    OR (c.status='pending' AND EXISTS(SELECT 1 FROM shopify_oauth_states WHERE connection_id=c.connection_id AND consumed_at>now()-interval '120 seconds'))
    THEN RAISE EXCEPTION 'authorization busy'; END IF;
  UPDATE shopify_connections SET generation=gen_random_uuid(),status='pending',error_code=NULL,authorization_started_at=now(),
    pending_uninstall_gid=NULL,pending_uninstall_at=NULL,sync_requested=false WHERE connection_id=c.connection_id RETURNING * INTO c;
  DELETE FROM shopify_credentials WHERE connection_id=c.connection_id;
  DELETE FROM shopify_sync_jobs WHERE connection_id=c.connection_id;
  DELETE FROM shopify_oauth_states WHERE connection_id=c.connection_id;
  INSERT INTO shopify_oauth_states(state_hash,connection_id,generation,actor_id)
    VALUES(p_state_hash,c.connection_id,c.generation,p_actor);
  INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(c.connection_id,p_actor,'authorization_started');
  RETURN to_jsonb(c);
END $$;

CREATE FUNCTION public.shopify_consume_state(p_hash text,p_shop text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE s shopify_oauth_states; c shopify_connections; BEGIN
  -- All routines lock connection before dependent rows to avoid lock inversion.
  SELECT c0.* INTO c FROM shopify_connections c0 JOIN shopify_oauth_states s0 USING(connection_id)
    WHERE s0.state_hash=p_hash FOR UPDATE OF c0;
  SELECT * INTO s FROM shopify_oauth_states WHERE state_hash=p_hash FOR UPDATE;
  IF c.connection_id IS NULL OR s.consumed_at IS NOT NULL OR s.expires_at<=now()
    OR c.shop_domain<>p_shop OR c.generation<>s.generation OR c.status<>'pending'
    OR NOT EXISTS(SELECT 1 FROM teams WHERE team_id=c.team_id AND owner_user_id=s.actor_id)
    THEN RETURN NULL; END IF;
  UPDATE shopify_oauth_states SET consumed_at=now() WHERE state_hash=p_hash;
  RETURN jsonb_build_object('connection',to_jsonb(c),'actor_id',s.actor_id);
END $$;

CREATE FUNCTION public.shopify_finish_auth(p_connection uuid,p_generation uuid,p_actor uuid,
  p_gid text,p_name text,p_scopes text[],p_tokens text,p_access_expiry timestamptz,p_refresh_expiry timestamptz)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
  SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection FOR UPDATE;
  IF c.connection_id IS NULL OR c.generation<>p_generation OR c.status<>'pending'
    OR (c.shop_gid IS NOT NULL AND c.shop_gid<>p_gid)
    OR NOT EXISTS(SELECT 1 FROM teams WHERE team_id=c.team_id AND owner_user_id=p_actor)
    THEN RETURN false; END IF;
  IF c.pending_uninstall_gid=p_gid AND c.pending_uninstall_at>=c.authorization_started_at THEN
    UPDATE shopify_connections SET status='uninstalled',generation=gen_random_uuid() WHERE connection_id=p_connection;
    DELETE FROM shopify_oauth_states WHERE connection_id=p_connection;
    RETURN false;
  END IF;
  INSERT INTO shopify_credentials VALUES(p_connection,p_tokens,p_access_expiry,p_refresh_expiry);
  UPDATE shopify_connections SET status='connected',shop_gid=p_gid,shop_name=p_name,
    granted_scopes=p_scopes,installed_at=now(),sync_requested=true,error_code=NULL WHERE connection_id=p_connection;
  INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(p_connection,p_actor,'connected');
  RETURN true;
END $$;

CREATE FUNCTION public.shopify_disconnect(p_connection uuid,p_actor uuid DEFAULT NULL,p_status text DEFAULT 'disconnected')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
  SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection FOR UPDATE;
  IF c.connection_id IS NULL THEN RETURN false; END IF;
  IF p_actor IS NOT NULL AND NOT EXISTS(SELECT 1 FROM teams WHERE team_id=c.team_id AND owner_user_id=p_actor)
    THEN RAISE EXCEPTION 'owner required'; END IF;
  IF p_status NOT IN ('disconnected','uninstalled') THEN RAISE EXCEPTION 'invalid status'; END IF;
  UPDATE shopify_connections SET status=p_status,generation=gen_random_uuid(),sync_requested=false,
    granted_scopes='{}',error_code=NULL,last_attempt_at=NULL,last_success_at=NULL,shop_name=NULL
    WHERE connection_id=p_connection;
  DELETE FROM shopify_credentials WHERE connection_id=p_connection;
  DELETE FROM shopify_sync_jobs WHERE connection_id=p_connection;
  DELETE FROM shopify_oauth_states WHERE connection_id=p_connection;
  DELETE FROM shopify_variants WHERE connection_id=p_connection;
  DELETE FROM shopify_inventory_levels WHERE connection_id=p_connection;
  INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(p_connection,p_actor,p_status);
  RETURN true;
END $$;

CREATE FUNCTION public.shopify_receive_webhook(p_delivery uuid,p_event text,p_shop text,p_topic text,p_triggered timestamptz,p_shop_gid text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; inserted integer; BEGIN
  SELECT * INTO c FROM shopify_connections WHERE shop_domain=p_shop FOR UPDATE;
  -- Unknown stores are not installed in FindEZ and contain no stored customer data.
  IF c.connection_id IS NULL THEN RETURN false; END IF;
  INSERT INTO shopify_webhook_receipts(delivery_id,connection_id,topic,event_id)
    VALUES(p_delivery,c.connection_id,p_topic,p_event) ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS inserted=ROW_COUNT;
  IF inserted=0 THEN RETURN false; END IF;
  IF p_topic='shop/redact' THEN
    IF p_shop_gid IS NULL OR (c.shop_gid IS NOT NULL AND c.shop_gid<>p_shop_gid) THEN RETURN false; END IF;
    PERFORM shopify_disconnect(c.connection_id,NULL,'uninstalled');
    DELETE FROM shopify_audit WHERE connection_id=c.connection_id;
    DELETE FROM shopify_webhook_receipts WHERE connection_id=c.connection_id;
    DELETE FROM shopify_connections WHERE connection_id=c.connection_id;
  ELSIF p_topic='app/uninstalled' THEN
    IF p_shop_gid IS NULL THEN RETURN false; END IF;
    IF c.status='pending' AND c.shop_gid IS NULL AND p_triggered>=c.authorization_started_at THEN
      -- Initial authorization has not verified Shop identity yet. Keep only its
      -- signed ID/time; finish_auth rejects a matching uninstall, not other shops.
      UPDATE shopify_connections SET pending_uninstall_gid=p_shop_gid,pending_uninstall_at=p_triggered
        WHERE connection_id=c.connection_id;
    ELSIF c.shop_gid=p_shop_gid AND c.status IN ('connected','pending','reconnect_required') AND
      p_triggered>=(CASE WHEN c.status='pending' THEN c.authorization_started_at ELSE c.installed_at END) THEN
      PERFORM shopify_disconnect(c.connection_id,NULL,'uninstalled'); END IF;
  ELSIF p_topic NOT IN ('customers/data_request','customers/redact') AND c.status='connected'
    AND p_triggered>=c.installed_at THEN
    UPDATE shopify_connections SET sync_requested=true WHERE connection_id=c.connection_id;
  END IF;
  RETURN true;
END $$;

CREATE FUNCTION public.shopify_claim_job() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; j shopify_sync_jobs; fresh boolean; BEGIN
  DELETE FROM shopify_oauth_states WHERE expires_at<now();
  DELETE FROM shopify_webhook_receipts WHERE received_at<now()-interval '30 days';
  DELETE FROM shopify_audit WHERE created_at<now()-interval '30 days';
  SELECT c0.* INTO c FROM shopify_connections c0 LEFT JOIN shopify_sync_jobs j0 USING(connection_id)
    WHERE c0.status='connected' AND (
      (j0.job_id IS NOT NULL AND j0.available_at<=now() AND (j0.lease_until IS NULL OR j0.lease_until<now()))
      OR (j0.job_id IS NULL AND (c0.sync_requested OR c0.last_success_at IS NULL
        OR c0.last_success_at<now()-interval '15 minutes')))
    ORDER BY c0.last_attempt_at NULLS FIRST FOR UPDATE OF c0 SKIP LOCKED LIMIT 1;
  IF c.connection_id IS NULL THEN RETURN NULL; END IF;
  INSERT INTO shopify_sync_jobs(connection_id,generation) VALUES(c.connection_id,c.generation)
    ON CONFLICT(connection_id) DO NOTHING;
  fresh := FOUND;
  UPDATE shopify_sync_jobs SET lease_id=gen_random_uuid(),lease_until=now()+interval '120 seconds'
    WHERE connection_id=c.connection_id RETURNING * INTO j;
  UPDATE shopify_connections SET last_attempt_at=now(),
    sync_requested=CASE WHEN fresh THEN false ELSE sync_requested END WHERE connection_id=c.connection_id;
  RETURN jsonb_build_object('connection',to_jsonb(c),'job',to_jsonb(j));
END $$;

CREATE FUNCTION public.shopify_save_tokens(p_connection uuid,p_generation uuid,p_lease uuid,
  p_tokens text,p_access_expiry timestamptz,p_refresh_expiry timestamptz) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  PERFORM 1 FROM shopify_connections WHERE connection_id=p_connection AND generation=p_generation AND status='connected' FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM shopify_sync_jobs WHERE connection_id=p_connection
    AND lease_id=p_lease AND lease_until>now()) THEN RETURN false; END IF;
  UPDATE shopify_credentials SET encrypted_tokens=p_tokens,access_expires_at=p_access_expiry,
    refresh_expires_at=p_refresh_expiry WHERE connection_id=p_connection;
  RETURN FOUND;
END $$;

CREATE FUNCTION public.shopify_commit_page(p_connection uuid,p_generation uuid,p_lease uuid,
  p_variants jsonb,p_levels jsonb,p_cursor jsonb,p_complete boolean DEFAULT false,p_delay integer DEFAULT 0)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE j shopify_sync_jobs; BEGIN
  PERFORM 1 FROM shopify_connections WHERE connection_id=p_connection AND generation=p_generation AND status='connected' FOR UPDATE;
  SELECT * INTO j FROM shopify_sync_jobs WHERE connection_id=p_connection;
  IF NOT FOUND OR j.generation<>p_generation OR j.lease_id IS DISTINCT FROM p_lease OR j.lease_until<=now()
    OR NOT EXISTS(SELECT 1 FROM shopify_connections WHERE connection_id=p_connection AND generation=p_generation AND status='connected')
    THEN RETURN false; END IF;
  INSERT INTO shopify_variants(connection_id,variant_gid,product_gid,product_title,variant_title,product_status,
    options,sku,barcodes,image_url,inventory_item_gid,tracked,source_updated_at,seen_run)
    SELECT p_connection,x.variant_gid,x.product_gid,x.product_title,x.variant_title,x.product_status,
      x.options,x.sku,x.barcodes,x.image_url,x.inventory_item_gid,x.tracked,x.source_updated_at,j.job_id
      FROM jsonb_to_recordset(p_variants) AS x(variant_gid text,product_gid text,product_title text,
        variant_title text,product_status text,options jsonb,sku text,barcodes jsonb,image_url text,
        inventory_item_gid text,tracked boolean,source_updated_at timestamptz)
    ON CONFLICT(connection_id,variant_gid) DO UPDATE SET product_gid=excluded.product_gid,
      product_title=excluded.product_title,variant_title=excluded.variant_title,product_status=excluded.product_status,
      options=excluded.options,sku=excluded.sku,barcodes=excluded.barcodes,image_url=excluded.image_url,
      inventory_item_gid=excluded.inventory_item_gid,tracked=excluded.tracked,
      source_updated_at=excluded.source_updated_at,synced_at=now(),seen_run=excluded.seen_run,deleted_at=NULL;
  INSERT INTO shopify_inventory_levels(connection_id,inventory_item_gid,location_gid,location_name,location_active,
    quantities,source_updated_at,seen_run)
    SELECT p_connection,x.inventory_item_gid,x.location_gid,x.location_name,x.location_active,x.quantities,
      x.source_updated_at,j.job_id FROM jsonb_to_recordset(p_levels) AS x(inventory_item_gid text,
        location_gid text,location_name text,location_active boolean,quantities jsonb,source_updated_at timestamptz)
    ON CONFLICT(connection_id,inventory_item_gid,location_gid) DO UPDATE SET location_name=excluded.location_name,
      location_active=excluded.location_active,quantities=excluded.quantities,source_updated_at=excluded.source_updated_at,
      synced_at=now(),seen_run=excluded.seen_run;
  IF p_complete THEN
    UPDATE shopify_variants SET deleted_at=coalesce(deleted_at,now()) WHERE connection_id=p_connection AND seen_run<>j.job_id;
    DELETE FROM shopify_inventory_levels WHERE connection_id=p_connection AND seen_run<>j.job_id;
    UPDATE shopify_connections SET last_success_at=now(),error_code=NULL WHERE connection_id=p_connection;
    DELETE FROM shopify_sync_jobs WHERE connection_id=p_connection;
    INSERT INTO shopify_audit(connection_id,action) VALUES(p_connection,'sync_completed');
  ELSE
    UPDATE shopify_sync_jobs SET cursor=p_cursor,attempts=0,lease_id=NULL,lease_until=NULL,
      available_at=now()+make_interval(secs=>least(greatest(p_delay,0),60)) WHERE connection_id=p_connection;
    UPDATE shopify_connections SET error_code=NULL WHERE connection_id=p_connection;
  END IF;
  RETURN true;
END $$;

CREATE FUNCTION public.shopify_fail_job(p_connection uuid,p_generation uuid,p_lease uuid,p_error text,p_delay integer)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE j shopify_sync_jobs; BEGIN
  PERFORM 1 FROM shopify_connections WHERE connection_id=p_connection AND generation=p_generation AND status='connected' FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  SELECT * INTO j FROM shopify_sync_jobs WHERE connection_id=p_connection;
  IF NOT FOUND OR j.lease_id IS DISTINCT FROM p_lease OR j.lease_until<=now() THEN RETURN false; END IF;
  UPDATE shopify_connections SET error_code=CASE WHEN j.attempts>=7 THEN 'retry_exhausted' ELSE p_error END,
    status=CASE WHEN p_error='reconnect' THEN 'reconnect_required' ELSE status END WHERE connection_id=p_connection;
  UPDATE shopify_sync_jobs SET attempts=attempts+1,lease_id=NULL,lease_until=NULL,
    available_at=CASE WHEN j.attempts>=7 OR p_error='reconnect' THEN 'infinity'::timestamptz
      ELSE now()+make_interval(secs=>least(greatest(p_delay,1),3600)) END WHERE connection_id=p_connection;
  RETURN true;
END $$;

CREATE FUNCTION public.shopify_request_sync(p_connection uuid,p_actor uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
  SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection FOR UPDATE;
  IF c.status<>'connected' OR NOT EXISTS(SELECT 1 FROM teams WHERE team_id=c.team_id AND owner_user_id=p_actor)
    THEN RETURN false; END IF;
  UPDATE shopify_connections SET sync_requested=true WHERE connection_id=p_connection;
  -- Exhaustion may mean a catalog record vanished during pagination. Restart
  -- that failed run; normal transient retries retain the committed cursor.
  UPDATE shopify_sync_jobs SET attempts=0,available_at=now(),job_id=gen_random_uuid(),cursor='{"stage":"variants"}'
    WHERE connection_id=p_connection AND available_at='infinity'::timestamptz;
  INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(p_connection,p_actor,'sync_requested');
  RETURN true;
END $$;

DO $$ DECLARE f record; BEGIN
  FOR f IN SELECT oid::regprocedure AS signature FROM pg_proc WHERE pronamespace='public'::regnamespace
    AND proname LIKE 'shopify_%' AND proname<>'shopify_member' LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated',f.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.signature);
  END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

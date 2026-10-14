-- Owner-selected edits are distinct from actual Shopify grants and Team roles.
BEGIN;
ALTER TABLE public.shopify_connections
 ADD COLUMN edit_products boolean NOT NULL DEFAULT false,
 ADD COLUMN edit_inventory boolean NOT NULL DEFAULT false,
 ADD COLUMN edit_access text NOT NULL DEFAULT 'owner' CHECK(edit_access IN ('owner','editors')),
 ADD COLUMN permission_revision integer NOT NULL DEFAULT 0,
 ADD COLUMN io_lease uuid,
 ADD COLUMN io_until timestamptz;
ALTER TABLE public.shopify_oauth_states
 ADD COLUMN requested_scopes text[] NOT NULL DEFAULT ARRAY['read_products','read_inventory'],
 ADD COLUMN permission_revision integer NOT NULL DEFAULT 0;
CREATE TABLE public.shopify_operations (
 operation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 connection_id uuid NOT NULL REFERENCES public.shopify_connections ON DELETE CASCADE,
 actor_id uuid REFERENCES auth.users ON DELETE SET NULL,
 generation uuid NOT NULL,
 permission_revision integer NOT NULL,
 kind text NOT NULL CHECK(kind IN ('product','inventory')),
 intent jsonb NOT NULL,
 snapshot jsonb NOT NULL,
 state text NOT NULL DEFAULT 'prepared' CHECK(state IN ('prepared','sending','succeeded','failed','unknown')),
 receipt jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT now()+interval '10 minutes',
 dispatched_at timestamptz,
 completed_at timestamptz,
 reviewed_at timestamptz,
 reviewed_by uuid REFERENCES auth.users ON DELETE SET NULL
);
ALTER TABLE public.shopify_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.shopify_operations FROM anon,authenticated;
GRANT ALL ON public.shopify_operations TO service_role;
REVOKE SELECT ON public.shopify_connections FROM authenticated;
GRANT SELECT(connection_id,team_id,shop_domain,shop_name,status,granted_scopes,
 installed_at,last_attempt_at,last_success_at,error_code,created_at,
 edit_products,edit_inventory,edit_access,permission_revision) ON public.shopify_connections TO authenticated;

CREATE FUNCTION public.shopify_immutable_intent() RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 IF (NEW.connection_id,NEW.generation,NEW.permission_revision,NEW.kind,NEW.intent,NEW.snapshot,NEW.created_at,NEW.expires_at)
 IS DISTINCT FROM (OLD.connection_id,OLD.generation,OLD.permission_revision,OLD.kind,OLD.intent,OLD.snapshot,OLD.created_at,OLD.expires_at)
 OR (NEW.actor_id IS NOT NULL AND NEW.actor_id IS DISTINCT FROM OLD.actor_id) THEN RAISE EXCEPTION 'immutable reviewed intent'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER shopify_immutable_intent BEFORE UPDATE ON public.shopify_operations FOR EACH ROW EXECUTE FUNCTION public.shopify_immutable_intent();

CREATE FUNCTION public.shopify_can_edit(p_connection uuid,p_actor uuid,p_kind text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM shopify_connections c JOIN teams t USING(team_id)
 JOIN team_memberships m ON m.team_id=c.team_id AND m.user_id=p_actor
 WHERE c.connection_id=p_connection AND c.status='connected'
 AND ((p_kind='product' AND c.edit_products AND 'write_products'=ANY(c.granted_scopes))
   OR (p_kind='inventory' AND c.edit_inventory AND 'write_inventory'=ANY(c.granted_scopes)))
 AND (t.owner_user_id=p_actor OR (c.edit_access='editors' AND m.role IN ('mentor','member'))));
$$;

CREATE FUNCTION public.shopify_permissions(p_team uuid,p_connection uuid,p_actor uuid,
 p_products boolean,p_inventory boolean,p_access text,p_revision integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection AND team_id=p_team FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM teams WHERE team_id=p_team AND owner_user_id=p_actor)
 THEN RETURN jsonb_build_object('error','permission'); END IF;
 IF c.permission_revision<>p_revision THEN RETURN jsonb_build_object('error','revision'); END IF;
 IF p_access NOT IN ('owner','editors') OR p_products IS NULL OR p_inventory IS NULL THEN
 RETURN jsonb_build_object('error','invalid'); END IF;
 UPDATE shopify_connections SET edit_products=p_products,edit_inventory=p_inventory,edit_access=p_access,
 permission_revision=permission_revision+1 WHERE connection_id=p_connection RETURNING * INTO c;
 INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(p_connection,p_actor,'permissions_changed');
 RETURN jsonb_build_object('revision',c.permission_revision);
END $$;

-- IO leases serialize refresh, reviewed mutations, reconnection and worker pages.
CREATE FUNCTION public.shopify_claim_io(p_team uuid,p_connection uuid,p_actor uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection AND team_id=p_team FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM team_memberships WHERE team_id=p_team AND user_id=p_actor)
 THEN RETURN jsonb_build_object('error','permission'); END IF;
 IF c.status<>'connected' THEN RETURN jsonb_build_object('error','reconnect'); END IF;
 IF c.io_until>now() OR EXISTS(SELECT 1 FROM shopify_sync_jobs WHERE connection_id=p_connection AND lease_until>now())
 THEN RETURN jsonb_build_object('error','busy'); END IF;
 UPDATE shopify_connections SET io_lease=gen_random_uuid(),io_until=now()+interval '120 seconds'
 WHERE connection_id=p_connection RETURNING * INTO c;
 RETURN to_jsonb(c);
END $$;
CREATE FUNCTION public.shopify_release_io(p_connection uuid,p_lease uuid) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $$
 UPDATE shopify_connections SET io_lease=NULL,io_until=NULL WHERE connection_id=p_connection AND io_lease=p_lease;
$$;
CREATE FUNCTION public.shopify_io_tokens(p_connection uuid,p_generation uuid,p_lease uuid,
 p_tokens text,p_access_expiry timestamptz,p_refresh_expiry timestamptz,p_scopes text[]) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM 1 FROM shopify_connections WHERE connection_id=p_connection AND generation=p_generation
 AND status='connected' AND io_lease=p_lease AND io_until>now() FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 UPDATE shopify_credentials SET encrypted_tokens=p_tokens,access_expires_at=p_access_expiry,
 refresh_expires_at=p_refresh_expiry WHERE connection_id=p_connection;
 UPDATE shopify_connections SET granted_scopes=p_scopes WHERE connection_id=p_connection;
 RETURN true;
END $$;
CREATE FUNCTION public.shopify_io_scopes(p_connection uuid,p_generation uuid,p_lease uuid,p_scopes text[]) RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $$
 WITH saved AS (UPDATE shopify_connections SET granted_scopes=p_scopes
 WHERE connection_id=p_connection AND generation=p_generation AND status='connected'
 AND io_lease=p_lease AND io_until>now() RETURNING 1) SELECT EXISTS(SELECT 1 FROM saved);
$$;

CREATE FUNCTION public.shopify_prepare_edit(p_connection uuid,p_actor uuid,p_lease uuid,
 p_kind text,p_intent jsonb,p_snapshot jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; o shopify_operations; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection FOR UPDATE;
 IF c.io_lease IS DISTINCT FROM p_lease OR c.io_until<=now() OR NOT shopify_can_edit(p_connection,p_actor,p_kind)
 THEN RETURN jsonb_build_object('error','permission'); END IF;
 IF EXISTS(SELECT 1 FROM shopify_operations WHERE connection_id=p_connection AND reviewed_at IS NULL
 AND (state='unknown' OR (state='sending' AND dispatched_at<now()-interval '120 seconds')))
 THEN RETURN jsonb_build_object('error','outcome_unknown'); END IF;
 INSERT INTO shopify_operations(connection_id,actor_id,generation,permission_revision,kind,intent,snapshot)
 VALUES(p_connection,p_actor,c.generation,c.permission_revision,p_kind,p_intent,p_snapshot) RETURNING * INTO o;
 INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(p_connection,p_actor,'edit_prepared');
 RETURN to_jsonb(o);
END $$;
CREATE FUNCTION public.shopify_dispatch_edit(p_connection uuid,p_actor uuid,p_lease uuid,p_operation uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; o shopify_operations; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection FOR UPDATE;
 SELECT * INTO o FROM shopify_operations WHERE connection_id=p_connection AND operation_id=p_operation FOR UPDATE;
 IF o.operation_id IS NULL OR o.actor_id IS DISTINCT FROM p_actor OR o.generation<>c.generation
 OR o.permission_revision<>c.permission_revision OR NOT shopify_can_edit(p_connection,p_actor,o.kind)
 OR c.io_lease IS DISTINCT FROM p_lease OR c.io_until<=now()
 THEN RETURN jsonb_build_object('error','permission'); END IF;
 IF o.state='succeeded' THEN RETURN to_jsonb(o); END IF;
 IF o.state<>'prepared' THEN RETURN jsonb_build_object('error','outcome_unknown'); END IF;
 IF EXISTS(SELECT 1 FROM shopify_operations WHERE connection_id=p_connection AND operation_id<>p_operation AND reviewed_at IS NULL
 AND (state='unknown' OR (state='sending' AND dispatched_at<now()-interval '120 seconds')))
 THEN RETURN jsonb_build_object('error','outcome_unknown'); END IF;
 IF o.expires_at<=now() THEN RETURN jsonb_build_object('error','expired'); END IF;
 UPDATE shopify_operations SET state='sending',dispatched_at=now() WHERE operation_id=p_operation RETURNING * INTO o;
 INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(p_connection,p_actor,'edit_dispatched');
 RETURN to_jsonb(o);
END $$;

CREATE FUNCTION public.shopify_review_unknown(p_team uuid,p_connection uuid,p_actor uuid,p_operation uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection AND team_id=p_team FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM teams WHERE team_id=p_team AND owner_user_id=p_actor) OR c.io_until>now() THEN RETURN false; END IF;
 UPDATE shopify_operations SET reviewed_at=now(),reviewed_by=p_actor,state='unknown'
 WHERE connection_id=p_connection AND operation_id=p_operation AND reviewed_at IS NULL
 AND (state='unknown' OR (state='sending' AND dispatched_at<now()-interval '120 seconds'));
 IF NOT FOUND THEN RETURN false; END IF;
 INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(p_connection,p_actor,'unknown_outcome_reviewed');
 RETURN true;
END $$;
CREATE FUNCTION public.shopify_finish_edit(p_connection uuid,p_lease uuid,p_operation uuid,p_state text,p_receipt jsonb)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; o shopify_operations; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection FOR UPDATE;
 IF c.io_lease IS DISTINCT FROM p_lease OR c.io_until<=now() OR p_state NOT IN ('succeeded','failed','unknown')
 THEN RETURN false; END IF;
 UPDATE shopify_operations SET state=p_state,receipt=p_receipt,completed_at=now()
 WHERE operation_id=p_operation AND connection_id=p_connection AND state='sending' RETURNING * INTO o;
 IF NOT FOUND THEN RETURN false; END IF;
 UPDATE shopify_connections SET sync_requested=true WHERE connection_id=p_connection;
 INSERT INTO shopify_audit(connection_id,actor_id,action) VALUES(p_connection,o.actor_id,'edit_'||p_state);
 RETURN true;
END $$;

ALTER FUNCTION public.shopify_begin_auth(uuid,uuid,text,text) RENAME TO shopify_begin_auth_v1;
CREATE FUNCTION public.shopify_begin_auth(p_team uuid,p_actor uuid,p_shop text,p_state_hash text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; result jsonb; desired text[]:=ARRAY['read_products','read_inventory']; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE shop_domain=p_shop FOR UPDATE;
 IF c.io_until>now() THEN RAISE EXCEPTION 'store busy'; END IF;
 result:=shopify_begin_auth_v1(p_team,p_actor,p_shop,p_state_hash);
 SELECT * INTO c FROM shopify_connections WHERE connection_id=(result->>'connection_id')::uuid;
 IF c.edit_products THEN desired:=array_append(desired,'write_products'); END IF;
 IF c.edit_inventory THEN desired:=array_append(desired,'write_inventory'); END IF;
 UPDATE shopify_oauth_states SET requested_scopes=desired,permission_revision=c.permission_revision WHERE state_hash=p_state_hash;
 RETURN result||jsonb_build_object('requested_scopes',desired);
END $$;
ALTER FUNCTION public.shopify_consume_state(text,text) RENAME TO shopify_consume_state_v1;
CREATE FUNCTION public.shopify_consume_state(p_hash text,p_shop text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE result jsonb; s shopify_oauth_states; c shopify_connections; BEGIN
 result:=shopify_consume_state_v1(p_hash,p_shop);
 IF result IS NULL THEN RETURN NULL; END IF;
 SELECT * INTO s FROM shopify_oauth_states WHERE state_hash=p_hash;
 SELECT * INTO c FROM shopify_connections WHERE connection_id=s.connection_id;
 IF s.permission_revision<>c.permission_revision THEN RETURN NULL; END IF;
 RETURN result||jsonb_build_object('requested_scopes',s.requested_scopes);
END $$;
ALTER FUNCTION public.shopify_finish_auth(uuid,uuid,uuid,text,text,text[],text,timestamptz,timestamptz) RENAME TO shopify_finish_auth_v1;
CREATE FUNCTION public.shopify_finish_auth(p_connection uuid,p_generation uuid,p_actor uuid,
 p_gid text,p_name text,p_scopes text[],p_tokens text,p_access_expiry timestamptz,p_refresh_expiry timestamptz) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM shopify_oauth_states WHERE connection_id=p_connection AND generation=p_generation
 AND consumed_at IS NOT NULL AND permission_revision=c.permission_revision) THEN RETURN false; END IF;
 RETURN shopify_finish_auth_v1(p_connection,p_generation,p_actor,p_gid,p_name,p_scopes,p_tokens,p_access_expiry,p_refresh_expiry);
END $$;
ALTER FUNCTION public.shopify_disconnect(uuid,uuid,text) RENAME TO shopify_disconnect_v1;
CREATE FUNCTION public.shopify_disconnect(p_connection uuid,p_actor uuid DEFAULT NULL,p_status text DEFAULT 'disconnected') RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; BEGIN
 SELECT * INTO c FROM shopify_connections WHERE connection_id=p_connection FOR UPDATE;
 IF p_actor IS NOT NULL AND c.io_until>now() THEN RETURN false; END IF;
 RETURN shopify_disconnect_v1(p_connection,p_actor,p_status);
END $$;

CREATE OR REPLACE FUNCTION public.shopify_claim_job() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c shopify_connections; j shopify_sync_jobs; fresh boolean; BEGIN
 DELETE FROM shopify_oauth_states WHERE expires_at<now();
 DELETE FROM shopify_webhook_receipts WHERE received_at<now()-interval '30 days';
 DELETE FROM shopify_audit WHERE created_at<now()-interval '30 days';
 SELECT c0.* INTO c FROM shopify_connections c0 LEFT JOIN shopify_sync_jobs j0 USING(connection_id)
 WHERE c0.status='connected' AND (c0.io_until IS NULL OR c0.io_until<now()) AND (
 (j0.job_id IS NOT NULL AND j0.available_at<=now() AND (j0.lease_until IS NULL OR j0.lease_until<now()))
 OR (j0.job_id IS NULL AND (c0.sync_requested OR c0.last_success_at IS NULL OR c0.last_success_at<now()-interval '15 minutes')))
 ORDER BY c0.last_attempt_at NULLS FIRST FOR UPDATE OF c0 SKIP LOCKED LIMIT 1;
 IF c.connection_id IS NULL THEN RETURN NULL; END IF;
 INSERT INTO shopify_sync_jobs(connection_id,generation) VALUES(c.connection_id,c.generation) ON CONFLICT(connection_id) DO NOTHING;
 fresh:=FOUND;
 UPDATE shopify_sync_jobs SET lease_id=gen_random_uuid(),lease_until=now()+interval '120 seconds' WHERE connection_id=c.connection_id RETURNING * INTO j;
 UPDATE shopify_connections SET last_attempt_at=now(),sync_requested=CASE WHEN fresh THEN false ELSE sync_requested END WHERE connection_id=c.connection_id;
 RETURN jsonb_build_object('connection',to_jsonb(c),'job',to_jsonb(j));
END $$;

DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT oid::regprocedure AS signature FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE 'shopify_%' LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.signature);
 END LOOP;
END $$;
-- Member RLS helper is the sole client-executable function in this namespace.
GRANT EXECUTE ON FUNCTION public.shopify_member(uuid) TO authenticated;
COMMIT;

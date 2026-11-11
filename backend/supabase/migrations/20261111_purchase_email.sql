-- Additive private mail intake. No existing inventory or commerce function changes.
BEGIN;
CREATE TABLE IF NOT EXISTS public.commerce_gmail_accounts (
 connection_id uuid PRIMARY KEY REFERENCES public.commerce_connections(id) ON DELETE CASCADE,
 status text NOT NULL CHECK(status IN ('pending','authorizing','connected','error','disconnected')),
 email text, token_ciphertext text, verifier_ciphertext text, state_hash text, state_expires_at timestamptz,
 lease uuid, lease_until timestamptz, cursor jsonb NOT NULL DEFAULT '{}',
 next_poll_at timestamptz NOT NULL DEFAULT now(), last_sync_at timestamptz, last_error text
);
CREATE TABLE IF NOT EXISTS public.commerce_purchase_emails (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 connection_id uuid NOT NULL REFERENCES public.commerce_gmail_accounts(connection_id) ON DELETE CASCADE,
 email_id text NOT NULL CHECK(email_id ~ '^[a-zA-Z0-9_-]{1,100}$'),
 body_ciphertext text CHECK(body_ciphertext IS NULL OR length(body_ciphertext)<=500000),
 status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','processing','ready','ignored','failed')),
 attempts integer NOT NULL DEFAULT 0,
 lease uuid, lease_until timestamptz, retry_at timestamptz NOT NULL DEFAULT now(),
 content_hash text, result jsonb,
 received_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(connection_id,email_id),
 CHECK(result IS NULL OR (jsonb_typeof(result)='object' AND jsonb_typeof(result->'lines')='array'
  AND jsonb_array_length(result->'lines')<=100 AND octet_length(result::text)<=250000))
);
CREATE UNIQUE INDEX IF NOT EXISTS commerce_email_content ON public.commerce_purchase_emails(connection_id,content_hash)
 WHERE content_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS commerce_email_queue ON public.commerce_purchase_emails(retry_at,received_at)
 WHERE status IN ('queued','processing');
CREATE INDEX IF NOT EXISTS commerce_email_history ON public.commerce_purchase_emails(connection_id,received_at DESC);
ALTER TABLE public.commerce_gmail_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerce_purchase_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.commerce_gmail_accounts,public.commerce_purchase_emails FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.commerce_gmail_accounts,public.commerce_purchase_emails TO service_role;

-- Server-only calls; every actor operation binds the JWT actor and inventory.
CREATE OR REPLACE FUNCTION public.findez_gmail_manage(p_actor uuid,p_inventory uuid,p_action text,p_payload jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c commerce_connections; g commerce_gmail_accounts;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor::text||':'||p_inventory::text,0));
 SELECT * INTO c FROM commerce_connections WHERE actor_id=p_actor AND inventory_id=p_inventory
  AND provider='amazon_consumer' AND status='connected' FOR UPDATE;
 IF p_action NOT IN ('disconnect','purge') AND coalesce(findez_inventory_role(p_inventory,p_actor),'') NOT IN ('owner','admin','editor') THEN
  RAISE EXCEPTION 'gmail_access_denied' USING ERRCODE='42501'; END IF;
 IF c.id IS NULL THEN
  IF p_action IN ('disconnect','purge') THEN RETURN '{}'::jsonb; END IF;
  IF p_action<>'start' THEN RAISE EXCEPTION 'gmail_not_found' USING ERRCODE='P0002'; END IF;
  INSERT INTO commerce_connections(actor_id,inventory_id,provider,external_account,status)
   VALUES(p_actor,p_inventory,'amazon_consumer',encode(sha256(convert_to(p_actor::text||':'||p_inventory::text,'UTF8')),'hex'),'connected') RETURNING * INTO c;
 END IF;
 SELECT * INTO g FROM commerce_gmail_accounts WHERE connection_id=c.id FOR UPDATE;
 IF p_action='start' THEN
  IF g.status IN ('connected','authorizing') THEN RAISE EXCEPTION 'gmail_already_connected' USING ERRCODE='40001'; END IF;
  INSERT INTO commerce_gmail_accounts(connection_id,status,state_hash,state_expires_at,verifier_ciphertext)
   VALUES(c.id,'pending',p_payload->>'state_hash',now()+interval '10 minutes',p_payload->>'verifier_ciphertext')
   ON CONFLICT(connection_id) DO UPDATE SET status='pending',state_hash=excluded.state_hash,
    state_expires_at=excluded.state_expires_at,verifier_ciphertext=excluded.verifier_ciphertext,lease=NULL,lease_until=NULL;
 ELSIF p_action='claim' THEN
  IF g.status<>'pending' OR g.state_hash IS NULL OR g.state_hash IS DISTINCT FROM p_payload->>'state_hash'
   OR g.state_expires_at<=now() OR c.id IS DISTINCT FROM (p_payload->>'connection_id')::uuid THEN
   RAISE EXCEPTION 'gmail_invalid_state' USING ERRCODE='40001'; END IF;
  UPDATE commerce_gmail_accounts SET status='authorizing',state_hash=NULL,lease=gen_random_uuid(),lease_until=now()+interval '3 minutes' WHERE connection_id=c.id;
 ELSIF p_action='finish' THEN
  IF g.email IS NOT NULL AND g.email IS DISTINCT FROM p_payload->>'email' AND EXISTS(SELECT FROM commerce_purchase_emails WHERE connection_id=c.id) THEN
   RAISE EXCEPTION 'Delete previous Gmail purchase records before switching mailboxes.' USING ERRCODE='40001'; END IF;
  IF g.status<>'authorizing' OR g.lease IS NULL OR g.lease IS DISTINCT FROM (p_payload->>'lease')::uuid OR g.lease_until<=now() THEN
   RAISE EXCEPTION 'gmail_stale_auth' USING ERRCODE='40001'; END IF;
  UPDATE commerce_gmail_accounts SET status='connected',email=p_payload->>'email',token_ciphertext=p_payload->>'token_ciphertext',
   verifier_ciphertext=NULL,state_hash=NULL,state_expires_at=NULL,lease=NULL,lease_until=NULL,cursor='{}',next_poll_at=now(),last_error=NULL WHERE connection_id=c.id;
 ELSIF p_action IN ('disconnect','purge') THEN
  -- Stop locally first, even if Google's revocation endpoint is unavailable.
  UPDATE commerce_gmail_accounts SET status='disconnected',token_ciphertext=NULL,verifier_ciphertext=NULL,
   state_hash=NULL,state_expires_at=NULL,lease=NULL,lease_until=NULL WHERE connection_id=c.id;
  UPDATE commerce_purchase_emails SET status='ignored',lease=NULL,lease_until=NULL,body_ciphertext=NULL
   WHERE connection_id=c.id AND status IN ('queued','processing');
  IF p_action='purge' THEN
   DELETE FROM commerce_purchase_emails WHERE connection_id=c.id;
   UPDATE commerce_gmail_accounts SET email=NULL,last_sync_at=NULL,last_error=NULL,cursor='{}' WHERE connection_id=c.id;
  END IF;
  RETURN jsonb_build_object('token_ciphertext',g.token_ciphertext,'connection_id',c.id);
 ELSE RAISE EXCEPTION 'invalid_gmail_action'; END IF;
 SELECT * INTO g FROM commerce_gmail_accounts WHERE connection_id=c.id;
 RETURN to_jsonb(g);
END $$;

CREATE OR REPLACE FUNCTION public.findez_gmail_job(p_action text,p_payload jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c commerce_connections; g commerce_gmail_accounts; candidate record; r jsonb;
BEGIN
 IF p_action='claim' THEN
  FOR candidate IN SELECT connection_id FROM commerce_gmail_accounts WHERE status='connected'
   AND next_poll_at<=now() AND (lease_until IS NULL OR lease_until<=now()) ORDER BY next_poll_at LIMIT 100
  LOOP
   SELECT * INTO c FROM commerce_connections WHERE id=candidate.connection_id FOR UPDATE SKIP LOCKED;
   IF NOT FOUND THEN CONTINUE; END IF;
   SELECT * INTO g FROM commerce_gmail_accounts WHERE connection_id=c.id FOR UPDATE;
   IF g.status<>'connected' OR g.next_poll_at>now() OR (g.lease_until IS NOT NULL AND g.lease_until>now()) THEN CONTINUE; END IF;
   IF c.status<>'connected' OR coalesce(findez_inventory_role(c.inventory_id,c.actor_id),'') NOT IN ('owner','admin','editor') THEN
    UPDATE commerce_gmail_accounts SET status='disconnected',token_ciphertext=NULL,lease=NULL,lease_until=NULL WHERE connection_id=c.id;
    CONTINUE;
   END IF;
   UPDATE commerce_gmail_accounts SET lease=gen_random_uuid(),lease_until=now()+interval '10 minutes' WHERE connection_id=c.id RETURNING * INTO g;
   RETURN to_jsonb(g);
  END LOOP;
  RETURN NULL;
 END IF;
 SELECT * INTO c FROM commerce_connections WHERE id=(p_payload->>'connection_id')::uuid FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT * INTO g FROM commerce_gmail_accounts WHERE connection_id=c.id FOR UPDATE;
 IF c.status<>'connected' OR g.status<>'connected' OR g.lease IS NULL OR g.lease IS DISTINCT FROM (p_payload->>'lease')::uuid OR g.lease_until<=now()
  OR coalesce(findez_inventory_role(c.inventory_id,c.actor_id),'') NOT IN ('owner','admin','editor') THEN
  RAISE EXCEPTION 'gmail_stale_sync' USING ERRCODE='40001'; END IF;
 IF p_action='tokens' THEN
  UPDATE commerce_gmail_accounts SET token_ciphertext=p_payload->>'token_ciphertext' WHERE connection_id=c.id;
 ELSIF p_action='commit' THEN
  IF jsonb_typeof(p_payload->'messages') IS DISTINCT FROM 'array' OR jsonb_array_length(p_payload->'messages')>20 THEN RAISE EXCEPTION 'gmail_invalid_batch'; END IF;
  FOR r IN SELECT value FROM jsonb_array_elements(p_payload->'messages') LOOP
   INSERT INTO commerce_purchase_emails(connection_id,email_id,body_ciphertext) VALUES(c.id,r->>'email_id',r->>'body_ciphertext') ON CONFLICT DO NOTHING;
  END LOOP;
  UPDATE commerce_gmail_accounts SET cursor=p_payload->'cursor',lease=NULL,lease_until=NULL,
   last_sync_at=now(),last_error=NULL,next_poll_at=now()+CASE WHEN p_payload->'cursor' ? 'page' THEN interval '10 seconds' ELSE interval '5 minutes' END WHERE connection_id=c.id;
 ELSIF p_action='fail' THEN
  UPDATE commerce_gmail_accounts SET lease=NULL,lease_until=NULL,next_poll_at=now()+interval '15 minutes',
   cursor=cursor-'page',last_error='Gmail sync failed. Reconnect if access was revoked.' WHERE connection_id=c.id;
 ELSE RAISE EXCEPTION 'invalid_gmail_job_action'; END IF;
 RETURN '{}'::jsonb;
END $$;

CREATE OR REPLACE FUNCTION public.findez_purchase_email_job(p_action text,p_payload jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c commerce_connections; a commerce_gmail_accounts; m commerce_purchase_emails; candidate record;
BEGIN
 IF p_action='claim' THEN
  -- Lock the connection before the message, same order as pause/disconnect/finish.
  FOR candidate IN SELECT DISTINCT connection_id FROM commerce_purchase_emails
   WHERE status IN ('queued','processing') AND retry_at<=now() AND (lease_until IS NULL OR lease_until<=now()) AND attempts<5 LIMIT 100
  LOOP
   SELECT * INTO c FROM commerce_connections WHERE id=candidate.connection_id FOR UPDATE SKIP LOCKED;
   IF NOT FOUND THEN CONTINUE; END IF;
   SELECT * INTO a FROM commerce_gmail_accounts WHERE connection_id=c.id;
   IF c.status<>'connected' OR a.status<>'connected' OR coalesce(findez_inventory_role(c.inventory_id,c.actor_id),'') NOT IN ('owner','admin','editor') THEN
    UPDATE commerce_purchase_emails SET status='ignored',lease=NULL,lease_until=NULL,body_ciphertext=NULL
     WHERE connection_id=c.id AND status IN ('queued','processing');
    CONTINUE;
   END IF;
   SELECT * INTO m FROM commerce_purchase_emails WHERE connection_id=c.id
    AND status IN ('queued','processing') AND retry_at<=now() AND (lease_until IS NULL OR lease_until<=now()) AND attempts<5
    ORDER BY received_at LIMIT 1 FOR UPDATE SKIP LOCKED;
   IF NOT FOUND THEN CONTINUE; END IF;
   UPDATE commerce_purchase_emails SET status='processing',attempts=attempts+1,lease=gen_random_uuid(),lease_until=now()+interval '3 minutes'
    WHERE id=m.id RETURNING * INTO m;
   RETURN jsonb_build_object('id',m.id,'connection_id',c.id,'email_id',m.email_id,'lease',m.lease,'body_ciphertext',m.body_ciphertext);
  END LOOP;
  -- A crash on the final attempt must not strand a job forever as processing.
  UPDATE commerce_purchase_emails SET status='failed',lease=NULL,lease_until=NULL,body_ciphertext=NULL
   WHERE status='processing' AND attempts>=5 AND lease_until<=now();
  RETURN NULL;
 END IF;
 SELECT x.* INTO c FROM commerce_connections x JOIN commerce_purchase_emails y ON x.id=y.connection_id
  WHERE y.id=(p_payload->>'id')::uuid FOR UPDATE OF x;
 IF NOT FOUND THEN RETURN NULL; END IF; -- purged while a worker was running
 SELECT * INTO m FROM commerce_purchase_emails WHERE id=(p_payload->>'id')::uuid FOR UPDATE;
 SELECT * INTO a FROM commerce_gmail_accounts WHERE connection_id=c.id;
 IF c.status<>'connected' OR a.status<>'connected' OR coalesce(findez_inventory_role(c.inventory_id,c.actor_id),'') NOT IN ('owner','admin','editor') THEN RETURN NULL; END IF;
 IF m.status<>'processing' OR m.lease IS DISTINCT FROM (p_payload->>'lease')::uuid OR m.lease_until<=now() THEN RETURN NULL; END IF;
 IF p_action='fail' THEN
  UPDATE commerce_purchase_emails SET status=CASE WHEN attempts>=5 THEN 'failed' ELSE 'queued' END,
   body_ciphertext=CASE WHEN attempts>=5 THEN NULL ELSE body_ciphertext END,lease=NULL,lease_until=NULL,retry_at=now()+make_interval(secs=>60*attempts*attempts) WHERE id=m.id;
 ELSIF p_action='finish' THEN
  IF jsonb_typeof(p_payload->'result'->'lines') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid_email_result'; END IF;
  IF coalesce(p_payload->>'content_hash','') !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'invalid_content_hash'; END IF;
  IF EXISTS(SELECT FROM commerce_purchase_emails WHERE connection_id=c.id AND content_hash=p_payload->>'content_hash' AND id<>m.id) THEN
   UPDATE commerce_purchase_emails SET status='ignored',lease=NULL,lease_until=NULL,body_ciphertext=NULL WHERE id=m.id;
  ELSE
   UPDATE commerce_purchase_emails SET status=CASE WHEN jsonb_array_length(p_payload->'result'->'lines')=0
    THEN 'ignored' ELSE 'ready' END,
    result=p_payload->'result',body_ciphertext=NULL,content_hash=p_payload->>'content_hash',lease=NULL,lease_until=NULL WHERE id=m.id;
   UPDATE commerce_connections SET last_sync_at=now(),updated_at=now() WHERE id=c.id;
  END IF;
 ELSE RAISE EXCEPTION 'invalid_job_action'; END IF;
 RETURN '{}'::jsonb;
END $$;
REVOKE ALL ON FUNCTION public.findez_gmail_manage(uuid,uuid,text,jsonb),public.findez_gmail_job(text,jsonb),public.findez_purchase_email_job(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_gmail_manage(uuid,uuid,text,jsonb),public.findez_gmail_job(text,jsonb),public.findez_purchase_email_job(text,jsonb) TO service_role;
COMMIT;

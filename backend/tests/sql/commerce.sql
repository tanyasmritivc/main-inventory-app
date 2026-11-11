-- EMPTY DISPOSABLE DATABASE ONLY. No production data, roles or credentials.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role BYPASSRLS; END IF;
END $$;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.app_inventories(inventory_id uuid PRIMARY KEY);
CREATE TABLE public.test_grants(user_id uuid,inventory_id uuid,role text);
CREATE FUNCTION public.findez_inventory_role(i uuid,u uuid) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS $$
 SELECT role FROM public.test_grants WHERE inventory_id=i AND user_id=u $$;
INSERT INTO auth.users VALUES('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
INSERT INTO public.app_inventories VALUES('20000000-0000-0000-0000-000000000001');
INSERT INTO public.test_grants VALUES('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','owner');
\ir ../../supabase/migrations/20261110_commerce_connectors.sql
\ir ../../supabase/migrations/20261110_commerce_connectors.sql
CREATE FUNCTION pg_temp.check(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
 BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF; RAISE NOTICE 'PASS: %',label; END $$;
CREATE FUNCTION pg_temp.denied(statement text,label text) RETURNS void LANGUAGE plpgsql AS $$
 DECLARE blocked bool:=false; BEGIN
 BEGIN EXECUTE statement; EXCEPTION WHEN OTHERS THEN blocked:=true; END;
 PERFORM pg_temp.check(blocked,label); END $$;
SELECT pg_temp.denied($q$SELECT findez_commerce_start('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','shopify','denied.myshopify.com','','','hash')$q$,'nonmember cannot connect');
SELECT findez_commerce_start('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','shopify','test.myshopify.com','','','hash')->>'id' AS c \gset
SELECT pg_temp.denied($q$SELECT findez_commerce_start('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','shopify','test.myshopify.com','','','hash')$q$,'one current store connection');
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000002',%L,'disconnect')$q$,:'c'),'another actor cannot disconnect');
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',%L,'oauth_claim','{}')$q$,:'c'),'missing state is denied');
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','oauth_claim','{"state_hash":"hash"}')->>'lease_id' AS lease \gset
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',%L,'oauth_claim','{"state_hash":"hash"}')$q$,:'c'),'OAuth replay denied');
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',%L,'oauth_finish','{"token_ciphertext":"test-only"}')$q$,:'c'),'missing lease denied');
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','oauth_finish',jsonb_build_object('lease_id',:'lease','token_ciphertext','encrypted-test-only'));
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','sync_claim')->>'lease_id' AS lease \gset
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',%L,'sync_claim')$q$,:'c'),'concurrent sync denied');
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','commit',jsonb_build_object('lease_id',:'lease','resource','orders','records',
 '[{"kind":"sale_line","external_id":"o1:l1","quantity":2,"physically_verified":false}]'::jsonb));
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','sync_claim')->>'lease_id' AS lease \gset
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','commit',jsonb_build_object('lease_id',:'lease','resource','orders','records',
 '[{"kind":"sale_line","external_id":"o1:l1","quantity":1,"physically_verified":false}]'::jsonb));
SELECT pg_temp.check((SELECT count(*)=1 AND max((data->>'quantity')::int)=1 FROM commerce_source_records),'repeat import updates source rather than adding stock');
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','sync_claim')->>'lease_id' AS lease \gset
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',%L,'commit',%L::jsonb)$q$,:'c',
 jsonb_build_object('lease_id',:'lease','resource','orders','records','[{"kind":"purchase_line","external_id":"o2:l1","physically_verified":false}]'::jsonb)::text),'merchant sale cannot become personal purchase');
SELECT pg_temp.check((SELECT count(*)=1 FROM commerce_source_records),'bad batch is atomic');
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','disconnect');
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',%L,'tokens',%L::jsonb)$q$,:'c',
 jsonb_build_object('lease_id',:'lease','token_ciphertext','late-token')::text),'disconnect blocks late token restoration');
SELECT pg_temp.check((SELECT token_ciphertext IS NULL FROM commerce_connections WHERE id=:'c'),'disconnect removes credentials');
SELECT pg_temp.check((SELECT count(*)=1 FROM commerce_source_records),'disconnect retains evidence by default');
DELETE FROM test_grants;
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','disconnect','{"purge":true}');
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_source_records),'purge still works after membership revocation');
SET ROLE authenticated;
SELECT pg_temp.denied('SELECT * FROM commerce_connections','client cannot read encrypted tokens');
SELECT pg_temp.denied('SELECT * FROM commerce_source_records','client cannot bypass source access');
SELECT pg_temp.denied($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','disconnect')$q$,'client cannot impersonate RPC actor');
RESET ROLE;
INSERT INTO test_grants VALUES('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','owner');
SELECT findez_commerce_start('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','amazon_consumer','local-file','','',NULL)->>'id' AS c \gset
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','sync_claim')->>'lease_id' AS old_lease \gset
UPDATE commerce_connections SET lease_expires_at=now()-interval '1 second' WHERE id=:'c';
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','sync_claim')->>'lease_id' AS lease \gset
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',%L,'commit',%L::jsonb)$q$,:'c',
 jsonb_build_object('lease_id',:'old_lease','resource','purchases','records','[]'::jsonb)::text),'expired worker cannot commit over replacement');
DELETE FROM test_grants;
SELECT pg_temp.denied(format($q$SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',%L,'commit',%L::jsonb)$q$,:'c',
 jsonb_build_object('lease_id',:'lease','resource','purchases','records','[]'::jsonb)::text),'revocation between fetch and commit denied');
DELETE FROM auth.users;
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_connections),'account deletion cascades connections');

-- Shopify lifecycle and privacy callbacks, including suppression on later sync.
INSERT INTO auth.users VALUES('10000000-0000-0000-0000-000000000001');
INSERT INTO test_grants VALUES('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','owner');
SELECT findez_commerce_start('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','shopify','privacy.myshopify.com','','','hash')->>'id' AS c \gset
UPDATE commerce_connections SET status='connected',token_ciphertext='test-only' WHERE id=:'c';
INSERT INTO commerce_source_records(connection_id,kind,external_id,resource,data) VALUES(:'c','sale_line','line','orders',
 '{"kind":"sale_line","external_id":"line","order_id":"gid://shopify/Order/123","physically_verified":false}');
SELECT findez_commerce_shopify_event('privacy.myshopify.com','customers/data_request','event1',now(),'["gid://shopify/Order/123"]','request1');
SELECT pg_temp.check((SELECT jsonb_array_length(records)=1 FROM commerce_privacy_exports LIMIT 1),'privacy export contains only requested order evidence');
SELECT pg_temp.check((findez_commerce_shopify_event('privacy.myshopify.com','customers/data_request','event1',now(),'["gid://shopify/Order/123"]','request1')->>'duplicate')::boolean,'webhook replay is idempotent');
SELECT findez_commerce_shopify_event('privacy.myshopify.com','customers/redact','event2',now(),'["gid://shopify/Order/123"]');
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_source_records),'customer redaction removes source rows');
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_privacy_exports),'customer redaction removes retained exports');
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','sync_claim')->>'lease_id' AS lease \gset
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000001',:'c','commit',jsonb_build_object('lease_id',:'lease','resource','orders','records',
 '[{"kind":"sale_line","external_id":"line","order_id":"gid://shopify/Order/123","physically_verified":false}]'::jsonb));
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_source_records),'future sync cannot resurrect redacted orders');
SELECT findez_commerce_shopify_event('privacy.myshopify.com','app/uninstalled','old-event',now()-interval '1 day');
SELECT pg_temp.check((SELECT status='connected' FROM commerce_connections WHERE id=:'c'),'old uninstall cannot remove a newer installation');
SELECT findez_commerce_shopify_event('privacy.myshopify.com','app/uninstalled','event3',now());
SELECT pg_temp.check((SELECT token_ciphertext IS NULL AND status='disconnected' FROM commerce_connections WHERE id=:'c'),'uninstall removes tokens');
SELECT findez_commerce_shopify_event('privacy.myshopify.com','shop/redact','event4',now());
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_connections),'shop redaction removes disconnected accounts');
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_order_redactions),'shop redaction removes suppression metadata');

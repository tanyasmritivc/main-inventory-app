-- ONLY the disposable database created by api_key_rls.sql. No Shopify access.
RESET ROLE;
\ir ../../supabase/migrations/042_shopify_catalog.sql
INSERT INTO auth.users(id) VALUES
('84000000-0000-0000-0000-000000000001'),('84000000-0000-0000-0000-000000000002'),('84000000-0000-0000-0000-000000000003');
INSERT INTO teams(team_id,name,owner_user_id) VALUES
('85000000-0000-0000-0000-000000000001','Shop Team','84000000-0000-0000-0000-000000000001'),
('85000000-0000-0000-0000-000000000002','Other Team','84000000-0000-0000-0000-000000000002');
INSERT INTO team_memberships(team_id,user_id) VALUES
('85000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001'),
('85000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000003'),
('85000000-0000-0000-0000-000000000002','84000000-0000-0000-0000-000000000002');
CREATE TEMP TABLE shopify_test_state(key text PRIMARY KEY,data jsonb);
INSERT INTO shopify_test_state VALUES('physical_before',(SELECT jsonb_agg(to_jsonb(i) ORDER BY item_id) FROM items i));
DO $$ DECLARE denied boolean:=false; BEGIN
  BEGIN PERFORM shopify_begin_auth('85000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000003','pilot.myshopify.com','unauthorized');
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  PERFORM pg_temp.check(denied,'member cannot authorize store');
END $$;
INSERT INTO shopify_test_state VALUES('connection',shopify_begin_auth('85000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','pilot.myshopify.com','state-one'));
SELECT pg_temp.check(shopify_consume_state('state-one','wrong.myshopify.com') IS NULL,'state cannot swap shop');
SELECT pg_temp.check(shopify_consume_state('state-one','pilot.myshopify.com') IS NOT NULL,'state consumed once');
SELECT pg_temp.check(shopify_consume_state('state-one','pilot.myshopify.com') IS NULL,'OAuth replay denied');
SELECT pg_temp.check(shopify_finish_auth((data->>'connection_id')::uuid,(data->>'generation')::uuid,
 '84000000-0000-0000-0000-000000000001','gid://shopify/Shop/1','Pilot',ARRAY['read_inventory','read_products'],
 'encrypted-test',now()+interval '1 hour',now()+interval '90 days'),'valid installation completes') FROM shopify_test_state WHERE key='connection';
DO $$ DECLARE denied boolean:=false; BEGIN
  BEGIN PERFORM shopify_begin_auth('85000000-0000-0000-0000-000000000002','84000000-0000-0000-0000-000000000002','pilot.myshopify.com','steal-state');
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  PERFORM pg_temp.check(denied,'another Team cannot claim installed store');
END $$;

SET ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"84000000-0000-0000-0000-000000000002"}',false);
SELECT pg_temp.check((SELECT count(*)=0 FROM shopify_connections),'foreign Team connections hidden');
SELECT set_config('request.jwt.claims','{"sub":"84000000-0000-0000-0000-000000000003"}',false);
SELECT pg_temp.check((SELECT count(*)=1 FROM shopify_connections),'Team member can read connection');
DO $$ BEGIN
  BEGIN PERFORM * FROM shopify_credentials; RAISE EXCEPTION 'credential read accepted';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: client credentials denied'; END;
  BEGIN PERFORM * FROM shopify_oauth_states; RAISE EXCEPTION 'OAuth state read accepted';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: client OAuth state denied'; END;
  BEGIN PERFORM shopify_claim_job(); RAISE EXCEPTION 'client job claim accepted';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: client worker execution denied'; END;
  BEGIN UPDATE shopify_connections SET shop_name='Mutated'; RAISE EXCEPTION 'client connection update accepted';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: client writes denied'; END;
END $$;
SELECT set_config('request.jwt.claims','{"sub":"84000000-0000-0000-0000-000000000003","api_key_id":"example"}',false);
SELECT pg_temp.check((SELECT count(*)=0 FROM shopify_connections),'API-key JWT cannot inherit member access');
RESET ROLE;

INSERT INTO shopify_test_state VALUES('job',shopify_claim_job());
SELECT pg_temp.check(shopify_claim_job() IS NULL,'two workers cannot share a live lease');
DO $$ DECLARE denied boolean:=false; BEGIN
  BEGIN PERFORM shopify_begin_auth('85000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','pilot.myshopify.com','concurrent-auth');
  EXCEPTION WHEN raise_exception THEN denied:=true; END;
  PERFORM pg_temp.check(denied,'token acquisition cannot race leased refresh');
END $$;
-- Worker crash: expire lease, reclaim cursor, reject the original worker.
UPDATE shopify_sync_jobs SET lease_until=now()-interval '1 second';
INSERT INTO shopify_test_state VALUES('resumed',shopify_claim_job());
SELECT pg_temp.check(NOT shopify_commit_page((data->'connection'->>'connection_id')::uuid,
 (data->'connection'->>'generation')::uuid,(data->'job'->>'lease_id')::uuid,'[]','[]','{"stage":"levels"}'),
 'expired worker cannot commit') FROM shopify_test_state WHERE key='job';
SELECT pg_temp.check(NOT shopify_save_tokens((data->'connection'->>'connection_id')::uuid,
 (data->'connection'->>'generation')::uuid,(data->'job'->>'lease_id')::uuid,'stale-token',now(),now()),
 'expired refresh cannot replace tokens') FROM shopify_test_state WHERE key='job';
SELECT pg_temp.check(shopify_save_tokens((data->'connection'->>'connection_id')::uuid,
 (data->'connection'->>'generation')::uuid,(data->'job'->>'lease_id')::uuid,'new-encrypted',now()+interval '1 hour',now()+interval '90 days'),
 'leased refresh rotates tokens atomically') FROM shopify_test_state WHERE key='resumed';
INSERT INTO shopify_test_state VALUES('variants','[
 {"variant_gid":"gid://shopify/ProductVariant/1","product_gid":"gid://shopify/Product/1","product_title":"Hoodie","variant_title":"Black M","product_status":"ACTIVE","options":[{"name":"Size","value":"M"}],"sku":"Duplicate-SKU","barcodes":[{"value":"0012","type":null},{"value":"0034","type":null}],"image_url":null,"inventory_item_gid":"gid://shopify/InventoryItem/1","tracked":true,"source_updated_at":"2026-10-12T10:00:00Z"},
 {"variant_gid":"gid://shopify/ProductVariant/2","product_gid":"gid://shopify/Product/1","product_title":"Hoodie","variant_title":"Black L","product_status":"ACTIVE","options":[{"name":"Size","value":"L"}],"sku":"Duplicate-SKU","barcodes":[],"image_url":null,"inventory_item_gid":"gid://shopify/InventoryItem/1","tracked":false,"source_updated_at":"2026-10-12T10:00:00Z"}
]');
SELECT pg_temp.check(shopify_commit_page((j.data->'connection'->>'connection_id')::uuid,
 (j.data->'connection'->>'generation')::uuid,(j.data->'job'->>'lease_id')::uuid,v.data,'[]','{"stage":"levels","last_item":"checkpoint"}'),
 'page and cursor commit together') FROM shopify_test_state j CROSS JOIN shopify_test_state v WHERE j.key='resumed' AND v.key='variants';
SELECT pg_temp.check((SELECT count(*)=2 FROM shopify_variants),'same-name duplicate SKUs retain distinct variants');
SELECT pg_temp.check((SELECT barcodes->0->>'value'='0012' FROM shopify_variants WHERE variant_gid='gid://shopify/ProductVariant/1'),'leading-zero barcode preserved');
SELECT pg_temp.check((SELECT cursor->>'last_item'='checkpoint' FROM shopify_sync_jobs),'restart retains cursor');
SELECT pg_temp.check((SELECT last_success_at IS NULL FROM shopify_connections),'partial import never claims full success');

DELETE FROM shopify_test_state WHERE key='job';
INSERT INTO shopify_test_state VALUES('job',shopify_claim_job());
SELECT pg_temp.check(shopify_receive_webhook('86000000-0000-0000-0000-000000000001','event-1','pilot.myshopify.com','products/update',now()),'webhook durable dirty flag');
SELECT pg_temp.check(NOT shopify_receive_webhook('86000000-0000-0000-0000-000000000001','event-1','pilot.myshopify.com','products/update',now()),'duplicate delivery ignored');
SELECT pg_temp.check(shopify_commit_page((j.data->'connection'->>'connection_id')::uuid,
 (j.data->'connection'->>'generation')::uuid,(j.data->'job'->>'lease_id')::uuid,v.data,
 '[{"inventory_item_gid":"gid://shopify/InventoryItem/1","location_gid":"gid://shopify/Location/1","location_name":"Warehouse","location_active":true,"quantities":{"available":24,"on_hand":30},"source_updated_at":"2026-10-12T10:00:00Z"}]',
 '{"stage":"levels"}',true),'full sync completes') FROM shopify_test_state j CROSS JOIN shopify_test_state v WHERE j.key='job' AND v.key='variants';
SELECT pg_temp.check((SELECT count(*)=2 FROM shopify_variants),'repeated page adds no duplicate variants');
SELECT pg_temp.check((SELECT quantities->>'available'='24' AND quantities->>'on_hand'='30' FROM shopify_inventory_levels),'named Shopify stock states stay separate');
SELECT pg_temp.check((SELECT last_success_at IS NOT NULL AND sync_requested FROM shopify_connections),'completion keeps changes received during import queued');

SET ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"84000000-0000-0000-0000-000000000003"}',false);
SELECT pg_temp.check((SELECT count(*)=2 FROM shopify_variants),'member reads catalog');
SELECT pg_temp.check((SELECT count(*)=1 FROM shopify_inventory_levels),'member reads scoped stock snapshots');
RESET ROLE;
DELETE FROM team_memberships WHERE user_id='84000000-0000-0000-0000-000000000003';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=0 FROM shopify_variants),'membership revocation immediately blocks catalog');
RESET ROLE;

-- Exhausted work is durable and explicitly retryable without losing its run ID.
DELETE FROM shopify_test_state WHERE key='job';
INSERT INTO shopify_test_state VALUES('job',shopify_claim_job());
UPDATE shopify_sync_jobs SET attempts=7;
SELECT pg_temp.check(shopify_fail_job((data->'connection'->>'connection_id')::uuid,
 (data->'connection'->>'generation')::uuid,(data->'job'->>'lease_id')::uuid,'network',30),'failure recorded') FROM shopify_test_state WHERE key='job';
SELECT pg_temp.check((SELECT error_code='retry_exhausted' FROM shopify_connections),'exhaustion visible');
SELECT pg_temp.check(shopify_claim_job() IS NULL,'exhausted work does not spin forever');
SELECT pg_temp.check(shopify_request_sync((data->>'connection_id')::uuid,'84000000-0000-0000-0000-000000000001'),'owner resumes exhausted job') FROM shopify_test_state WHERE key='connection';
DELETE FROM shopify_test_state WHERE key='job';
INSERT INTO shopify_test_state VALUES('job',shopify_claim_job());
SELECT pg_temp.check(shopify_commit_page((data->'connection'->>'connection_id')::uuid,
 (data->'connection'->>'generation')::uuid,(data->'job'->>'lease_id')::uuid,'[]','[]','{}',true),'empty refreshed catalog completes') FROM shopify_test_state WHERE key='job';
SELECT pg_temp.check((SELECT count(*)=2 FROM shopify_variants WHERE deleted_at IS NOT NULL),'removed variants tombstoned after full import');
SELECT pg_temp.check((SELECT count(*)=0 FROM shopify_inventory_levels),'absent levels removed after full import');

-- Stale uninstall cannot revoke a new install; explicit disconnect fences workers.
SELECT shopify_receive_webhook('86000000-0000-0000-0000-000000000002','event-2','pilot.myshopify.com','app/uninstalled',now()-interval '1 day','gid://shopify/Shop/1');
SELECT pg_temp.check((SELECT status='connected' FROM shopify_connections),'old uninstall delivery does not revoke current installation');
SELECT shopify_receive_webhook('86000000-0000-0000-0000-000000000005','other-store','pilot.myshopify.com','app/uninstalled',now(),'gid://shopify/Shop/999');
SELECT pg_temp.check((SELECT status='connected' FROM shopify_connections),'another signed store payload cannot revoke this store');
UPDATE shopify_connections SET sync_requested=true;
DELETE FROM shopify_test_state WHERE key='job';
INSERT INTO shopify_test_state VALUES('job',shopify_claim_job());
SELECT pg_temp.check(shopify_disconnect((data->>'connection_id')::uuid,'84000000-0000-0000-0000-000000000001'),'disconnect confirmed') FROM shopify_test_state WHERE key='connection';
SELECT pg_temp.check(NOT shopify_commit_page((data->'connection'->>'connection_id')::uuid,
 (data->'connection'->>'generation')::uuid,(data->'job'->>'lease_id')::uuid,'[]','[]','{}',true),'late worker cannot revive disconnected cache') FROM shopify_test_state WHERE key='job';
SELECT pg_temp.check((SELECT count(*)=0 FROM shopify_credentials),'disconnect erases credentials');
SELECT pg_temp.check((SELECT count(*)=0 FROM shopify_variants),'disconnect erases derived catalog');
SELECT pg_temp.check((SELECT jsonb_agg(to_jsonb(i) ORDER BY item_id) FROM items i)=(SELECT data FROM shopify_test_state WHERE key='physical_before'),'imports and disconnect preserve every native item and quantity');

-- Pending OAuth cannot resurrect after disconnect. Expiry and compliance erase.
DELETE FROM shopify_test_state WHERE key='connection';
INSERT INTO shopify_test_state VALUES('connection',shopify_begin_auth('85000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','pilot.myshopify.com','state-two'));
UPDATE shopify_oauth_states SET expires_at=now()-interval '1 second';
SELECT pg_temp.check(shopify_consume_state('state-two','pilot.myshopify.com') IS NULL,'expired state rejected');
SELECT shopify_receive_webhook('86000000-0000-0000-0000-000000000004','uninstall-pending','pilot.myshopify.com','app/uninstalled',now(),'gid://shopify/Shop/1');
SELECT pg_temp.check((SELECT status='uninstalled' FROM shopify_connections),'known-store uninstall invalidates pending OAuth');
SELECT shopify_disconnect((data->>'connection_id')::uuid,'84000000-0000-0000-0000-000000000001') FROM shopify_test_state WHERE key='connection';
SELECT pg_temp.check(NOT shopify_finish_auth((data->>'connection_id')::uuid,(data->>'generation')::uuid,
 '84000000-0000-0000-0000-000000000001','gid://shopify/Shop/1','Pilot',ARRAY['read_inventory','read_products'],
 'late-encrypted',now()+interval '1 hour',now()+interval '90 days'),'late OAuth cannot reconnect after disconnect') FROM shopify_test_state WHERE key='connection';
SELECT shopify_receive_webhook('86000000-0000-0000-0000-000000000003','redact-1','pilot.myshopify.com','shop/redact',now(),'gid://shopify/Shop/1');
SELECT pg_temp.check((SELECT count(*)=0 FROM shopify_connections),'shop redaction erases binding and derived audit');
SELECT pg_temp.check((SELECT count(*)=0 FROM shopify_audit),'shop redaction erases audit identifiers');
-- A brand new pending store has no verified Shop GID yet. Only a matching signed
-- uninstall identity can prevent completion; another store's payload cannot.
DELETE FROM shopify_test_state WHERE key='connection';
INSERT INTO shopify_test_state VALUES('connection',shopify_begin_auth('85000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','new-pilot.myshopify.com','new-state'));
SELECT shopify_receive_webhook('86000000-0000-0000-0000-000000000006','new-uninstall','new-pilot.myshopify.com','app/uninstalled',now(),'gid://shopify/Shop/2');
SELECT pg_temp.check(NOT shopify_finish_auth((data->>'connection_id')::uuid,(data->>'generation')::uuid,
 '84000000-0000-0000-0000-000000000001','gid://shopify/Shop/2','New Pilot',ARRAY['read_inventory','read_products'],
 'late-encrypted',now()+interval '1 hour',now()+interval '90 days'),'matching initial uninstall blocks token persistence') FROM shopify_test_state WHERE key='connection';
SELECT pg_temp.check((SELECT status='uninstalled' FROM shopify_connections),'initial pending uninstall cannot resurrect an installation');
DELETE FROM shopify_connections;
\echo Shopify catalog isolation and lifecycle checks passed.

RESET ROLE;
CREATE TABLE public.profiles(id uuid PRIMARY KEY,display_name text,first_name text);
ALTER TABLE team_memberships ADD COLUMN role text NOT NULL DEFAULT 'member';
\ir ../../supabase/migrations/013_bin_locations.sql
\ir ../../supabase/migrations/043_physical_memory.sql
INSERT INTO auth.users VALUES ('a1000000-0000-0000-0000-000000000001'),('a1000000-0000-0000-0000-000000000002'),('a1000000-0000-0000-0000-000000000003');
INSERT INTO profiles VALUES('a1000000-0000-0000-0000-000000000001','Alex',NULL);
INSERT INTO teams(team_id,name,owner_user_id) VALUES('a2000000-0000-0000-0000-000000000001','Store Team','a1000000-0000-0000-0000-000000000001'),('a2000000-0000-0000-0000-000000000002','Other Team','a1000000-0000-0000-0000-000000000002');
INSERT INTO team_memberships(team_id,user_id,role) VALUES
 ('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','owner'),
 ('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000003','viewer'),
 ('a2000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000002','owner');
INSERT INTO spaces(id,user_id,name) VALUES('a3000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','Stockroom'),('a3000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000002','Private room');
INSERT INTO team_spaces(team_id,space_id) VALUES('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001');
INSERT INTO bins(id,user_id,space_id,name) VALUES
 ('a4000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','Bin 12'),
 ('a4000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','Bin 13'),
 ('a4000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000002','a3000000-0000-0000-0000-000000000002','Other Bin');
INSERT INTO shopify_connections(connection_id,team_id,shop_domain,shop_gid,status) VALUES('a5000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','memory-pilot.myshopify.com','gid://shopify/Shop/30','connected');
INSERT INTO shopify_variants(connection_id,variant_gid,product_gid,product_title,variant_title,product_status,options,sku,barcodes,inventory_item_gid,tracked,source_updated_at,seen_run) VALUES
 ('a5000000-0000-0000-0000-000000000001','gid://shopify/ProductVariant/30','gid://shopify/Product/30','Hoodie','Black M','ACTIVE','[{"name":"Size","value":"M"}]','Same-SKU','[{"value":"00012345"}]','gid://shopify/InventoryItem/30',true,now(),gen_random_uuid()),
 ('a5000000-0000-0000-0000-000000000001','gid://shopify/ProductVariant/31','gid://shopify/Product/30','Hoodie','Black L','ACTIVE','[{"name":"Size","value":"L"}]','Same-SKU','[{"value":"00012345"}]','gid://shopify/InventoryItem/31',true,now(),gen_random_uuid());
CREATE TEMP TABLE physical_test(key text PRIMARY KEY,value jsonb);
INSERT INTO physical_test VALUES('before',(SELECT jsonb_agg(to_jsonb(i) ORDER BY item_id) FROM items i)),('payload','{
 "native_label":"Our black medium hoodie","connection_id":"a5000000-0000-0000-0000-000000000001","variant_gid":"gid://shopify/ProductVariant/30",
 "space_id":"a3000000-0000-0000-0000-000000000001","bin_id":"a4000000-0000-0000-0000-000000000001","expected_revision":0,"observed_count":null,"action":"confirm"
}');
SELECT pg_temp.check(physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000003','a6000000-0000-0000-0000-000000000001',value)->>'error'='permission','viewer cannot confirm') FROM physical_test WHERE key='payload';
SELECT pg_temp.check(physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000002',value||'{"bin_id":"a4000000-0000-0000-0000-000000000003"}')->>'error'='destination','foreign bin rejected') FROM physical_test WHERE key='payload';
SELECT pg_temp.check((SELECT count(*)=0 FROM physical_memories),'failed save creates no orphan memory');
SELECT pg_temp.check(physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000003',value||'{"barcode":"wrong"}')->>'error'='barcode_conflict','unmatched barcode rejected') FROM physical_test WHERE key='payload';
INSERT INTO physical_test SELECT 'saved',physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000004',value) FROM physical_test WHERE key='payload';
SELECT pg_temp.check(physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000004',value)=(SELECT value FROM physical_test WHERE key='saved'),'confirmation replay returns original receipt') FROM physical_test WHERE key='payload';
SELECT pg_temp.check((SELECT count(*)=1 FROM physical_observations),'replay appends no duplicate event');
SELECT pg_temp.check((SELECT observed_count IS NULL FROM physical_placements),'unknown count is null, not one or zero');
SELECT pg_temp.check(physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000004',value||'{"observed_count":2}')->>'error'='idempotency_conflict','reused key cannot change payload') FROM physical_test WHERE key='payload';
SELECT pg_temp.check(jsonb_array_length(physical_lookup('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',ARRAY['black','medium','hoodie'])->'candidates')=1,'medium matches M, not arbitrary substrings');
SELECT pg_temp.check(jsonb_array_length(physical_lookup('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','{}','00012345')->'candidates')=2,'duplicate barcode stays ambiguous');
SELECT pg_temp.check(physical_lookup('a2000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000002','{}')->'candidates'='[]','foreign Team catalog hidden');
SELECT pg_temp.check(physical_lookup('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000003','{}')->'candidates' IS NOT NULL,'viewer lookup permitted');

-- Two placements for one variant; explicit zero is preserved without stock writes.
SELECT pg_temp.check((physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000005',value||'{"bin_id":"a4000000-0000-0000-0000-000000000002","observed_count":0}')->>'revision')::int=1,'second placement records zero') FROM physical_test WHERE key='payload';
SELECT pg_temp.check((SELECT count(*)=1 FROM physical_memories),'one variant reuses native memory');
SELECT pg_temp.check((SELECT count(*)=2 FROM physical_placements),'one variant supports two bins');
SELECT pg_temp.check(physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000006',value)->>'error'='destination_conflict','same destination is not duplicated') FROM physical_test WHERE key='payload';
INSERT INTO physical_test SELECT 'edit',jsonb_build_object('memory_id',value->>'memory_id','placement_id',value->>'placement_id','native_label','Our black medium hoodie','expected_revision',1,'space_id','a3000000-0000-0000-0000-000000000001','bin_id','a4000000-0000-0000-0000-000000000001','observed_count',3,'action','confirm') FROM physical_test WHERE key='saved';
SELECT pg_temp.check((physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000007',value)->>'revision')::int=2,'reconfirmation advances revision') FROM physical_test WHERE key='edit';
SELECT pg_temp.check(physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000008',value)->>'error'='revision_conflict','stale concurrent edit rejected') FROM physical_test WHERE key='edit';
SELECT pg_temp.check(jsonb_array_length(physical_history('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',(value->>'placement_id')::uuid)->'observations')=2,'confirmation history retains revisions') FROM physical_test WHERE key='saved';
SELECT pg_temp.check(jsonb_array_length(physical_lookup('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','{}',NULL,'12')->'candidates')=1,'bin lookup uses actual confirmed placement');

SET ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000003"}',false);
SELECT pg_temp.check((SELECT count(*)=2 FROM physical_placements),'Team viewer reads owner bins through physical scope');
DO $$ BEGIN
 BEGIN PERFORM * FROM physical_observations; RAISE EXCEPTION 'raw audit exposed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE physical_placements SET observed_count=999; RAISE EXCEPTION 'client wrote observations'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000003","api_key_id":"key"}',false);
SELECT pg_temp.check((SELECT count(*)=0 FROM physical_memories),'API keys cannot read physical memory');
RESET ROLE;

SET ROLE service_role;
DO $$ BEGIN
 BEGIN UPDATE physical_observations SET observed_count=999; RAISE EXCEPTION 'service rewrote audit'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN DELETE FROM physical_observations; RAISE EXCEPTION 'service erased audit'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SELECT pg_temp.check((physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000009',value||'{"action":"remove","expected_revision":2}')->>'revision')::int=3,'removal advances revision without a stock write') FROM physical_test WHERE key='edit';
SELECT pg_temp.check(physical_history('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',(value->>'placement_id')::uuid)->'observations'->0->>'bin_label'='Bin 12','removal audit keeps last confirmed destination') FROM physical_test WHERE key='saved';
SELECT pg_temp.check(physical_confirm('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000010',value||'{"action":"remove","expected_revision":3}')->>'error'='revision_conflict','already removed placement is not removed again') FROM physical_test WHERE key='edit';

DELETE FROM bins WHERE id='a4000000-0000-0000-0000-000000000002';
SELECT pg_temp.check(jsonb_array_length(physical_lookup('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',ARRAY['medium'])->'candidates'->0->'placements')=0,'removed location and deleted bin do not become guessed Space-only locations');
DELETE FROM team_spaces WHERE team_id='a2000000-0000-0000-0000-000000000001';
SELECT pg_temp.check(physical_lookup('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',ARRAY['medium'])->'candidates'->0->'placements'='[]','detached Space locations disappear');
SELECT pg_temp.check(physical_history('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',(value->>'placement_id')::uuid)->'observations'='[]','detached Space history is not disclosed') FROM physical_test WHERE key='saved';
DELETE FROM team_memberships WHERE user_id='a1000000-0000-0000-0000-000000000003';
SELECT pg_temp.check(physical_lookup('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000003',ARRAY['medium'])->>'error'='permission','revoked member cannot look up memory');
SELECT shopify_disconnect('a5000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001');
SELECT pg_temp.check((SELECT count(*)=0 FROM physical_commerce_links),'disconnect erases derived identity links');
SELECT pg_temp.check((SELECT count(*)=1 FROM physical_memories),'disconnect retains independently authored native memory');
SELECT pg_temp.check((SELECT count(*)=4 FROM physical_observations),'disconnect retains human observation history');
SELECT pg_temp.check(physical_lookup('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',ARRAY['hoodie'])->'candidates'->0->>'native_label'='Our black medium hoodie','native name remains searchable after disconnect');
SELECT pg_temp.check((SELECT jsonb_agg(to_jsonb(i) ORDER BY item_id) FROM items i)=(SELECT value FROM physical_test WHERE key='before'),'location observations never change physical inventory or stock');
\echo Physical memory isolation, confirmation and lifecycle checks passed.

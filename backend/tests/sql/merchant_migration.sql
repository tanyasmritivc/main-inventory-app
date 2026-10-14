RESET ROLE;
\ir ../../supabase/migrations/045_merchant_migration.sql
INSERT INTO auth.users VALUES
 ('c1000000-0000-0000-0000-000000000001'),
 ('c1000000-0000-0000-0000-000000000002'),
 ('c1000000-0000-0000-0000-000000000003');
INSERT INTO teams(team_id,name,owner_user_id) VALUES
 ('c2000000-0000-0000-0000-000000000001','Migration Team','c1000000-0000-0000-0000-000000000001'),
 ('c2000000-0000-0000-0000-000000000002','Other migration Team','c1000000-0000-0000-0000-000000000002');
INSERT INTO team_memberships(team_id,user_id,role) VALUES
 ('c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','owner'),
 ('c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000003','viewer'),
 ('c2000000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000002','owner');
INSERT INTO spaces(id,user_id,name) VALUES
 ('c4000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','Stockroom'),
 ('c4000000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000002','Private room');
INSERT INTO team_spaces(team_id,space_id) VALUES
 ('c2000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001');
INSERT INTO bins(id,user_id,space_id,name) VALUES
 ('c5000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','Bin 1'),
 ('c5000000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','Bin 2'),
 ('c5000000-0000-0000-0000-000000000003','c1000000-0000-0000-0000-000000000002','c4000000-0000-0000-0000-000000000002','Moved bin');
INSERT INTO shopify_connections(connection_id,team_id,shop_domain,shop_gid,status,installed_at,last_success_at) VALUES
 ('c3000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','migration-pilot.myshopify.com','gid://shopify/Shop/50','connected',now()-interval '1 hour',now());
INSERT INTO shopify_variants(connection_id,variant_gid,product_gid,product_title,variant_title,product_status,options,sku,barcodes,inventory_item_gid,tracked,source_updated_at,seen_run,deleted_at)
 SELECT 'c3000000-0000-0000-0000-000000000001','gid://shopify/ProductVariant/'||i,'gid://shopify/Product/'||i,'Product '||i,'Default Title','ACTIVE','[]','Repeated-SKU','[]','gid://shopify/InventoryItem/'||i,true,now(),gen_random_uuid(),CASE WHEN i=9 THEN now() END
 FROM generate_series(1,9) i;
INSERT INTO physical_memories(memory_id,team_id,native_label)
 SELECT ('c6000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
 CASE WHEN i=8 THEN 'c2000000-0000-0000-0000-000000000002'::uuid ELSE 'c2000000-0000-0000-0000-000000000001'::uuid END,'Our product '||i
 FROM generate_series(1,8) i;
INSERT INTO physical_commerce_links(memory_id,connection_id,variant_gid)
 SELECT memory_id,'c3000000-0000-0000-0000-000000000001','gid://shopify/ProductVariant/'||right(native_label,1)
 FROM physical_memories WHERE memory_id::text LIKE 'c6000000%';
INSERT INTO physical_placements(memory_id,team_id,space_id,bin_id,had_bin,status,revision,observed_count,confirmed_at,source_kind) VALUES
 ('c6000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000001',true,'active',1,0,now(),'catalog_selection'),
 ('c6000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000002',true,'active',1,NULL,now()-interval '8 days','catalog_selection'),
 ('c6000000-0000-0000-0000-000000000002','c2000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001',NULL,true,'active',1,NULL,now(),'catalog_selection'),
 ('c6000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000003',true,'active',1,NULL,now(),'catalog_selection'),
 ('c6000000-0000-0000-0000-000000000004','c2000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001',NULL,false,'removed',2,NULL,now(),'manual_reconfirmation'),
 ('c6000000-0000-0000-0000-000000000005','c2000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001',NULL,false,'active',1,NULL,now(),'catalog_selection'),
 ('c6000000-0000-0000-0000-000000000008','c2000000-0000-0000-0000-000000000002','c4000000-0000-0000-0000-000000000002',NULL,false,'active',1,NULL,now(),'catalog_selection');

CREATE FUNCTION pg_temp.migration_report(p_actor uuid DEFAULT 'c1000000-0000-0000-0000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT shopify_adoption_report('c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001',p_actor);
$$;
SELECT pg_temp.check(pg_temp.migration_report()->>'total_variants'='8','removed catalog variant is excluded');
SELECT pg_temp.check(pg_temp.migration_report()->>'confirmed_variants'='2','multiple placements count once; removed, deleted, moved and foreign destinations are excluded');
SELECT pg_temp.check(pg_temp.migration_report()->>'older_confirmations'='1','any accessible older confirmation is flagged once');
SELECT pg_temp.check(pg_temp.migration_report()->>'unconfirmed_variants'='6','unconfirmed variants remain separate from unknown stock');
SELECT pg_temp.check(jsonb_array_length(pg_temp.migration_report()->'unconfirmed_sample')=5,'queue is bounded to five');
SELECT pg_temp.check(pg_temp.migration_report()->'unconfirmed_sample'->0->>'variant_gid'='gid://shopify/ProductVariant/2','queue uses deterministic stable IDs, not repeated SKUs');
SELECT pg_temp.check(pg_temp.migration_report()->'confirmed_example'->>'variant_gid'='gid://shopify/ProductVariant/1','lookup points to a confirmed variant');
SELECT pg_temp.check(pg_temp.migration_report()->>'import_complete'='true','current install completed sync');
SELECT pg_temp.check(pg_temp.migration_report()->>'can_confirm'='true','editor can confirm');
SELECT pg_temp.check(pg_temp.migration_report('c1000000-0000-0000-0000-000000000003')->>'can_confirm'='false','viewer reads progress without writes');
SELECT pg_temp.check(pg_temp.migration_report('c1000000-0000-0000-0000-000000000002')->>'error'='permission','foreign actor blocked');
SELECT pg_temp.check(shopify_adoption_report('c2000000-0000-0000-0000-000000000002','c3000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000002')->>'error'='permission','connection must belong to requested Team');

UPDATE shopify_connections SET installed_at=now()+interval '1 minute' WHERE connection_id='c3000000-0000-0000-0000-000000000001';
SELECT pg_temp.check(pg_temp.migration_report()->>'import_complete'='false','previous install sync cannot mark a new import complete');
UPDATE shopify_connections SET status='reconnect_required' WHERE connection_id='c3000000-0000-0000-0000-000000000001';
SELECT pg_temp.check(pg_temp.migration_report()->>'can_confirm'='false','reconnect requires renewed access before mapping');
UPDATE shopify_connections SET status='connected',installed_at=now()-interval '1 hour' WHERE connection_id='c3000000-0000-0000-0000-000000000001';
DELETE FROM bins WHERE id='c5000000-0000-0000-0000-000000000002';
SELECT pg_temp.check(pg_temp.migration_report()->>'older_confirmations'='0','deleted bin cannot continue a stale progress badge');
SELECT pg_temp.check(pg_temp.migration_report()->>'confirmed_variants'='2','another accessible placement still confirms the variant');
UPDATE shopify_variants SET deleted_at=now() WHERE connection_id='c3000000-0000-0000-0000-000000000001' AND variant_gid='gid://shopify/ProductVariant/1';
SELECT pg_temp.check(pg_temp.migration_report()->>'confirmed_variants'='1','deleted product is no longer part of current mapping progress');
DELETE FROM team_spaces WHERE team_id='c2000000-0000-0000-0000-000000000001';
SELECT pg_temp.check(pg_temp.migration_report()->>'confirmed_variants'='0' AND pg_temp.migration_report()->>'space_count'='0','detached Space clears progress and lookup example');
DELETE FROM team_memberships WHERE user_id='c1000000-0000-0000-0000-000000000003';
SELECT pg_temp.check(pg_temp.migration_report('c1000000-0000-0000-0000-000000000003')->>'error'='permission','revocation is checked every read');

SET ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000001","api_key_id":"key"}',false);
DO $$ BEGIN
 BEGIN PERFORM shopify_adoption_report('c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001'); RAISE EXCEPTION 'client invoked service report'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM shopify_adoption_report('c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001'); RAISE EXCEPTION 'anonymous report'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE shopify_connections SET status='disconnected' WHERE connection_id='c3000000-0000-0000-0000-000000000001';
SELECT pg_temp.check(pg_temp.migration_report()->>'error'='reconnect','disconnected connections cannot expose setup records');
\echo Guided merchant migration isolation and factual progress checks passed.

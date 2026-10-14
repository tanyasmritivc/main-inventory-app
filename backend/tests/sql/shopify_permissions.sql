RESET ROLE;
\ir ../../supabase/migrations/044_shopify_owner_permissions.sql
INSERT INTO auth.users VALUES('b1000000-0000-0000-0000-000000000001'),('b1000000-0000-0000-0000-000000000002'),('b1000000-0000-0000-0000-000000000003');
INSERT INTO teams(team_id,name,owner_user_id) VALUES('b2000000-0000-0000-0000-000000000001','Edit Team','b1000000-0000-0000-0000-000000000001');
INSERT INTO team_memberships(team_id,user_id,role) VALUES
 ('b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','owner'),
 ('b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','member'),
 ('b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000003','viewer');
INSERT INTO shopify_connections(connection_id,team_id,shop_domain,shop_gid,status,granted_scopes)
 VALUES('b3000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','edit-pilot.myshopify.com','gid://shopify/Shop/40','connected',ARRAY['read_products','read_inventory']);
CREATE TEMP TABLE edit_test(key text PRIMARY KEY,value jsonb);
SELECT pg_temp.check(NOT shopify_can_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','product'),'default is read only');
SELECT pg_temp.check(shopify_permissions('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002',true,true,'editors',0)->>'error'='permission','member cannot increase owner policy');
SELECT pg_temp.check(shopify_permissions('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',true,true,'owner',0)->>'revision'='1','owner selects edits');
SELECT pg_temp.check(NOT shopify_can_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','product'),'local choice is not Shopify grant');
UPDATE shopify_connections SET granted_scopes=ARRAY['write_products','write_inventory'] WHERE connection_id='b3000000-0000-0000-0000-000000000001';
SELECT pg_temp.check(shopify_can_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','product'),'owner edits with real grant');
SELECT pg_temp.check(NOT shopify_can_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','product'),'owner-only delegation enforced');
SELECT pg_temp.check(shopify_permissions('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',true,true,'editors',0)->>'error'='revision','stale permission update rejected');
SELECT shopify_permissions('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',true,true,'editors',1);
SELECT pg_temp.check(shopify_can_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','inventory'),'owner delegates stock edits to member');
SELECT pg_temp.check(NOT shopify_can_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000003','inventory'),'viewer stays read only');
INSERT INTO edit_test VALUES('lease',shopify_claim_io('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002'));
SELECT pg_temp.check(shopify_claim_io('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001')->>'error'='busy','only one token or edit IO lease');
INSERT INTO edit_test SELECT 'operation',shopify_prepare_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002',(value->>'io_lease')::uuid,'inventory','{"delta":2}','{"available":8}') FROM edit_test WHERE key='lease';
SELECT shopify_permissions('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',false,false,'owner',2);
SELECT pg_temp.check(shopify_dispatch_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002',(SELECT (value->>'io_lease')::uuid FROM edit_test WHERE key='lease'),(value->>'operation_id')::uuid)->>'error'='permission','downgrade invalidates pending approval') FROM edit_test WHERE key='operation';
SELECT pg_temp.check((SELECT state='prepared' FROM shopify_operations),'revoked review never dispatched');
SELECT shopify_permissions('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',true,true,'editors',3);
INSERT INTO edit_test SELECT 'new',shopify_prepare_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002',(value->>'io_lease')::uuid,'inventory','{"delta":3}','{"available":8}') FROM edit_test WHERE key='lease';
SELECT pg_temp.check(shopify_dispatch_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002',(SELECT (value->>'io_lease')::uuid FROM edit_test WHERE key='lease'),(value->>'operation_id')::uuid)->>'state'='sending','current review dispatched once') FROM edit_test WHERE key='new';
SELECT pg_temp.check(shopify_dispatch_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002',(SELECT (value->>'io_lease')::uuid FROM edit_test WHERE key='lease'),(value->>'operation_id')::uuid)->>'error'='outcome_unknown','duplicate send prevented') FROM edit_test WHERE key='new';
SELECT shopify_finish_edit('b3000000-0000-0000-0000-000000000001',(SELECT (value->>'io_lease')::uuid FROM edit_test WHERE key='lease'),(value->>'operation_id')::uuid,'unknown',NULL) FROM edit_test WHERE key='new';
SELECT pg_temp.check(shopify_prepare_edit('b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002',(value->>'io_lease')::uuid,'inventory','{"delta":3}','{}')->>'error'='outcome_unknown','uncertain result blocks new edits') FROM edit_test WHERE key='lease';
SELECT shopify_release_io('b3000000-0000-0000-0000-000000000001',(value->>'io_lease')::uuid) FROM edit_test WHERE key='lease';
SELECT pg_temp.check(NOT shopify_review_unknown('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002',(value->>'operation_id')::uuid),'member cannot clear uncertain outcome') FROM edit_test WHERE key='new';
SELECT pg_temp.check(shopify_review_unknown('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',(value->>'operation_id')::uuid),'owner acknowledges actual Shopify check') FROM edit_test WHERE key='new';
SELECT pg_temp.check((SELECT state='unknown' AND reviewed_at IS NOT NULL FROM shopify_operations WHERE operation_id=(SELECT (value->>'operation_id')::uuid FROM edit_test WHERE key='new')),'acknowledgment does not fabricate success');
SET ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000001"}',false);
DO $$ BEGIN
 BEGIN PERFORM * FROM shopify_operations; RAISE EXCEPTION 'raw operation exposed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM io_lease FROM shopify_connections; RAISE EXCEPTION 'IO lease exposed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM shopify_permissions('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001',true,true,'editors',4); RAISE EXCEPTION 'client wrote policy'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
\echo Owner permissions, review, revocation and duplicate-write checks passed.

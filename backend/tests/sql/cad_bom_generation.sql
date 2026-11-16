\set ON_ERROR_STOP on
-- Run ONLY in a fresh disposable database.
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.app_inventories(inventory_id uuid PRIMARY KEY);
CREATE TABLE public.items(item_id uuid PRIMARY KEY,inventory_id uuid NOT NULL REFERENCES app_inventories);
CREATE TABLE public.test_roles(actor_id uuid,inventory_id uuid,role text);
CREATE FUNCTION public.findez_inventory_role(uuid,uuid) RETURNS text LANGUAGE sql AS $$ SELECT role FROM test_roles WHERE inventory_id=$1 AND actor_id=$2 $$;
\ir ../../supabase/migrations/20261115_cad_workspace.sql
\ir ../../supabase/migrations/20261116_cad_bom_generation.sql
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
INSERT INTO app_inventories VALUES ('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
INSERT INTO test_roles VALUES ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','editor');
INSERT INTO items VALUES ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
INSERT INTO cad_device_grants(id,device_hash,user_code,actor_id,inventory_id,approved_at,session_expires_at,token_hash)
VALUES('30000000-0000-0000-0000-000000000001',repeat('a',64),'ABCD234567','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',now(),now()+interval '1 hour',repeat('b',64));
DO $$
DECLARE a uuid:='00000000-0000-0000-0000-000000000001'; i uuid:='10000000-0000-0000-0000-000000000001';
 g uuid:='30000000-0000-0000-0000-000000000001'; r uuid:=gen_random_uuid(); v jsonb; again jsonb; n integer;
BEGIN
 IF has_table_privilege('authenticated','cad_bom_versions','SELECT') OR has_table_privilege('anon','cad_generation_jobs','SELECT') THEN RAISE EXCEPTION 'private metadata exposed'; END IF;
 IF has_function_privilege('authenticated','findez_cad_can_write(uuid,uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'function exposed'; END IF;
 IF findez_cad_can_write(a,i,g) THEN RAISE EXCEPTION 'legacy grant silently expanded'; END IF;
 IF findez_cad_save_version(a,i,g,repeat('c',64),'Robot',r,repeat('d',64),'{}','{}')->>'error'<>'forbidden' THEN RAISE EXCEPTION 'read only write'; END IF;
 UPDATE cad_device_grants SET allow_cad_writes=true WHERE id=g;
 v:=findez_cad_save_version(a,i,g,repeat('c',64),'Robot',r,repeat('d',64),'{}','{"summary":{"covered_units":3}}');
 again:=findez_cad_save_version(a,i,g,repeat('c',64),'Robot',r,repeat('d',64),'{}','{"summary":{"covered_units":10}}');
 IF v->>'id' IS DISTINCT FROM again->>'id' OR (again->>'replayed')::boolean IS NOT true THEN RAISE EXCEPTION 'retry duplicates'; END IF;
 IF (SELECT comparison->'summary'->>'covered_units' FROM cad_bom_versions WHERE id=(v->>'id')::uuid)<>'3' THEN RAISE EXCEPTION 'history mutated'; END IF;
 IF findez_cad_save_version(a,i,g,repeat('c',64),'Robot',r,repeat('e',64),'{}','{}')->>'error'<>'conflict' THEN RAISE EXCEPTION 'changed retry accepted'; END IF;
 IF findez_cad_save_review(a,i,g,repeat('c',64),'match','20000000-0000-0000-0000-000000000001',repeat('d',64)) THEN RAISE EXCEPTION 'foreign item accepted'; END IF;
 IF NOT findez_cad_save_review(a,i,g,repeat('c',64),'no_match',NULL,NULL) THEN RAISE EXCEPTION 'review failed'; END IF;
 v:=findez_cad_begin_generation(a,i,g,r,repeat('f',64),'{"prompt":"plate","name":"plate","units":"mm"}');
 again:=findez_cad_begin_generation(a,i,g,r,repeat('f',64),'{"prompt":"plate","name":"plate","units":"mm"}');
 IF v->>'id' IS DISTINCT FROM again->>'id' THEN RAISE EXCEPTION 'job retry duplicates'; END IF;
 IF findez_cad_begin_generation(a,i,g,r,repeat('e',64),'{}')->>'error'<>'conflict' THEN RAISE EXCEPTION 'changed job retry'; END IF;
 UPDATE test_roles SET role='viewer' WHERE actor_id=a;
 IF findez_cad_can_write(a,i,g) THEN RAISE EXCEPTION 'role revocation bypass'; END IF;
 UPDATE test_roles SET role='editor' WHERE actor_id=a;
 UPDATE cad_device_grants SET revoked_at=now() WHERE id=g;
 IF findez_cad_save_review(a,i,g,repeat('c',64),'reset',NULL,NULL) THEN RAISE EXCEPTION 'revoked grant wrote'; END IF;
 SELECT count(*) INTO n FROM items; IF n<>1 THEN RAISE EXCEPTION 'stock altered'; END IF;
END $$;
SELECT 'BOM idempotency, historical immutability, correction scope and generation isolation passed';

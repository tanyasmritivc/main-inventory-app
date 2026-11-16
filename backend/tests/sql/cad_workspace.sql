\set ON_ERROR_STOP on
-- ONLY a fresh disposable database. No production fixtures.
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.app_inventories(inventory_id uuid PRIMARY KEY);
CREATE TABLE public.test_roles(actor_id uuid, inventory_id uuid, role text);
CREATE FUNCTION public.findez_inventory_role(uuid,uuid) RETURNS text LANGUAGE sql AS $$ SELECT role FROM test_roles WHERE inventory_id=$1 AND actor_id=$2 $$;
\ir ../../supabase/migrations/20261115_cad_workspace.sql
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
INSERT INTO app_inventories VALUES ('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
INSERT INTO test_roles VALUES ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','viewer');
INSERT INTO cad_device_grants(device_hash,user_code) VALUES (repeat('a',64),'ABCD234567'),(repeat('c',64),'ABCD234568'),(repeat('d',64),'ABCD234569');
DO $$
DECLARE a uuid:='00000000-0000-0000-0000-000000000001'; b uuid:='00000000-0000-0000-0000-000000000002';
 i uuid:='10000000-0000-0000-0000-000000000001'; j uuid:='10000000-0000-0000-0000-000000000002';
BEGIN
 IF has_table_privilege('anon','cad_device_grants','SELECT') OR has_table_privilege('authenticated','cad_device_grants','SELECT') THEN RAISE EXCEPTION 'credential exposure'; END IF;
 IF has_function_privilege('authenticated','findez_cad_device_exchange(text,text)','EXECUTE') OR has_function_privilege('anon','findez_cad_device_approve(text,uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'public auth mutation'; END IF;
 IF (findez_cad_device_exchange(repeat('a',64),repeat('b',64))->>'status')<>'pending' THEN RAISE EXCEPTION 'unapproved token'; END IF;
 IF findez_cad_device_approve('ABCD234567',b,i) OR findez_cad_device_approve('ABCD234567',a,j) THEN RAISE EXCEPTION 'foreign pairing'; END IF;
 IF NOT findez_cad_device_approve('ABCD234567',a,i) THEN RAISE EXCEPTION 'viewer read pairing blocked'; END IF;
 IF findez_cad_device_approve('ABCD234567',a,i) THEN RAISE EXCEPTION 'approval replay'; END IF;
 IF (findez_cad_device_exchange(repeat('a',64),repeat('b',64))->>'status')<>'connected' THEN RAISE EXCEPTION 'exchange failed'; END IF;
 IF (findez_cad_device_exchange(repeat('a',64),repeat('c',64))->>'status')<>'expired' THEN RAISE EXCEPTION 'exchange replay'; END IF;
 UPDATE cad_device_grants SET pairing_expires_at=now()-interval '1 second' WHERE user_code='ABCD234568';
 IF findez_cad_device_approve('ABCD234568',a,i) THEN RAISE EXCEPTION 'expired approval'; END IF;
 IF NOT findez_cad_device_approve('ABCD234569',a,i) THEN RAISE EXCEPTION 'approval failed'; END IF;
 DELETE FROM test_roles;
 IF (findez_cad_device_exchange(repeat('d',64),repeat('e',64))->>'status')<>'expired' THEN RAISE EXCEPTION 'permission revocation bypassed'; END IF;
 IF EXISTS(SELECT 1 FROM cad_device_grants WHERE token_hash=repeat('e',64)) THEN RAISE EXCEPTION 'issued revoked token'; END IF;
 DELETE FROM auth.users WHERE id=a;
 IF EXISTS(SELECT 1 FROM cad_device_grants WHERE actor_id=a) THEN RAISE EXCEPTION 'credentials survive account deletion'; END IF;
END $$;
SELECT 'Fusion pairing isolation, replay, expiry, revocation and deletion checks passed';

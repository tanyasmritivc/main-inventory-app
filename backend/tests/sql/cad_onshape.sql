\set ON_ERROR_STOP on
-- Run only in a fresh disposable DB. Minimal fixture, not a production baseline.
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.app_inventories(inventory_id uuid PRIMARY KEY);
CREATE TABLE public.items(item_id uuid PRIMARY KEY,inventory_id uuid REFERENCES public.app_inventories);
CREATE TABLE public.test_inventory_roles(inventory_id uuid,actor_id uuid,role text);
CREATE FUNCTION public.findez_inventory_role(uuid,uuid) RETURNS text LANGUAGE sql AS $$
 SELECT role FROM public.test_inventory_roles WHERE inventory_id=$1 AND actor_id=$2
$$;
\ir ../../supabase/migrations/086_cad_onshape.sql
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
INSERT INTO app_inventories VALUES ('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
INSERT INTO items VALUES ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002');
INSERT INTO test_inventory_roles VALUES ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','editor'),
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','viewer');
DO $$
DECLARE a uuid:='00000000-0000-0000-0000-000000000001'; v uuid:='00000000-0000-0000-0000-000000000002';
 i uuid:='10000000-0000-0000-0000-000000000001'; item uuid:='20000000-0000-0000-0000-000000000001';
BEGIN
 IF has_table_privilege('authenticated','cad_match_corrections','SELECT') OR has_table_privilege('anon','cad_onshape_connections','SELECT') THEN RAISE EXCEPTION 'Client grant'; END IF;
 IF has_function_privilege('authenticated','findez_cad_refresh_lease(uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'Client RPC grant'; END IF;
 IF NOT findez_cad_save_correction(a,i,repeat('a',64),'match',item,repeat('b',64)) THEN RAISE EXCEPTION 'Save denied'; END IF;
 IF findez_cad_save_correction(v,i,repeat('a',64),'no_match',null,null) THEN RAISE EXCEPTION 'Viewer wrote'; END IF;
 IF findez_cad_save_correction(a,i,repeat('a',64),'match','20000000-0000-0000-0000-000000000002',repeat('b',64)) THEN RAISE EXCEPTION 'Foreign item accepted'; END IF;
 IF findez_cad_save_correction(a,'10000000-0000-0000-0000-000000000002',repeat('a',64),'no_match',null,null) THEN RAISE EXCEPTION 'Foreign inventory accepted'; END IF;
 IF NOT findez_cad_save_correction(a,i,repeat('a',64),'no_match',null,null) THEN RAISE EXCEPTION 'Reject failed'; END IF;
 IF (SELECT count(*) FROM cad_match_corrections)<>1 THEN RAISE EXCEPTION 'Upsert duplicated'; END IF;
 IF NOT findez_cad_save_correction(a,i,repeat('a',64),'reset',null,null) THEN RAISE EXCEPTION 'Reset failed'; END IF;
 IF EXISTS(SELECT 1 FROM cad_match_corrections) THEN RAISE EXCEPTION 'Reset left a correction'; END IF;
END $$;
INSERT INTO cad_onshape_connections(actor_id,generation,tokens,expires_at) VALUES
 ('00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','encrypted-test-only',now()-interval '1 hour');
DO $$ BEGIN
 IF NOT findez_cad_refresh_lease('00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001') THEN RAISE EXCEPTION 'First lease failed'; END IF;
 IF findez_cad_refresh_lease('00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001') THEN RAISE EXCEPTION 'Double refresh'; END IF;
 IF findez_cad_refresh_lease('00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002') THEN RAISE EXCEPTION 'Stale connection refreshed'; END IF;
END $$;
DELETE FROM auth.users WHERE id='00000000-0000-0000-0000-000000000001';
DO $$ BEGIN IF EXISTS(SELECT 1 FROM cad_onshape_connections) THEN RAISE EXCEPTION 'Credentials survived account deletion'; END IF; END $$;
SELECT 'CAD migration isolation and refresh checks passed';

INSERT INTO cad_oauth_states VALUES ('00000000-0000-0000-0000-000000000002',repeat('c',64),now()+interval '10 minutes');
DO $$ BEGIN
 IF findez_cad_begin_connection('00000000-0000-0000-0000-000000000002',repeat('d',64),'30000000-0000-0000-0000-000000000002') THEN RAISE EXCEPTION 'Wrong state accepted'; END IF;
 IF NOT findez_cad_begin_connection('00000000-0000-0000-0000-000000000002',repeat('c',64),'30000000-0000-0000-0000-000000000002') THEN RAISE EXCEPTION 'State not consumed'; END IF;
 IF findez_cad_begin_connection('00000000-0000-0000-0000-000000000002',repeat('c',64),'30000000-0000-0000-0000-000000000002') THEN RAISE EXCEPTION 'State replay'; END IF;
 PERFORM findez_cad_disconnect('00000000-0000-0000-0000-000000000002');
 UPDATE cad_onshape_connections SET tokens='late callback',expires_at=now()+interval '1 hour'
 WHERE actor_id='00000000-0000-0000-0000-000000000002' AND generation='30000000-0000-0000-0000-000000000002';
 IF FOUND THEN RAISE EXCEPTION 'Callback resurrected connection'; END IF;
END $$;
SELECT 'CAD OAuth state replay and disconnect checks passed';

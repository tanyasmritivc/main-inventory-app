\set ON_ERROR_STOP on
\ir cad_purchasing.sql
\ir ../../supabase/migrations/20261118_cad_native_purchasing.sql
DO $$
DECLARE a uuid:='00000000-0000-0000-0000-000000000001'; i uuid:='10000000-0000-0000-0000-000000000001';
 g uuid:='30000000-0000-0000-0000-000000000001'; b uuid; p uuid; l uuid:=gen_random_uuid(); r uuid:=gen_random_uuid(); data jsonb; v jsonb; qty integer;
BEGIN
 IF has_function_privilege('authenticated','findez_cad_native_purchase_action(uuid,uuid,uuid,uuid,text,uuid,text,integer,jsonb)','EXECUTE')
 OR has_function_privilege('anon','findez_cad_device_approve_purchasing(text,uuid,uuid,boolean)','EXECUTE') THEN RAISE EXCEPTION 'native RPC public'; END IF;
 IF EXISTS(SELECT 1 FROM cad_device_grants WHERE allow_purchasing) THEN RAISE EXCEPTION 'existing grant expanded'; END IF;
 UPDATE cad_device_grants SET revoked_at=NULL,session_expires_at=now()+interval '1 hour' WHERE id=g;
 SELECT id INTO b FROM cad_bom_versions LIMIT 1;
 data:=jsonb_build_object('bom_version_id',b,'name','Native robot','inventory_as_of',now(),'lines',jsonb_build_array(
 jsonb_build_object('id',l,'quantity',3,'received',0,'quotes','[]'::jsonb,'selected_quote',jsonb_build_object('valid_until',now()+interval '1 day','estimate',jsonb_build_object('order_quantity',3)))));
 v:=findez_cad_native_purchase_action(a,i,g,r,repeat('a',64),NULL,'create',NULL,data);
 IF v->>'error'<>'forbidden' THEN RAISE EXCEPTION 'old grant created purchase'; END IF;
 g:=gen_random_uuid();
 INSERT INTO cad_device_grants(id,device_hash,user_code) VALUES(g,repeat('c',64),'BCDE234567');
 IF NOT findez_cad_device_approve_purchasing('BCDE234567',a,i,false) THEN RAISE EXCEPTION 'explicit consent failed'; END IF;
 PERFORM findez_cad_device_exchange(repeat('c',64),repeat('d',64));
 IF (SELECT allow_cad_writes FROM cad_device_grants WHERE id=g) THEN RAISE EXCEPTION 'purchase consent enabled unrelated writes'; END IF;
 v:=findez_cad_native_purchase_action(a,i,g,r,repeat('a',64),NULL,'create',NULL,data); p:=(v->>'id')::uuid;
 IF p IS NULL THEN RAISE EXCEPTION 'native create %',v; END IF;
 IF findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('b',64),p,'approve',1,'{}')->>'error'<>'approval_required' THEN RAISE EXCEPTION 'editor approved'; END IF;
 UPDATE test_roles SET role='admin';
 v:=findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('b',64),p,'approve',1,'{}');
 v:=findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('b',64),p,'order',2,'{"order_reference":"PO native"}');
 IF (SELECT state FROM cad_purchase_plans WHERE id=p)<>'ordered' THEN RAISE EXCEPTION 'native ordering %',v; END IF;
 UPDATE test_roles SET role='editor';
 SELECT quantity INTO qty FROM items WHERE item_id='20000000-0000-0000-0000-000000000002';
 data:=jsonb_build_object('line_id',l,'quantity',1,'item_id','20000000-0000-0000-0000-000000000002','identity_confirmed',true); r:=gen_random_uuid();
 UPDATE cad_device_grants SET revoked_at=now() WHERE id=g;
 IF findez_cad_native_purchase_action(a,i,g,r,repeat('c',64),p,'receive',3,data)->>'error'<>'forbidden' THEN RAISE EXCEPTION 'revoked grant received'; END IF;
 UPDATE cad_device_grants SET revoked_at=NULL,session_expires_at=now()-interval '1 minute' WHERE id=g;
 IF findez_cad_native_purchase_action(a,i,g,r,repeat('c',64),p,'receive',3,data)->>'error'<>'forbidden' THEN RAISE EXCEPTION 'expired grant received'; END IF;
 UPDATE cad_device_grants SET session_expires_at=now()+interval '1 hour' WHERE id=g;
 IF findez_cad_native_purchase_action('00000000-0000-0000-0000-000000000002',i,g,r,repeat('c',64),p,'receive',3,data)->>'error'<>'forbidden' THEN RAISE EXCEPTION 'other actor used grant'; END IF;
 v:=findez_cad_native_purchase_action(a,i,g,r,repeat('c',64),p,'receive',3,data);
 v:=findez_cad_native_purchase_action(a,i,g,r,repeat('c',64),p,'receive',3,data);
 IF v->>'replayed'<>'true' OR (SELECT quantity FROM items WHERE item_id='20000000-0000-0000-0000-000000000002')<>qty+1 THEN RAISE EXCEPTION 'native duplicate stock'; END IF;
 UPDATE test_roles SET role='viewer';
 IF findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('d',64),p,'receive',4,data)->>'error'<>'forbidden' THEN RAISE EXCEPTION 'viewer received'; END IF;
END $$;
SELECT 'Native consent, expiry, revocation, actor/role isolation and receiving replay passed';

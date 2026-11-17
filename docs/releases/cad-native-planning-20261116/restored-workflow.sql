-- Synthetic exercise ONLY in the network-disabled disposable restored database.
-- Existing identities are kept inside this transaction and never printed.
BEGIN;
SET LOCAL request.jwt.claims='{"role":"service_role"}';
DO $$
DECLARE a uuid; i uuid; item uuid; project uuid; bom uuid; p uuid; line uuid:=gen_random_uuid(); q uuid:=gen_random_uuid(); v jsonb; g uuid:=gen_random_uuid(); token text:=encode(extensions.digest(gen_random_uuid()::text,'sha256'),'hex'); code text:=translate(upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),'01','GH');
BEGIN
 SELECT inv.owner_user_id,inv.inventory_id,it.item_id INTO a,i,item
 FROM app_inventories inv JOIN items it USING(inventory_id)
 WHERE findez_inventory_role(inv.inventory_id,inv.owner_user_id)='owner' AND it.quantity>=0 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'No suitable restored fixture'; END IF;
 INSERT INTO cad_device_grants(id,device_hash,user_code) VALUES(g,token,code);
 IF NOT findez_cad_device_approve_purchasing(code,a,i,false) THEN RAISE EXCEPTION 'Native consent failed'; END IF;
 PERFORM findez_cad_device_exchange(token,encode(extensions.digest(gen_random_uuid()::text,'sha256'),'hex'));
 IF (SELECT allow_cad_writes FROM cad_device_grants WHERE id=g) THEN RAISE EXCEPTION 'Unrelated CAD permission granted'; END IF;
 UPDATE items SET quantity=100 WHERE item_id=item;
 INSERT INTO cad_projects(inventory_id,source_key,name) VALUES(i,encode(extensions.digest(gen_random_uuid()::text,'sha256'),'hex'),'Synthetic purchasing rehearsal') RETURNING id INTO project;
 INSERT INTO cad_bom_versions(inventory_id,project_id,version,request_id,request_hash,snapshot,comparison,created_by)
 VALUES(i,project,1,gen_random_uuid(),repeat('a',64),'{}','{}',a) RETURNING id INTO bom;
 v:=findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('a',64),NULL,'create',NULL,
 jsonb_build_object('bom_version_id',bom,'name','Synthetic purchasing rehearsal','inventory_as_of',now(),'lines',jsonb_build_array(jsonb_build_object('id',line,'quantity',2,'received',0,'quotes','[]'::jsonb,'selected_quote',NULL))));
 p:=(v->>'id')::uuid; IF p IS NULL THEN RAISE EXCEPTION 'Create failed'; END IF;
 v:=findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('b',64),p,'quote',1,jsonb_build_object('line_id',line,'quote',
 jsonb_build_object('id',q,'valid_until',now()+interval '1 day','availability','in_stock','estimate',jsonb_build_object('order_quantity',2))));
 v:=findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('c',64),p,'select_quote',2,jsonb_build_object('line_id',line,'quote_id',q));
 v:=findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('d',64),p,'approve',3,'{}');
 v:=findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('e',64),p,'order',4,'{"order_reference":"Synthetic rehearsal only"}');
 v:=findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('f',64),p,'receive',5,jsonb_build_object('line_id',line,'quantity',2,'item_id',item,'identity_confirmed',true));
 IF (SELECT quantity FROM items WHERE item_id=item)<>102 OR (SELECT state FROM cad_purchase_plans WHERE id=p)<>'completed'
 OR NOT EXISTS(SELECT 1 FROM item_events WHERE item_id=item AND quantity_delta=2 AND content='Received CAD purchase plan '||p::text)
 OR NOT EXISTS(SELECT 1 FROM app_access_audit WHERE actor_id=a AND inventory_id=i AND target_id=item AND action='item_update')
 THEN RAISE EXCEPTION 'Receiving or audit failed'; END IF;
 UPDATE cad_device_grants SET revoked_at=now() WHERE id=g;
 IF findez_cad_native_purchase_action(a,i,g,gen_random_uuid(),repeat('a',64),p,'receive',6,'{}')->>'error'<>'forbidden' THEN RAISE EXCEPTION 'Revoked session wrote'; END IF;
END $$;
ROLLBACK;

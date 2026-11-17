\set ON_ERROR_STOP on
-- Fresh disposable database only. Reuse the existing session/BOM fixtures.
\ir cad_bom_generation.sql
ALTER TABLE items ADD COLUMN quantity integer DEFAULT 0;
ALTER TABLE items ADD COLUMN user_id uuid;
CREATE TABLE item_events(event_id uuid DEFAULT gen_random_uuid(),item_id uuid,user_id uuid,inventory_id uuid,event_type text,content text,quantity_delta integer);
\ir ../../supabase/migrations/20261117_cad_purchasing.sql
UPDATE test_roles SET role='editor';
INSERT INTO items(item_id,inventory_id,quantity,user_id) VALUES
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001',10,'00000000-0000-0000-0000-000000000001');
DO $$
DECLARE a uuid:='00000000-0000-0000-0000-000000000001'; i uuid:='10000000-0000-0000-0000-000000000001';
 p uuid; b uuid; r uuid:=gen_random_uuid(); l uuid:=gen_random_uuid(); q uuid:=gen_random_uuid(); v jsonb; data jsonb;
BEGIN
 IF has_table_privilege('authenticated','cad_purchase_plans','SELECT') OR has_table_privilege('anon','cad_purchase_events','SELECT')
 OR has_function_privilege('authenticated','findez_cad_purchase_action(uuid,uuid,uuid,text,uuid,text,integer,jsonb)','EXECUTE')
 THEN RAISE EXCEPTION 'purchasing exposed'; END IF;
 SELECT id INTO b FROM cad_bom_versions LIMIT 1;
 data:=jsonb_build_object('bom_version_id',b,'name','Robot','inventory_as_of',now(),'lines',jsonb_build_array(
  jsonb_build_object('id',l,'quantity',3,'received',0,'quotes','[]'::jsonb,'selected_quote',NULL)));
 v:=findez_cad_purchase_action(a,i,r,repeat('a',64),NULL,'create',NULL,data);p:=(v->>'id')::uuid;
 IF p IS NULL THEN RAISE EXCEPTION 'create %',v; END IF;
 v:=findez_cad_purchase_action(a,i,r,repeat('a',64),NULL,'create',NULL,'{}');
 IF v->>'id'<>p::text OR v->>'replayed'<>'true' THEN RAISE EXCEPTION 'create retry'; END IF;
 IF findez_cad_purchase_action(a,i,r,repeat('b',64),NULL,'create',NULL,data)->>'error'<>'conflict' THEN RAISE EXCEPTION 'changed retry'; END IF;
 IF findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('b',64),NULL,'create',NULL,data)->>'error'<>'active_plan' THEN RAISE EXCEPTION 'duplicate project plan'; END IF;
 IF findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('b',64),p,'approve',1,'{}')->>'error'<>'approval_required' THEN RAISE EXCEPTION 'editor approved'; END IF;
 UPDATE test_roles SET role='admin';
 IF findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('b',64),p,'approve',1,'{}')->>'error'<>'quote_unavailable' THEN RAISE EXCEPTION 'unpriced approved'; END IF;
 data:=jsonb_build_object('line_id',l,'quote',jsonb_build_object('id',q,'valid_until',now()+interval '1 day','availability','in_stock','estimate',jsonb_build_object('order_quantity',4)));
 v:=findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('b',64),p,'quote',1,data);
 IF v->>'id' IS NULL THEN RAISE EXCEPTION 'quote %',v; END IF;
 IF findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('b',64),p,'select_quote',1,jsonb_build_object('line_id',l,'quote_id',q))->>'error'<>'stale' THEN RAISE EXCEPTION 'stale update'; END IF;
 v:=findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('b',64),p,'select_quote',2,jsonb_build_object('line_id',l,'quote_id',q));
 v:=findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('b',64),p,'approve',3,'{}');
 v:=findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('b',64),p,'order',4,'{"order_reference":"Supplier PO 123"}');
 IF (SELECT state FROM cad_purchase_plans WHERE id=p)<>'ordered' THEN RAISE EXCEPTION 'order %',v; END IF;
 IF (SELECT quantity FROM items WHERE item_id='20000000-0000-0000-0000-000000000002')<>10 THEN RAISE EXCEPTION 'ordering changed stock'; END IF;
 UPDATE test_roles SET role='editor';
 r:=gen_random_uuid();data:=jsonb_build_object('line_id',l,'item_id','20000000-0000-0000-0000-000000000001','quantity',2,'identity_confirmed',true);
 IF findez_cad_purchase_action(a,i,r,repeat('c',64),p,'receive',5,data)->>'error'<>'not_found' THEN RAISE EXCEPTION 'foreign inventory receiving'; END IF;
 data:=jsonb_set(data,'{item_id}','"20000000-0000-0000-0000-000000000002"');
 v:=findez_cad_purchase_action(a,i,r,repeat('c',64),p,'receive',5,data);
 v:=findez_cad_purchase_action(a,i,r,repeat('c',64),p,'receive',5,data);
 IF v->>'replayed'<>'true' OR (SELECT quantity FROM items WHERE item_id='20000000-0000-0000-0000-000000000002')<>12
 OR (SELECT count(*) FROM item_events)<>1 THEN RAISE EXCEPTION 'receipt retry duplicated stock'; END IF;
 IF findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('d',64),p,'receive',6,jsonb_set(data,'{quantity}','3'))->>'error'<>'over_receipt' THEN RAISE EXCEPTION 'over receipt accepted'; END IF;
 UPDATE test_roles SET role='viewer';
 IF findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('d',64),p,'receive',6,data)->>'error'<>'forbidden' THEN RAISE EXCEPTION 'revoked writer'; END IF;
 UPDATE test_roles SET role='editor';
 v:=findez_cad_purchase_action(a,i,gen_random_uuid(),repeat('d',64),p,'receive',6,data);
 IF (SELECT state FROM cad_purchase_plans WHERE id=p)<>'completed' OR (SELECT quantity FROM items WHERE item_id='20000000-0000-0000-0000-000000000002')<>14
 THEN RAISE EXCEPTION 'completion %',v; END IF;
END $$;
SELECT 'Purchase authorization, quote approval, state transitions, partial receipts and retry safety passed';

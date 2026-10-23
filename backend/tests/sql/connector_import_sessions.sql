\set ON_ERROR_STOP on
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.check(p_condition boolean, p_name text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p_condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAILED: %',p_name; END IF; END $$;
DO $$
DECLARE actor uuid:=gen_random_uuid(); other_actor uuid:=gen_random_uuid(); inv uuid; sp uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid(); r jsonb; choices jsonb; saved uuid; bulk_sid uuid:=gen_random_uuid(); bulk_rows jsonb; bulk_choices jsonb;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(actor,actor||'@connector.test'),(other_actor,other_actor||'@connector.test');
 inv:=(public.findez_create_inventory(actor,NULL,'Connector QA','workspace')->>'inventory_id')::uuid;
 INSERT INTO public.spaces(id,user_id,inventory_id,name) VALUES(sp,actor,inv,'Storage');
 INSERT INTO public.connector_import_sessions(id,actor_id,owner_id,inventory_id,location,filename,source_hash,kind,tables,revision,status,review)
 VALUES(sid,actor,actor,inv,'Storage','test.csv','synthetic','inventory','[]',1,'review',jsonb_build_array(
  jsonb_build_object('index',0,'errors','[]'::jsonb,'duplicates','[]'::jsonb,'duplicate_rows','[]'::jsonb,'item',jsonb_build_object('name','Battery','category','Supplies','quantity',10,'space_id',sp,'location','Storage')),
  jsonb_build_object('index',1,'errors','[]'::jsonb,'duplicates','[]'::jsonb,'duplicate_rows','[]'::jsonb,'item',jsonb_build_object('name','Cable','category','Supplies','quantity',4,'space_id',gen_random_uuid(),'location','Missing')),
  jsonb_build_object('index',2,'errors',jsonb_build_array('Missing name'),'duplicates','[]'::jsonb,'duplicate_rows','[]'::jsonb,'item','{}'::jsonb)
 ));
 choices:='{"0":"create","1":"create","2":"skip"}';
 BEGIN
  PERFORM public.findez_commit_connector_import(other_actor,sid,1,choices);
  RAISE EXCEPTION 'cross-user import accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.findez_commit_connector_import(actor,sid,0,choices);
  RAISE EXCEPTION 'stale revision accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  PERFORM public.findez_commit_connector_import(actor,sid,1,choices,NULL,false,'{"limit":0}');
  RAISE EXCEPTION 'zero quota accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'CONNECTOR_IMPORT_LIMIT' THEN RAISE; END IF;
 END;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.items WHERE inventory_id=inv),'quota failure writes no items');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.usage_limits WHERE user_id=actor),'quota failure rolls back counter');
 r:=public.findez_commit_connector_import(actor,sid,1,choices,NULL,false,'{"limit":2}');
 PERFORM pg_temp.check(r->'receipts'->'0'->>'status'='imported','valid row saved');
 PERFORM pg_temp.check(r->'receipts'->'1'->>'status'='failed','partial failure explicit');
 PERFORM pg_temp.check(r->'receipts'->'2'->>'status'='skipped','invalid row skipped');
 PERFORM pg_temp.check((SELECT count(*)=1 AND sum(quantity)=10 FROM public.items WHERE inventory_id=inv),'stock correct');
 saved:=(r->'receipts'->'0'->>'item_id')::uuid;
 PERFORM public.findez_commit_connector_import(actor,sid,1,choices);
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.items WHERE inventory_id=inv),'repeat does not duplicate');
 PERFORM pg_temp.check((SELECT count=1 FROM public.usage_limits WHERE user_id=actor AND feature='spreadsheet_import'),'one usage charge across retries');
 -- Lost responses and later edits do not cause a replay to overwrite stock.
 UPDATE public.items SET quantity=8 WHERE item_id=saved;
 PERFORM public.findez_commit_connector_import(actor,sid,1,choices,NULL,true);
 PERFORM pg_temp.check((SELECT quantity=8 FROM public.items WHERE item_id=saved),'retry preserves later stock edit');
 BEGIN
  PERFORM public.findez_commit_connector_import(actor,sid,1,'{"0":"skip","1":"skip","2":"skip"}');
  RAISE EXCEPTION 'changed decisions accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 UPDATE auth.users SET banned_until=now()+interval '1 hour' WHERE id=actor;
 BEGIN
  PERFORM public.findez_commit_connector_import(actor,sid,1,choices);
  RAISE EXCEPTION 'revoked actor accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE auth.users SET banned_until=NULL WHERE id=actor;
 PERFORM pg_temp.check(NOT has_table_privilege('authenticated','public.connector_import_sessions','SELECT'),'source rows private');
 PERFORM pg_temp.check(NOT has_function_privilege('authenticated','public.findez_commit_connector_import(uuid,uuid,integer,jsonb,integer,boolean,jsonb)','EXECUTE'),'RPC server only');
 -- Even deletion of an imported item cannot turn replay into new stock.
 DELETE FROM public.items WHERE item_id=saved;
 PERFORM public.findez_commit_connector_import(actor,sid,1,choices);
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.items WHERE item_id=saved),'receipt survives item deletion');
 -- More than one batch, exact item totals, and receipts survive replay.
 SELECT jsonb_agg(jsonb_build_object('index',n,'errors','[]'::jsonb,'duplicates','[]'::jsonb,'duplicate_rows','[]'::jsonb,'item',jsonb_build_object('name','Bulk '||n,'category','Supplies','quantity',1,'space_id',sp,'location','Storage'))),jsonb_object_agg(n::text,'create') INTO bulk_rows,bulk_choices FROM generate_series(0,200) n;
 INSERT INTO public.connector_import_sessions(id,actor_id,owner_id,inventory_id,location,filename,source_hash,kind,tables,revision,status,review)
 VALUES(bulk_sid,actor,actor,inv,'Storage','bulk.csv','synthetic-bulk','inventory','[]',1,'review',bulk_rows);
 r:=public.findez_commit_connector_import(actor,bulk_sid,1,bulk_choices,NULL,false,'{"limit":2}');
 PERFORM pg_temp.check(r->>'status'='importing','first batch remains pending');
 PERFORM pg_temp.check((SELECT count(*)=200 FROM public.items WHERE inventory_id=inv),'first batch bounded to 200');
 r:=public.findez_commit_connector_import(actor,bulk_sid,1,bulk_choices,NULL,false,'{"limit":2}');
 PERFORM pg_temp.check(r->>'status'='complete','second batch completes');
 PERFORM public.findez_commit_connector_import(actor,bulk_sid,1,bulk_choices,NULL,false,'{"limit":2}');
 PERFORM pg_temp.check((SELECT count(*)=201 FROM public.items WHERE inventory_id=inv),'batch retry exact total');
 PERFORM pg_temp.check((SELECT count=2 FROM public.usage_limits WHERE user_id=actor AND feature='spreadsheet_import'),'one charge per file, not per batch');
 PERFORM public.findez_delete_inventory_contents(actor,inv,'Connector QA');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.connector_import_sessions WHERE inventory_id=inv),'inventory deletion clears private source snapshots');
END $$;
ROLLBACK;

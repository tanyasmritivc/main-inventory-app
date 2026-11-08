-- Isolated fixture only. Never run this file on production.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
END $$;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.app_inventories(inventory_id uuid PRIMARY KEY);
CREATE TABLE public.items(item_id uuid PRIMARY KEY,inventory_id uuid REFERENCES app_inventories,
 name text,category text,subcategory text,brand text,part_number text,barcode text,image_url text);
CREATE TABLE public.personalization_profiles(user_id uuid PRIMARY KEY REFERENCES auth.users,
 enabled boolean DEFAULT true,generation bigint DEFAULT 0);
CREATE TABLE fixture_roles(actor uuid,inventory uuid,role text);
CREATE FUNCTION public.findez_inventory_role(uuid,uuid) RETURNS text LANGUAGE sql AS $$
 SELECT role FROM fixture_roles WHERE inventory=$1 AND actor=$2
$$;
CREATE FUNCTION public.findez_personalization_enabled(uuid) RETURNS boolean LANGUAGE sql AS $$
 SELECT coalesce((SELECT enabled FROM personalization_profiles WHERE user_id=$1),false)
$$;
CREATE TABLE cleanup_marker(calls integer);
INSERT INTO cleanup_marker VALUES(0);
CREATE FUNCTION public.findez_personalization_cleanup() RETURNS void LANGUAGE sql AS $$
 UPDATE cleanup_marker SET calls=calls+1
$$;
\ir ../../supabase/migrations/085_recognition_learning.sql
CREATE FUNCTION assert_true(value boolean,message text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF value IS DISTINCT FROM true THEN RAISE EXCEPTION '%',message; END IF; END $$;
INSERT INTO auth.users VALUES('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
INSERT INTO app_inventories VALUES('20000000-0000-0000-0000-000000000001'),('20000000-0000-0000-0000-000000000002');
INSERT INTO personalization_profiles(user_id) SELECT id FROM auth.users;
INSERT INTO fixture_roles VALUES
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','owner'),
 ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','editor');
DO $$ DECLARE a uuid:='10000000-0000-0000-0000-000000000001';
 b uuid:='10000000-0000-0000-0000-000000000002';inv uuid:='20000000-0000-0000-0000-000000000001';
 item uuid:='30000000-0000-0000-0000-000000000001'; ex uuid; n integer; ctx jsonb;
BEGIN
 n:=findez_recognition_observe(a,inv,0,repeat('1',64),'model','pipeline',jsonb_build_array(
  jsonb_build_object('crop_url','photo-one','image_digest',repeat('a',64),'predicted',jsonb_build_object('name','Washer','category','Hardware'))));
 PERFORM assert_true(n=1,'Prediction must persist');
 INSERT INTO items(item_id,inventory_id,name,category,image_url) VALUES(item,inv,'Washer','Hardware','photo-one');
 PERFORM assert_true(findez_recognition_review(a,inv,ARRAY[item])=0,'Unchanged model output is not a correctness label');
 UPDATE items SET name='Bearing' WHERE item_id=item;
 PERFORM assert_true(findez_recognition_review(a,inv,ARRAY[item])=1,'Confirmed identity correction must persist');
 PERFORM assert_true(findez_recognition_review(a,inv,ARRAY[item])=1,'Replay must be idempotent');
 PERFORM assert_true((SELECT count(*) FROM recognition_examples)=1,'Replay must not duplicate');
 SELECT id INTO ex FROM recognition_examples;
 PERFORM assert_true(findez_recognition_reference_allowed(a,inv,0,ex),'Valid example readable');
 PERFORM assert_true(NOT findez_recognition_reference_allowed(b,inv,0,ex),'Same-inventory coworker cannot read private examples');
 ctx:=findez_recognition_context(a,inv,repeat('2',64));
 PERFORM assert_true(jsonb_array_length(ctx->'examples')=1,'Other-photo context gets example');
 PERFORM assert_true(jsonb_array_length(findez_recognition_context(a,inv,repeat('1',64))->'examples')=0,'Same source cannot leak into evaluation');
 PERFORM assert_true(jsonb_array_length(findez_recognition_context(b,inv,repeat('2',64))->'examples')=0,'Foreign actor context empty');
 UPDATE items SET name='Changed later' WHERE item_id=item;
 PERFORM assert_true(NOT findez_recognition_reference_allowed(a,inv,0,ex),'Later edits invalidate stale examples');
 UPDATE items SET name='Bearing' WHERE item_id=item;
 UPDATE personalization_profiles SET enabled=false WHERE user_id=a;
 PERFORM assert_true(findez_recognition_context(a,inv,repeat('2',64)) IS NULL,'Memory off hides context');
 PERFORM assert_true(findez_recognition_review(a,inv,ARRAY[item])=0,'Memory off does not collect corrections');
 UPDATE personalization_profiles SET enabled=true WHERE user_id=a;
 DELETE FROM fixture_roles WHERE actor=a;
 PERFORM assert_true(NOT findez_recognition_reference_allowed(a,inv,0,ex),'Access removal immediately revokes example');
 INSERT INTO fixture_roles VALUES(a,inv,'owner');
 UPDATE personalization_profiles SET generation=1 WHERE user_id=a;
 PERFORM assert_true((SELECT count(*) FROM recognition_observations)=0,'Forget deletes predictions');
 PERFORM assert_true((SELECT count(*) FROM recognition_examples)=0,'Forget deletes labels');
 PERFORM assert_true(findez_recognition_observe(a,inv,0,repeat('1',64),'m','v','[]')=0,'Old workers cannot recreate forgotten history');
 -- Five is a holdout source group. Exact crop duplicates also remain excluded.
 n:=findez_recognition_observe(a,inv,1,'00000005'||repeat('0',56),'m','v',jsonb_build_array(
  jsonb_build_object('crop_url','photo-one','image_digest',repeat('a',64),'predicted',jsonb_build_object('name','Washer','category','Hardware'))));
 PERFORM findez_recognition_review(a,inv,ARRAY[item]);
 PERFORM assert_true((SELECT split FROM recognition_examples)='holdout','Source-group holdout partition');
 PERFORM assert_true(jsonb_array_length(findez_recognition_dataset(a,inv)->'cases')=1,'Evaluation can read own held-out correction');
 PERFORM assert_true(jsonb_array_length(findez_recognition_dataset(b,inv)->'cases')=0,'Evaluation cannot read coworker corrections');
 PERFORM assert_true(jsonb_array_length(findez_recognition_context(a,inv,repeat('2',64))->'examples')=0,'Holdouts never become prompt examples');
 n:=findez_recognition_observe(a,inv,1,repeat('1',64),'m','v',jsonb_build_array(
  jsonb_build_object('crop_url','photo-copy','image_digest',repeat('a',64),'predicted',jsonb_build_object('name','Washer','category','Hardware'))));
 INSERT INTO items(item_id,inventory_id,name,category,image_url) VALUES('30000000-0000-0000-0000-000000000002',inv,'Bearing','Hardware','photo-copy');
 PERFORM findez_recognition_review(a,inv,ARRAY['30000000-0000-0000-0000-000000000002'::uuid]);
 PERFORM assert_true(jsonb_array_length(findez_recognition_context(a,inv,repeat('2',64))->'examples')=0,'Duplicate crop cannot straddle holdout and reference');
 DELETE FROM items WHERE item_id=item;
 PERFORM assert_true((SELECT count(*) FROM recognition_examples)=1,'Deleting item removes its example');
 UPDATE recognition_observations SET created_at=now()-interval '91 days';
 PERFORM findez_personalization_cleanup();
 PERFORM assert_true((SELECT count(*) FROM recognition_observations)=0,'Scheduled retention purges old data');
 PERFORM assert_true((SELECT calls FROM cleanup_marker)=1,'Existing cleanup still runs');
 PERFORM assert_true(NOT has_table_privilege('authenticated','recognition_observations','SELECT'),'No direct client access');
 PERFORM assert_true(NOT has_function_privilege('authenticated','findez_recognition_review(uuid,uuid,uuid[])','EXECUTE'),'No client training-label RPC access');
END $$;
SELECT 'recognition learning database checks passed';

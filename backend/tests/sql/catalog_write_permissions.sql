-- Disposable database only. Also runs after the composed inventory fixture.
\set ON_ERROR_STOP on
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
CREATE TABLE IF NOT EXISTS public.parts_catalog (
 catalog_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), barcode text UNIQUE,
 canonical_name text NOT NULL, aliases text[], brand text, category text,
 subcategory text, part_number text, description text, image_urls text[], source text,
 confirmation_count integer DEFAULT 1, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now()
);
\ir ../../supabase/migrations/014_verified_parts_catalog.sql
\ir ../../supabase/migrations/018_catalog_barcode_aliases.sql
-- Reproduce the prior overly broad grants so the migration must remove them.
GRANT ALL ON public.parts_catalog,public.part_catalog_barcodes TO PUBLIC,anon,authenticated,service_role;
INSERT INTO public.parts_catalog(catalog_id,barcode,canonical_name,brand,part_number,verification_status,source)
VALUES
 ('53000000-0000-4000-8000-000000000001','123456789012','Verified A','Vendor','Part A','verified','manufacturer'),
 ('53000000-0000-4000-8000-000000000002',NULL,'Verified B','Vendor','Part B','verified','manufacturer'),
 ('53000000-0000-4000-8000-000000000003','community-code','Community label',NULL,NULL,'community','user');
INSERT INTO public.part_catalog_barcodes(barcode,catalog_id,source)
VALUES('known-alias','53000000-0000-4000-8000-000000000001','manufacturer');
CREATE TEMP TABLE catalog_before AS SELECT * FROM public.parts_catalog;
CREATE TEMP TABLE aliases_before AS SELECT * FROM public.part_catalog_barcodes;
\ir ../../supabase/migrations/053_catalog_write_permissions.sql
CREATE FUNCTION pg_temp.catalog_check(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF; RAISE NOTICE 'PASS: %',label; END $$;
SELECT pg_temp.catalog_check(NOT EXISTS((SELECT * FROM public.parts_catalog EXCEPT SELECT * FROM catalog_before) UNION ALL (SELECT * FROM catalog_before EXCEPT SELECT * FROM public.parts_catalog)),'permission migration preserves every catalog row');
SELECT pg_temp.catalog_check(NOT EXISTS((SELECT * FROM public.part_catalog_barcodes EXCEPT SELECT * FROM aliases_before) UNION ALL (SELECT * FROM aliases_before EXCEPT SELECT * FROM public.part_catalog_barcodes)),'permission migration preserves every alias');
SELECT pg_temp.catalog_check((SELECT bool_and(relrowsecurity) FROM pg_class WHERE oid IN ('public.parts_catalog'::regclass,'public.part_catalog_barcodes'::regclass)),'both shared catalog tables have RLS');
DO $$ DECLARE who text; tab text; op text; fn text; BEGIN
 FOREACH who IN ARRAY ARRAY['anon','authenticated'] LOOP
  FOREACH tab IN ARRAY ARRAY['parts_catalog','part_catalog_barcodes'] LOOP
   FOREACH op IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
    PERFORM pg_temp.catalog_check(NOT has_table_privilege(who,'public.'||tab,op),who||' lacks '||tab||' '||op);
   END LOOP;
  END LOOP;
  FOREACH fn IN ARRAY ARRAY['findez_save_community_catalog(text,jsonb,text)','findez_link_verified_barcode_alias(text,uuid)'] LOOP
   PERFORM pg_temp.catalog_check(NOT has_function_privilege(who,'public.'||fn,'EXECUTE'),who||' cannot call privileged catalog RPC');
  END LOOP;
 END LOOP;
END $$;

SET ROLE anon;
DO $$ BEGIN
 BEGIN DELETE FROM public.part_catalog_barcodes; RAISE EXCEPTION 'anonymous delete admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.part_catalog_barcodes(barcode,catalog_id) VALUES('forged','53000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'anonymous insert admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.parts_catalog SET canonical_name='Forged'; RAISE EXCEPTION 'anonymous update admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_save_community_catalog('forged','{"name":"Forged"}','user'); RAISE EXCEPTION 'anonymous RPC admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_link_verified_barcode_alias('forged','53000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'anonymous alias RPC admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"53000000-0000-4000-8000-000000000010"}',false);
SELECT pg_temp.catalog_check(EXISTS(SELECT 1 FROM public.parts_catalog WHERE barcode='123456789012'),'signed-in lookup still reads catalog');
SELECT pg_temp.catalog_check(EXISTS(SELECT 1 FROM public.part_catalog_barcodes WHERE barcode='known-alias'),'signed-in lookup still reads alias');
DO $$ BEGIN
 BEGIN UPDATE public.part_catalog_barcodes SET catalog_id='53000000-0000-4000-8000-000000000002'; RAISE EXCEPTION 'user alias reassignment admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN DELETE FROM public.parts_catalog; RAISE EXCEPTION 'user catalog delete admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_link_verified_barcode_alias('forged','53000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'user alias RPC admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_save_community_catalog('forged','{"name":"Forged"}','user'); RAISE EXCEPTION 'user community RPC admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claims','{"sub":"53000000-0000-4000-8000-000000000011"}',false);
DO $$ BEGIN
 BEGIN INSERT INTO public.parts_catalog(barcode,canonical_name) VALUES('forged','Forged'); RAISE EXCEPTION 'second user insert admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN TRUNCATE public.part_catalog_barcodes; RAISE EXCEPTION 'second user truncate admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- Test RLS independently of the privilege layer, without retaining the grant.
GRANT INSERT,UPDATE,DELETE ON public.parts_catalog,public.part_catalog_barcodes TO authenticated;
SET ROLE authenticated;
UPDATE public.parts_catalog SET canonical_name='Forged';
DELETE FROM public.part_catalog_barcodes;
DO $$ BEGIN
 BEGIN INSERT INTO public.part_catalog_barcodes(barcode,catalog_id) VALUES('forged','53000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'RLS insert admitted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
REVOKE INSERT,UPDATE,DELETE ON public.parts_catalog,public.part_catalog_barcodes FROM authenticated;
SELECT pg_temp.catalog_check((SELECT canonical_name='Verified A' FROM public.parts_catalog WHERE barcode='123456789012'),'RLS independently prevents catalog modification');
SELECT pg_temp.catalog_check(EXISTS(SELECT 1 FROM public.part_catalog_barcodes WHERE barcode='known-alias'),'RLS independently prevents alias deletion');

SET ROLE service_role;
SELECT pg_temp.catalog_check(NOT public.findez_save_community_catalog('123456789012','{"name":"Forged","verification_status":"verified"}','user'),'ordinary correction cannot modify verified canonical row');
SELECT pg_temp.catalog_check(NOT public.findez_save_community_catalog('0123456789012','{"name":"Forged"}','ai'),'EAN form cannot shadow verified UPC');
SELECT pg_temp.catalog_check(NOT public.findez_save_community_catalog('00123456789012','{"name":"Forged"}','upcitemdb'),'GTIN form cannot shadow verified UPC');
SELECT pg_temp.catalog_check(NOT public.findez_save_community_catalog('known-alias','{"name":"Forged"}','user'),'alias cannot be shadowed by a canonical community row');
SELECT pg_temp.catalog_check(NOT public.findez_save_community_catalog('fresh','{"name":"Forged"}','manufacturer'),'runtime caller cannot promote manufacturer provenance');
SELECT pg_temp.catalog_check(NOT public.findez_save_community_catalog('fresh','{"name":"Label","brand":{"invalid":true}}','user'),'invalid catalog field rejected');
SELECT pg_temp.catalog_check(NOT public.findez_save_community_catalog('', '{"name":"Label"}','user'),'empty barcode rejected');
SELECT pg_temp.catalog_check(public.findez_save_community_catalog('fresh','{"name":"Community label","verification_status":"verified","source_url":"https://forged.invalid","quantity":99}','user'),'new community learning works');
SELECT pg_temp.catalog_check((SELECT verification_status='community' AND source='user' AND source_url IS NULL FROM public.parts_catalog WHERE barcode='fresh'),'untrusted fields cannot promote verification or source evidence');
SELECT pg_temp.catalog_check(public.findez_save_community_catalog('fresh','{"name":"Corrected community label"}','user'),'community correction works');
SELECT pg_temp.catalog_check((SELECT canonical_name='Corrected community label' AND confirmation_count=2 FROM public.parts_catalog WHERE barcode='fresh'),'community confirmation count is updated transactionally');
SELECT pg_temp.catalog_check(NOT public.findez_link_verified_barcode_alias('new-label','53000000-0000-4000-8000-000000000099'),'unknown target rejected');
SELECT pg_temp.catalog_check(NOT public.findez_link_verified_barcode_alias('new-label','53000000-0000-4000-8000-000000000003'),'unverified target rejected');
SELECT pg_temp.catalog_check(public.findez_link_verified_barcode_alias(' new-label ','53000000-0000-4000-8000-000000000001'),'verified target can acquire a new alias');
SELECT pg_temp.catalog_check(public.findez_link_verified_barcode_alias('new-label','53000000-0000-4000-8000-000000000001'),'alias replay is idempotent');
SELECT pg_temp.catalog_check(NOT public.findez_link_verified_barcode_alias('new-label','53000000-0000-4000-8000-000000000002'),'alias cannot be reassigned');
SELECT pg_temp.catalog_check(NOT public.findez_link_verified_barcode_alias('123456789012','53000000-0000-4000-8000-000000000002'),'canonical barcode cannot be stolen');
SELECT pg_temp.catalog_check(NOT public.findez_link_verified_barcode_alias('00123456789012','53000000-0000-4000-8000-000000000002'),'equivalent canonical code cannot be stolen');
SELECT pg_temp.catalog_check((SELECT count(*)=1 FROM public.part_catalog_barcodes WHERE barcode='new-label'),'alias replay creates no duplicate');
SELECT pg_temp.catalog_check((SELECT canonical_name='Verified A' AND verification_status='verified' AND source='manufacturer' FROM public.parts_catalog WHERE barcode='123456789012'),'verified manufacturer row remains unchanged');
RESET ROLE;
\echo Catalog permission and provenance checks passed.

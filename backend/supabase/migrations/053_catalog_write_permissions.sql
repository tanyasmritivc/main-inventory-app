-- Shared catalog reads remain available to signed-in clients. All writes are
-- server-owned; optional community learning cannot modify verified identities.
BEGIN;

ALTER TABLE public.parts_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.part_catalog_barcodes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.parts_catalog, public.part_catalog_barcodes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.parts_catalog, public.part_catalog_barcodes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.parts_catalog, public.part_catalog_barcodes TO service_role;

DROP POLICY IF EXISTS catalog_client_read ON public.parts_catalog;
CREATE POLICY catalog_client_read ON public.parts_catalog FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS catalog_alias_client_read ON public.part_catalog_barcodes;
CREATE POLICY catalog_alias_client_read ON public.part_catalog_barcodes FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION public.findez_save_community_catalog(p_barcode text, p_data jsonb, p_source text DEFAULT 'user')
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
 code text := btrim(p_barcode);
 upc text;
 candidates text[];
 existing public.parts_catalog;
 field text;
BEGIN
 IF code IS NULL OR code = '' OR length(code) > 200 OR code ~ '[[:cntrl:]]'
 OR jsonb_typeof(p_data) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_data->'name') IS DISTINCT FROM 'string'
 OR coalesce(btrim(p_data->>'name'), '') = '' OR length(p_data->>'name') > 500
 OR p_source IS NULL OR p_source NOT IN ('user','upcitemdb','go_upc','openfoodfacts','ai') THEN
  RETURN false;
 END IF;
 FOREACH field IN ARRAY ARRAY['brand','category','subcategory','part_number'] LOOP
  IF p_data ? field AND jsonb_typeof(p_data->field) NOT IN ('string','null') THEN RETURN false; END IF;
  IF length(p_data->>field) > 200 THEN RETURN false; END IF;
 END LOOP;
 upc := CASE WHEN code ~ '^[0-9]{12}$' THEN code
             WHEN code ~ '^0[0-9]{12}$' THEN substr(code,2)
             WHEN code ~ '^00[0-9]{12}$' THEN substr(code,3) END;
 candidates := CASE WHEN upc IS NULL THEN ARRAY[code] ELSE ARRAY[upc,'0'||upc,'00'||upc] END;
 -- Alias assignment and community saving take the same lock, including all
 -- equivalent UPC/EAN/GTIN forms. A conflicting mapping is never replaced.
 PERFORM pg_advisory_xact_lock(hashtextextended('findez:catalog:'||coalesce(upc,code),0));
 IF EXISTS (SELECT 1 FROM public.part_catalog_barcodes WHERE barcode = ANY(candidates))
 OR EXISTS (SELECT 1 FROM public.parts_catalog WHERE barcode = ANY(candidates)
            AND verification_status IS DISTINCT FROM 'community') THEN RETURN false; END IF;

 SELECT * INTO existing FROM public.parts_catalog WHERE barcode = ANY(candidates)
 ORDER BY (barcode=code) DESC, barcode LIMIT 1 FOR UPDATE;
 IF FOUND THEN
  UPDATE public.parts_catalog SET
   canonical_name = btrim(p_data->>'name'), brand = p_data->>'brand',
   category = p_data->>'category', subcategory = p_data->>'subcategory',
   part_number = p_data->>'part_number', source = p_source,
   confirmation_count = coalesce(confirmation_count,0)+1, updated_at = now()
  WHERE catalog_id = existing.catalog_id AND verification_status = 'community';
 ELSE
  INSERT INTO public.parts_catalog(barcode,canonical_name,brand,category,subcategory,part_number,source,verification_status,confirmation_count)
  VALUES(code,btrim(p_data->>'name'),p_data->>'brand',p_data->>'category',p_data->>'subcategory',p_data->>'part_number',p_source,'community',1)
  ON CONFLICT (barcode) DO NOTHING;
 END IF;
 RETURN FOUND;
END $$;

CREATE OR REPLACE FUNCTION public.findez_link_verified_barcode_alias(p_barcode text, p_catalog_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
 code text := btrim(p_barcode);
 upc text;
 candidates text[];
 status text;
BEGIN
 IF code IS NULL OR code = '' OR length(code) > 200 OR code ~ '[[:cntrl:]]' OR p_catalog_id IS NULL THEN RETURN false; END IF;
 upc := CASE WHEN code ~ '^[0-9]{12}$' THEN code
             WHEN code ~ '^0[0-9]{12}$' THEN substr(code,2)
             WHEN code ~ '^00[0-9]{12}$' THEN substr(code,3) END;
 candidates := CASE WHEN upc IS NULL THEN ARRAY[code] ELSE ARRAY[upc,'0'||upc,'00'||upc] END;
 PERFORM pg_advisory_xact_lock(hashtextextended('findez:catalog:'||coalesce(upc,code),0));
 SELECT verification_status INTO status FROM public.parts_catalog WHERE catalog_id=p_catalog_id FOR SHARE;
 IF status IS DISTINCT FROM 'verified' THEN RETURN false; END IF;
 IF EXISTS(SELECT 1 FROM public.parts_catalog WHERE barcode=ANY(candidates) AND catalog_id<>p_catalog_id)
 OR EXISTS(SELECT 1 FROM public.part_catalog_barcodes WHERE barcode=ANY(candidates) AND catalog_id<>p_catalog_id) THEN RETURN false; END IF;
 INSERT INTO public.part_catalog_barcodes(barcode,catalog_id,source)
 VALUES(code,p_catalog_id,'user_confirmed_label') ON CONFLICT (barcode) DO NOTHING;
 RETURN EXISTS(SELECT 1 FROM public.part_catalog_barcodes WHERE barcode=code AND catalog_id=p_catalog_id);
END $$;

REVOKE ALL ON FUNCTION public.findez_save_community_catalog(text,jsonb,text), public.findez_link_verified_barcode_alias(text,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.findez_save_community_catalog(text,jsonb,text), public.findez_link_verified_barcode_alias(text,uuid) TO service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;

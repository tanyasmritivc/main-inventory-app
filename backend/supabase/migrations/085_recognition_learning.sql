-- Private correction examples. No cross-account training or automatic model promotion.
BEGIN;
CREATE TABLE public.recognition_observations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 generation bigint NOT NULL,
 source_digest text NOT NULL CHECK(source_digest ~ '^[a-f0-9]{64}$'),
 image_digest text NOT NULL CHECK(image_digest ~ '^[a-f0-9]{64}$'),
 crop_url text NOT NULL CHECK(length(crop_url) BETWEEN 1 AND 2048),
 predicted jsonb NOT NULL CHECK(jsonb_typeof(predicted)='object' AND octet_length(predicted::text)<=4096),
 model_version text NOT NULL CHECK(length(model_version)<=100),
 pipeline_version text NOT NULL CHECK(length(pipeline_version)<=100),
 reference_ids jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(reference_ids)='array' AND jsonb_array_length(reference_ids)<=2),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id,inventory_id,generation,crop_url)
);
CREATE INDEX recognition_observations_lookup ON public.recognition_observations(user_id,inventory_id,generation,crop_url);
CREATE INDEX recognition_observations_retention ON public.recognition_observations(created_at);
CREATE TABLE public.recognition_examples (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 observation_id uuid NOT NULL REFERENCES public.recognition_observations(id) ON DELETE CASCADE,
 item_id uuid NOT NULL REFERENCES public.items(item_id) ON DELETE CASCADE,
 corrected jsonb NOT NULL CHECK(jsonb_typeof(corrected)='object' AND octet_length(corrected::text)<=4096),
 split text NOT NULL CHECK(split IN ('reference','holdout')),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(observation_id,item_id)
);
ALTER TABLE public.recognition_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recognition_examples ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.recognition_observations,public.recognition_examples FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.recognition_observations,public.recognition_examples TO service_role;

CREATE FUNCTION public.findez_recognition_identity(p_item jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path=public AS $$
 SELECT jsonb_object_agg(k,left(btrim(coalesce(p_item->>k,'')),200))
 FROM unnest(ARRAY['name','category','subcategory','brand','part_number','barcode']) AS k
$$;

CREATE FUNCTION public.findez_recognition_observe(p_actor uuid,p_inventory uuid,p_generation bigint,
 p_source text,p_model text,p_version text,p_rows jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inserted integer;
BEGIN
 PERFORM 1 FROM public.personalization_profiles WHERE user_id=p_actor AND generation=p_generation FOR SHARE;
 IF NOT FOUND OR NOT public.findez_personalization_enabled(p_actor)
  OR public.findez_inventory_role(p_inventory,p_actor) IS NULL THEN RETURN 0; END IF;
 IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_array_length(p_rows)>500
  OR octet_length(p_rows::text)>2000000 THEN RAISE invalid_parameter_value; END IF;
 INSERT INTO public.recognition_observations(user_id,inventory_id,generation,source_digest,image_digest,
  crop_url,predicted,model_version,pipeline_version,reference_ids)
 SELECT p_actor,p_inventory,p_generation,p_source,r->>'image_digest',r->>'crop_url',
  public.findez_recognition_identity(r->'predicted'),p_model,p_version,coalesce(r->'reference_ids','[]')
 FROM jsonb_array_elements(p_rows) AS r
 ON CONFLICT(user_id,inventory_id,generation,crop_url) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 RETURN inserted;
END $$;

CREATE FUNCTION public.findez_recognition_review(p_actor uuid,p_inventory uuid,p_items uuid[]) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE gen bigint; changed integer;
BEGIN
 SELECT generation INTO gen FROM public.personalization_profiles WHERE user_id=p_actor FOR SHARE;
 IF NOT FOUND OR NOT public.findez_personalization_enabled(p_actor)
  OR public.findez_inventory_role(p_inventory,p_actor) NOT IN ('owner','admin','editor')
  OR public.findez_inventory_role(p_inventory,p_actor) IS NULL THEN RETURN 0; END IF;
 IF cardinality(p_items)>500 THEN RAISE invalid_parameter_value; END IF;
 -- Values come from confirmed database receipts, never client-supplied training labels.
 INSERT INTO public.recognition_examples(observation_id,item_id,corrected,split)
 SELECT o.id,i.item_id,public.findez_recognition_identity(to_jsonb(i)),
  CASE WHEN (('x'||substr(o.source_digest,1,8))::bit(32)::bigint % 5)=0 THEN 'holdout' ELSE 'reference' END
 FROM public.items i JOIN public.recognition_observations o
  ON o.crop_url=i.image_url AND o.inventory_id=i.inventory_id
 WHERE i.item_id=ANY(p_items) AND i.inventory_id=p_inventory AND o.user_id=p_actor AND o.generation=gen
  AND o.created_at>now()-interval '90 days'
  AND public.findez_recognition_identity(to_jsonb(i))<>o.predicted
  AND lower(btrim(i.name)) NOT IN ('','unknown','unknown item','unidentified object','unidentified item')
 ON CONFLICT(observation_id,item_id) DO UPDATE SET corrected=excluded.corrected,reviewed_at=now();
 GET DIAGNOSTICS changed=ROW_COUNT;
 -- Undoing a correction removes the old example rather than leaving a stale label.
 DELETE FROM public.recognition_examples e USING public.recognition_observations o,public.items i
 WHERE e.observation_id=o.id AND e.item_id=i.item_id AND i.item_id=ANY(p_items)
  AND o.user_id=p_actor AND o.inventory_id=p_inventory
  AND public.findez_recognition_identity(to_jsonb(i))=o.predicted;
 RETURN changed;
END $$;

CREATE FUNCTION public.findez_recognition_reference_allowed(p_actor uuid,p_inventory uuid,
 p_generation bigint,p_example uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT public.findez_personalization_enabled(p_actor)
 AND public.findez_inventory_role(p_inventory,p_actor) IS NOT NULL
 AND EXISTS(SELECT 1 FROM public.recognition_examples e
 JOIN public.recognition_observations o ON o.id=e.observation_id
 JOIN public.items i ON i.item_id=e.item_id
 JOIN public.personalization_profiles p ON p.user_id=o.user_id
 WHERE e.id=p_example AND o.user_id=p_actor AND o.inventory_id=p_inventory
 AND i.inventory_id=p_inventory AND o.generation=p_generation AND p.generation=p_generation
 AND e.split='reference' AND o.created_at>now()-interval '90 days'
 AND i.image_url=o.crop_url AND public.findez_recognition_identity(to_jsonb(i))=e.corrected)
$$;

CREATE FUNCTION public.findez_recognition_context(p_actor uuid,p_inventory uuid,p_source text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE gen bigint; examples jsonb;
BEGIN
 SELECT generation INTO gen FROM public.personalization_profiles WHERE user_id=p_actor;
 IF NOT FOUND OR NOT public.findez_personalization_enabled(p_actor)
  OR public.findez_inventory_role(p_inventory,p_actor) IS NULL THEN RETURN NULL; END IF;
 SELECT coalesce(jsonb_agg(row_to_json(rows)),'[]') INTO examples FROM (
  SELECT e.id,o.crop_url,o.image_digest,o.predicted,e.corrected
  FROM public.recognition_examples e JOIN public.recognition_observations o ON o.id=e.observation_id
  WHERE o.user_id=p_actor AND o.inventory_id=p_inventory AND o.generation=gen
   AND o.source_digest<>p_source
   AND public.findez_recognition_reference_allowed(p_actor,p_inventory,gen,e.id)
   -- An exact duplicate crop cannot straddle reference and holdout partitions.
   AND NOT EXISTS(SELECT 1 FROM public.recognition_examples held
    JOIN public.recognition_observations ho ON ho.id=held.observation_id
    WHERE held.split='holdout' AND ho.user_id=p_actor AND ho.inventory_id=p_inventory
    AND ho.image_digest=o.image_digest)
  ORDER BY e.reviewed_at DESC,e.id LIMIT 50
 ) rows;
 RETURN jsonb_build_object('generation',gen,'examples',examples);
END $$;

CREATE FUNCTION public.findez_recognition_forget() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NEW.generation<>OLD.generation THEN
  DELETE FROM public.recognition_observations WHERE user_id=NEW.user_id;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER recognition_forget AFTER UPDATE OF generation ON public.personalization_profiles
 FOR EACH ROW EXECUTE FUNCTION public.findez_recognition_forget();

CREATE FUNCTION public.findez_recognition_dataset(p_actor uuid,p_inventory uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE gen bigint; result jsonb;
BEGIN
 SELECT generation INTO gen FROM public.personalization_profiles WHERE user_id=p_actor;
 IF NOT FOUND OR NOT public.findez_personalization_enabled(p_actor)
  OR public.findez_inventory_role(p_inventory,p_actor) IS NULL THEN RETURN NULL; END IF;
 SELECT jsonb_build_object('observations',count(*)) INTO result FROM public.recognition_observations
  WHERE user_id=p_actor AND inventory_id=p_inventory AND generation=gen
  AND created_at>now()-interval '90 days';
 RETURN result || jsonb_build_object('cases',coalesce((SELECT jsonb_agg(row_to_json(rows)) FROM (
  SELECT DISTINCT ON (o.image_digest) e.id,o.source_digest,o.image_digest,o.crop_url,e.corrected AS expected
  FROM public.recognition_examples e JOIN public.recognition_observations o ON o.id=e.observation_id
  JOIN public.items i ON i.item_id=e.item_id
  WHERE o.user_id=p_actor AND o.inventory_id=p_inventory AND o.generation=gen AND e.split='holdout'
   AND i.inventory_id=p_inventory AND i.image_url=o.crop_url
   AND public.findez_recognition_identity(to_jsonb(i))=e.corrected
   AND o.created_at>now()-interval '90 days'
  ORDER BY o.image_digest,e.reviewed_at DESC LIMIT 100
 ) rows),'[]'::jsonb));
END $$;

-- Extend the existing scheduled cleanup without replacing its implementation.
ALTER FUNCTION public.findez_personalization_cleanup() RENAME TO findez_personalization_cleanup_before_recognition;
CREATE FUNCTION public.findez_personalization_cleanup() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 PERFORM public.findez_personalization_cleanup_before_recognition();
 DELETE FROM public.recognition_observations WHERE created_at<now()-interval '90 days';
END $$;

DO $$ DECLARE f regprocedure; BEGIN
 FOR f IN SELECT oid::regprocedure FROM pg_proc WHERE pronamespace='public'::regnamespace
  AND (proname LIKE 'findez_recognition_%' OR proname IN
   ('findez_personalization_cleanup','findez_personalization_cleanup_before_recognition')) LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

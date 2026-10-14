-- Human-confirmed physical context is independent of imported commerce stock.
BEGIN;
CREATE TABLE public.physical_memories (
  memory_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES public.teams ON DELETE CASCADE,
  native_label text NOT NULL CHECK (native_label=btrim(native_label) AND char_length(native_label) BETWEEN 1 AND 200 AND native_label !~ '[[:cntrl:]]'),
  created_by uuid REFERENCES auth.users ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(memory_id,team_id)
);
CREATE TABLE public.physical_commerce_links (
  memory_id uuid PRIMARY KEY REFERENCES public.physical_memories ON DELETE CASCADE,
  connection_id uuid NOT NULL,
  variant_gid text NOT NULL,
  UNIQUE(connection_id,variant_gid),
  FOREIGN KEY(connection_id,variant_gid) REFERENCES public.shopify_variants ON DELETE CASCADE
);
CREATE TABLE public.physical_placements (
  placement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memory_id uuid NOT NULL, team_id uuid NOT NULL,
  space_id uuid REFERENCES public.spaces(id) ON DELETE SET NULL,
  bin_id uuid REFERENCES public.bins(id) ON DELETE SET NULL,
  had_bin boolean NOT NULL DEFAULT false,
  status text NOT NULL CHECK (status IN ('active','removed')),
  revision integer NOT NULL CHECK (revision>0),
  observed_count integer CHECK (observed_count>=0),
  confirmed_by uuid REFERENCES auth.users ON DELETE SET NULL,
  confirmed_at timestamptz NOT NULL DEFAULT now(),
  source_kind text NOT NULL CHECK (source_kind IN ('catalog_selection','barcode_entry','manual_reconfirmation')),
  FOREIGN KEY(memory_id,team_id) REFERENCES public.physical_memories(memory_id,team_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX physical_active_destination ON public.physical_placements(memory_id,space_id,coalesce(bin_id,'00000000-0000-0000-0000-000000000000'::uuid))
  WHERE status='active' AND (NOT had_bin OR bin_id IS NOT NULL);
CREATE TABLE public.physical_observations (
  observation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES public.teams ON DELETE CASCADE,
  memory_id uuid NOT NULL REFERENCES public.physical_memories ON DELETE CASCADE,
  placement_id uuid NOT NULL REFERENCES public.physical_placements ON DELETE CASCADE,
  request_id uuid NOT NULL, actor_id uuid REFERENCES auth.users ON DELETE SET NULL,
  event_type text NOT NULL CHECK(event_type IN ('confirmed','removed')),
  revision integer NOT NULL, observed_count integer CHECK(observed_count>=0),
  space_id uuid REFERENCES public.spaces(id) ON DELETE SET NULL,
  bin_id uuid REFERENCES public.bins(id) ON DELETE SET NULL,
  space_label text, bin_label text,
  source_kind text NOT NULL,
  confirmed_at timestamptz NOT NULL DEFAULT now(),
  request_hash text NOT NULL,
  UNIQUE(team_id,request_id), UNIQUE(placement_id,revision)
);

CREATE FUNCTION public.physical_member(p_team uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'api_key_id','')=''
   AND EXISTS(SELECT 1 FROM team_memberships WHERE team_id=p_team AND user_id=auth.uid());
$$;
REVOKE ALL ON FUNCTION public.physical_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.physical_member(uuid) TO authenticated,service_role;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['physical_memories','physical_commerce_links','physical_placements','physical_observations'] LOOP
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
   EXECUTE format('REVOKE ALL ON public.%I FROM anon,authenticated',t);
   EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
 END LOOP;
END $$;
GRANT SELECT ON public.physical_memories,public.physical_placements TO authenticated;
-- Append-only receipts; deletion through parent lifecycle FKs remains possible.
REVOKE UPDATE,DELETE ON public.physical_observations FROM service_role;
CREATE FUNCTION public.physical_destination_readable(p_team uuid,p_space uuid,p_bin uuid,p_had_bin boolean)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT physical_member(p_team) AND EXISTS(SELECT 1 FROM team_spaces ts JOIN spaces s ON s.id=ts.space_id
  WHERE ts.team_id=p_team AND s.id=p_space AND (NOT p_had_bin OR EXISTS(SELECT 1 FROM bins b
    WHERE b.id=p_bin AND b.space_id=s.id AND b.user_id=s.user_id)));
$$;
REVOKE ALL ON FUNCTION public.physical_destination_readable(uuid,uuid,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.physical_destination_readable(uuid,uuid,uuid,boolean) TO authenticated,service_role;
CREATE POLICY physical_memory_member_read ON public.physical_memories FOR SELECT TO authenticated USING(physical_member(team_id));
CREATE POLICY physical_placement_member_read ON public.physical_placements FOR SELECT TO authenticated USING(
 status='active' AND physical_destination_readable(team_id,space_id,bin_id,had_bin));

CREATE FUNCTION public.physical_actor_label(p_team uuid,p_actor uuid) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT CASE WHEN p_actor IS NULL THEN 'Deleted account'
  WHEN NOT EXISTS(SELECT 1 FROM team_memberships WHERE team_id=p_team AND user_id=p_actor) THEN 'Former Team member'
  ELSE coalesce((SELECT coalesce(nullif(btrim(display_name),''),nullif(btrim(first_name),'')) FROM profiles WHERE id=p_actor),'Team member') END;
$$;
CREATE FUNCTION public.physical_options(p_team uuid,p_actor uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE member_role text; BEGIN
 SELECT role INTO member_role FROM team_memberships WHERE team_id=p_team AND user_id=p_actor;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','permission'); END IF;
 RETURN jsonb_build_object('can_confirm',member_role IN ('owner','mentor','member'),'spaces',coalesce((
  SELECT jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'bins',coalesce((SELECT jsonb_agg(jsonb_build_object('id',b.id,'name',b.name) ORDER BY b.name)
   FROM bins b WHERE b.space_id=s.id AND b.user_id=s.user_id),'[]')) ORDER BY s.name)
  FROM team_spaces ts JOIN spaces s ON s.id=ts.space_id WHERE ts.team_id=p_team),'[]'));
END $$;

CREATE FUNCTION public.physical_confirm(p_team uuid,p_actor uuid,p_request uuid,p_payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE member_role text; c shopify_connections; v shopify_variants; m physical_memories;
 p physical_placements; e physical_observations; s spaces; b bins;
 mid uuid:=(p_payload->>'memory_id')::uuid; pid uuid:=(p_payload->>'placement_id')::uuid;
 cid uuid:=(p_payload->>'connection_id')::uuid; variant text:=p_payload->>'variant_gid';
 expected integer:=(p_payload->>'expected_revision')::integer; kind text; remove_it boolean:=p_payload->>'action'='remove';
BEGIN
 -- Store lock precedes native records, so disconnect cannot leave a dangling link.
 IF cid IS NOT NULL THEN
  SELECT * INTO c FROM shopify_connections WHERE connection_id=cid AND team_id=p_team FOR UPDATE;
 END IF;
 PERFORM 1 FROM teams WHERE team_id=p_team FOR UPDATE;
 SELECT role INTO member_role FROM team_memberships WHERE team_id=p_team AND user_id=p_actor FOR SHARE;
 IF NOT FOUND OR member_role NOT IN ('owner','mentor','member') THEN RETURN jsonb_build_object('error','permission'); END IF;
 SELECT * INTO e FROM physical_observations WHERE team_id=p_team AND request_id=p_request;
 IF FOUND THEN
  IF e.actor_id IS DISTINCT FROM p_actor OR e.request_hash<>encode(digest(p_payload::text,'sha256'),'hex') THEN RETURN jsonb_build_object('error','idempotency_conflict'); END IF;
  RETURN jsonb_build_object('memory_id',e.memory_id,'placement_id',e.placement_id,'revision',e.revision,'observation_id',e.observation_id);
 END IF;
 IF cid IS NOT NULL THEN
  IF c.connection_id IS NULL OR c.status NOT IN ('connected','reconnect_required') THEN RETURN jsonb_build_object('error','catalog_unavailable'); END IF;
  SELECT * INTO v FROM shopify_variants WHERE connection_id=cid AND variant_gid=variant AND deleted_at IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('error','catalog_unavailable'); END IF;
  SELECT memory_id INTO mid FROM physical_commerce_links WHERE connection_id=cid AND variant_gid=variant;
 END IF;
 IF mid IS NOT NULL THEN
  SELECT * INTO m FROM physical_memories WHERE memory_id=mid AND team_id=p_team FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error','missing'); END IF;
 ELSE
  IF remove_it OR cid IS NULL THEN RETURN jsonb_build_object('error','missing'); END IF;
  -- This label is explicitly authored by the employee, not copied by a sync.
  m.memory_id:=gen_random_uuid(); m.team_id:=p_team; m.native_label:=p_payload->>'native_label';
 END IF;
 IF p_payload->>'native_label' IS DISTINCT FROM m.native_label THEN RETURN jsonb_build_object('error','label_conflict'); END IF;
 IF pid IS NOT NULL THEN
  SELECT * INTO p FROM physical_placements WHERE placement_id=pid AND memory_id=m.memory_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error','missing'); END IF;
  IF p.revision<>expected THEN RETURN jsonb_build_object('error','revision_conflict'); END IF;
  IF remove_it AND p.status<>'active' THEN RETURN jsonb_build_object('error','revision_conflict'); END IF;
 ELSE
  IF expected<>0 OR remove_it THEN RETURN jsonb_build_object('error','revision_conflict'); END IF;
 END IF;
 IF NOT remove_it THEN
  SELECT s0.* INTO s FROM spaces s0 JOIN team_spaces ts ON ts.space_id=s0.id
   WHERE ts.team_id=p_team AND s0.id=(p_payload->>'space_id')::uuid FOR SHARE OF ts,s0;
  IF NOT FOUND THEN RETURN jsonb_build_object('error','destination'); END IF;
  IF p_payload->>'bin_id' IS NOT NULL THEN
   SELECT * INTO b FROM bins WHERE id=(p_payload->>'bin_id')::uuid AND space_id=s.id AND user_id=s.user_id FOR SHARE;
   IF NOT FOUND THEN RETURN jsonb_build_object('error','destination'); END IF;
  END IF;
  IF EXISTS(SELECT 1 FROM physical_placements WHERE memory_id=m.memory_id AND space_id=s.id
   AND bin_id IS NOT DISTINCT FROM b.id AND status='active' AND (NOT had_bin OR bin_id IS NOT NULL)
   AND placement_id IS DISTINCT FROM pid) THEN RETURN jsonb_build_object('error','destination_conflict'); END IF;
 ELSE
  SELECT * INTO e FROM physical_observations WHERE placement_id=p.placement_id ORDER BY revision DESC LIMIT 1;
  s.name:=e.space_label; b.name:=e.bin_label;
 END IF;
 kind:=CASE WHEN cid IS NULL THEN 'manual_reconfirmation' WHEN p_payload->>'barcode' IS NULL THEN 'catalog_selection' ELSE 'barcode_entry' END;
 IF cid IS NOT NULL AND p_payload->>'barcode' IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM jsonb_array_elements(v.barcodes) x WHERE x->>'value'=p_payload->>'barcode') THEN
   RETURN jsonb_build_object('error','barcode_conflict'); END IF;
 IF m.created_at IS NULL THEN
  INSERT INTO physical_memories(memory_id,team_id,native_label,created_by) VALUES(m.memory_id,p_team,m.native_label,p_actor);
  INSERT INTO physical_commerce_links VALUES(m.memory_id,cid,variant);
 END IF;
 IF pid IS NULL THEN
  INSERT INTO physical_placements(memory_id,team_id,space_id,bin_id,had_bin,status,revision,observed_count,confirmed_by,source_kind)
   VALUES(m.memory_id,p_team,s.id,b.id,b.id IS NOT NULL,'active',1,(p_payload->>'observed_count')::integer,p_actor,kind) RETURNING * INTO p;
 ELSE
  UPDATE physical_placements SET space_id=CASE WHEN remove_it THEN space_id ELSE s.id END,
   bin_id=CASE WHEN remove_it THEN bin_id ELSE b.id END,had_bin=CASE WHEN remove_it THEN had_bin ELSE b.id IS NOT NULL END,
   status=CASE WHEN remove_it THEN 'removed' ELSE 'active' END,revision=revision+1,
   observed_count=CASE WHEN remove_it THEN NULL ELSE (p_payload->>'observed_count')::integer END,
   confirmed_by=p_actor,confirmed_at=now(),source_kind=kind WHERE placement_id=pid RETURNING * INTO p;
 END IF;
 INSERT INTO physical_observations(team_id,memory_id,placement_id,request_id,actor_id,event_type,revision,observed_count,
   space_id,bin_id,space_label,bin_label,source_kind,request_hash)
  VALUES(p_team,m.memory_id,p.placement_id,p_request,p_actor,CASE WHEN remove_it THEN 'removed' ELSE 'confirmed' END,
   p.revision,p.observed_count,p.space_id,p.bin_id,s.name,b.name,kind,encode(digest(p_payload::text,'sha256'),'hex')) RETURNING * INTO e;
 RETURN jsonb_build_object('memory_id',m.memory_id,'placement_id',p.placement_id,'revision',p.revision,'observation_id',e.observation_id);
END $$;

CREATE FUNCTION public.physical_normalize(p_text text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$
 SELECT regexp_replace(regexp_replace(regexp_replace(lower(coalesce(p_text,'')),'\mmedium\M','m','g'),'\mlarge\M','l','g'),'\msmall\M','s','g');
$$;
CREATE FUNCTION public.physical_lookup(p_team uuid,p_actor uuid,p_tokens text[] DEFAULT '{}',p_barcode text DEFAULT NULL,
 p_bin text DEFAULT NULL,p_space text DEFAULT NULL,p_memory uuid DEFAULT NULL,p_connection uuid DEFAULT NULL,p_variant text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE result jsonb; BEGIN
 IF NOT EXISTS(SELECT 1 FROM team_memberships WHERE team_id=p_team AND user_id=p_actor) THEN RETURN jsonb_build_object('error','permission'); END IF;
 WITH subjects AS (
  SELECT m.memory_id,m.native_label,l.connection_id,l.variant_gid,v.product_title,v.variant_title,v.sku,v.barcodes,v.options,
   v.inventory_item_gid,v.tracked,v.deleted_at,coalesce(c.status,'disconnected') AS connection_status
   FROM physical_memories m LEFT JOIN physical_commerce_links l USING(memory_id)
    LEFT JOIN shopify_variants v ON v.connection_id=l.connection_id AND v.variant_gid=l.variant_gid
    LEFT JOIN shopify_connections c ON c.connection_id=l.connection_id WHERE m.team_id=p_team
  UNION ALL
  SELECT NULL,NULL,v.connection_id,v.variant_gid,v.product_title,v.variant_title,v.sku,v.barcodes,v.options,v.inventory_item_gid,v.tracked,v.deleted_at,c.status
   FROM shopify_variants v JOIN shopify_connections c USING(connection_id)
   WHERE c.team_id=p_team AND v.deleted_at IS NULL AND c.status IN ('connected','reconnect_required') AND NOT EXISTS(
    SELECT 1 FROM physical_commerce_links l WHERE l.connection_id=v.connection_id AND l.variant_gid=v.variant_gid)
 ), matching AS (
  SELECT *,physical_normalize(concat_ws(' ',native_label,product_title,variant_title,sku,options::text)) AS searchable FROM subjects
 ), selected AS (
  SELECT * FROM matching x WHERE
   (p_memory IS NULL OR x.memory_id=p_memory) AND (p_connection IS NULL OR x.connection_id=p_connection)
   AND (p_variant IS NULL OR x.variant_gid=p_variant)
   AND (p_barcode IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(x.barcodes,'[]')) b WHERE b->>'value'=p_barcode))
   AND (p_memory IS NOT NULL OR p_variant IS NOT NULL OR NOT EXISTS(SELECT 1 FROM unnest(p_tokens) token
     WHERE NOT physical_normalize(token)=ANY(regexp_split_to_array(x.searchable,'[^[:alnum:]_-]+'))))
   AND ((p_bin IS NULL AND p_space IS NULL) OR EXISTS(SELECT 1 FROM physical_placements p JOIN team_spaces ts ON ts.team_id=p_team AND ts.space_id=p.space_id
    JOIN spaces s ON s.id=p.space_id LEFT JOIN bins b ON b.id=p.bin_id AND b.space_id=s.id AND b.user_id=s.user_id
    WHERE p.memory_id=x.memory_id AND p.status='active' AND (NOT p.had_bin OR b.id IS NOT NULL)
    AND (p_bin IS NULL OR lower(b.name)=lower(p_bin) OR lower(b.name)=lower('Bin '||p_bin))
    AND (p_space IS NULL OR lower(s.name)=lower(p_space))))
  ORDER BY coalesce(native_label,product_title),variant_title,memory_id LIMIT 21
 ) SELECT coalesce(jsonb_agg(jsonb_build_object('memory_id',x.memory_id,'native_label',x.native_label,
   'connection_id',x.connection_id,'variant_gid',x.variant_gid,'product_title',x.product_title,'variant_title',x.variant_title,
   'sku',x.sku,'barcodes',x.barcodes,'options',x.options,'catalog_deleted',x.deleted_at IS NOT NULL,'connection_status',x.connection_status,
   'tracked',x.tracked,'placements',coalesce((SELECT jsonb_agg(jsonb_build_object('placement_id',p.placement_id,'revision',p.revision,
     'space_id',s.id,'space_name',s.name,'bin_id',b.id,'bin_name',b.name,'observed_count',p.observed_count,
     'actor_id',p.confirmed_by,'actor_label',physical_actor_label(p_team,p.confirmed_by),'confirmed_at',p.confirmed_at,'source_kind',p.source_kind)
     ORDER BY p.confirmed_at DESC) FROM physical_placements p JOIN team_spaces ts ON ts.team_id=p_team AND ts.space_id=p.space_id
      JOIN spaces s ON s.id=p.space_id LEFT JOIN bins b ON b.id=p.bin_id AND b.space_id=s.id AND b.user_id=s.user_id
     WHERE p.memory_id=x.memory_id AND p.status='active' AND (NOT p.had_bin OR b.id IS NOT NULL)
     AND (p_bin IS NULL OR lower(b.name)=lower(p_bin) OR lower(b.name)=lower('Bin '||p_bin))
     AND (p_space IS NULL OR lower(s.name)=lower(p_space))),'[]'),
   'shopify_inventory',coalesce((SELECT jsonb_agg(jsonb_build_object('location_name',il.location_name,'quantities',il.quantities,'synced_at',il.synced_at))
     FROM shopify_inventory_levels il WHERE il.connection_id=x.connection_id AND il.inventory_item_gid=x.inventory_item_gid AND x.deleted_at IS NULL),'[]')
  )),'[]') INTO result FROM selected x;
 RETURN jsonb_build_object('candidates',result,'truncated',jsonb_array_length(result)>20);
END $$;

CREATE FUNCTION public.physical_history(p_team uuid,p_actor uuid,p_placement uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM team_memberships WHERE team_id=p_team AND user_id=p_actor) THEN RETURN jsonb_build_object('error','permission'); END IF;
 RETURN jsonb_build_object('observations',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (
  SELECT o.observation_id,o.event_type,o.revision,o.observed_count,o.space_label,o.bin_label,o.source_kind,o.confirmed_at,o.actor_id,
   physical_actor_label(p_team,o.actor_id) AS actor_label FROM physical_observations o
   WHERE o.team_id=p_team AND o.placement_id=p_placement AND EXISTS(SELECT 1 FROM team_spaces WHERE team_id=p_team AND space_id=o.space_id)
   ORDER BY o.revision DESC LIMIT 100) x),'[]'));
END $$;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT oid::regprocedure AS signature FROM pg_proc WHERE pronamespace='public'::regnamespace
  AND proname LIKE 'physical_%' AND proname NOT IN ('physical_member','physical_destination_readable') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.signature);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

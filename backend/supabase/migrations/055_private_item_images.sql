-- Private image delivery preserves every existing object/path and record value.
-- Apply with the compatible authenticated web/mobile image loaders.
BEGIN;
CREATE TABLE IF NOT EXISTS public.app_image_previews (
 storage_path text PRIMARY KEY, actor_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
 inventory_id uuid REFERENCES public.app_inventories ON DELETE CASCADE,
 expires_at timestamptz NOT NULL DEFAULT now()+interval '24 hours'
);
ALTER TABLE public.app_image_previews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_image_previews FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.app_image_previews TO service_role;

CREATE OR REPLACE FUNCTION public.findez_item_image_path(p_url text) RETURNS text
LANGUAGE plpgsql IMMUTABLE SET search_path=public AS $$
DECLARE tail text; output bytea:=''::bytea; pos integer:=1; ch text; decoded text;
BEGIN
 IF p_url!~'^(https?://[^/]+)?/storage/v1/object/' THEN RETURN NULL; END IF;
 tail:=substring(split_part(p_url,'?',1) FROM '/storage/v1/object/(?:public/|sign/|authenticated/)?item-images/(.+)$');
 IF tail IS NULL THEN RETURN NULL; END IF;
 WHILE pos<=length(tail) LOOP
  ch:=substr(tail,pos,1);
  IF ch='%' THEN
   IF substr(tail,pos+1,2)!~'^[0-9a-fA-F]{2}$' THEN RETURN NULL; END IF;
   output:=output||decode(substr(tail,pos+1,2),'hex'); pos:=pos+3;
  ELSE output:=output||convert_to(ch,'UTF8'); pos:=pos+1; END IF;
 END LOOP;
 decoded:=convert_from(output,'UTF8');
 IF decoded!~'^[0-9a-fA-F-]{36}/' OR decoded~'(^|/)(\.|\.\.)?(/|$)' OR decoded~'[\\\x00-\x1f]' OR decoded~'%[0-9a-fA-F]{2}' THEN RETURN NULL; END IF;
 RETURN decoded;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.findez_item_image_path(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_item_image_path(text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.findez_image_paths(p_value jsonb) RETURNS SETOF text
LANGUAGE sql IMMUTABLE SET search_path=public AS $$
 WITH RECURSIVE nodes(value) AS (
  SELECT p_value UNION ALL
  SELECT child.value FROM nodes n CROSS JOIN LATERAL (
   SELECT value FROM jsonb_each(CASE WHEN jsonb_typeof(n.value)='object' THEN n.value ELSE '{}'::jsonb END)
   UNION ALL SELECT value FROM jsonb_array_elements(CASE WHEN jsonb_typeof(n.value)='array' THEN n.value ELSE '[]'::jsonb END)
  ) child
 ) SELECT DISTINCT path FROM nodes CROSS JOIN LATERAL (
  SELECT public.findez_item_image_path(value#>>'{}') AS path
 ) parsed WHERE jsonb_typeof(value)='string' AND path IS NOT NULL
$$;
REVOKE ALL ON FUNCTION public.findez_image_paths(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_image_paths(jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_record_image_paths(p_record jsonb) RETURNS SETOF text
LANGUAGE sql IMMUTABLE SET search_path=public AS $$
 SELECT public.findez_image_paths(jsonb_build_object('image_url',p_record->'image_url',
  'source_frame_url',p_record->'source_frame_url','scan_evidence',p_record->'scan_evidence',
  'answer_context',p_record->'answer_context'))
 UNION SELECT public.findez_item_image_path('/storage/v1/object/public/item-images/'||(p_record->'answer_context'->>'photo_path'))
 WHERE p_record->'answer_context'->>'photo_path' IS NOT NULL
$$;
REVOKE ALL ON FUNCTION public.findez_record_image_paths(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_record_image_paths(jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_shared_item_image(p_actor uuid,p_item jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE allowed boolean;
BEGIN
 IF to_regclass('public.team_members') IS NULL OR NOT EXISTS(SELECT 1 FROM public.app_inventories
  WHERE inventory_id=(p_item->>'inventory_id')::uuid AND team_id IS NULL AND access_mode='legacy') THEN RETURN false; END IF;
 EXECUTE $query$SELECT EXISTS(SELECT 1 FROM public.team_shares s JOIN public.team_members m USING(share_id)
  WHERE m.member_user_id=$1 AND coalesce(to_jsonb(s)->>'is_active','true')='true'
  AND s.owner_user_id=($2->>'user_id')::uuid
  AND (s.space_id=($2->>'space_id')::uuid OR s.space_id IS NULL AND s.share_name=$2->>'location'))$query$
 INTO allowed USING p_actor,p_item;
 RETURN coalesce(allowed,false);
END $$;
REVOKE ALL ON FUNCTION public.findez_shared_item_image(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_shared_item_image(uuid,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_can_read_item_image(p_actor uuid,p_path text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT public.findez_actor_active(p_actor) AND (
  EXISTS(SELECT 1 FROM public.items i WHERE public.findez_item_image_path(i.image_url)=p_path
   AND (public.findez_inventory_role(i.inventory_id,p_actor) IS NOT NULL OR public.findez_shared_item_image(p_actor,to_jsonb(i))))
  OR EXISTS(SELECT 1 FROM public.item_events e JOIN public.items i USING(item_id)
   WHERE public.findez_item_image_path(e.image_url)=p_path
   AND (public.findez_inventory_role(i.inventory_id,p_actor) IS NOT NULL OR public.findez_shared_item_image(p_actor,to_jsonb(i))))
  OR EXISTS(SELECT 1 FROM public.capture_reviews r WHERE p_path IN (SELECT public.findez_record_image_paths(to_jsonb(r)))
   AND public.findez_inventory_role(r.inventory_id,p_actor) IS NOT NULL
   AND coalesce(to_jsonb(r)->>'status','pending')='pending'
   AND (r.user_id=p_actor OR coalesce(to_jsonb(r)->>'inventory_visibility','personal')='inventory'))
  OR EXISTS(SELECT 1 FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id JOIN public.app_inventories ci ON ci.inventory_id=c.inventory_id
   WHERE c.user_id=p_actor AND public.findez_inventory_role(c.inventory_id,p_actor) IS NOT NULL
   AND (p_path~('^[a-fA-F0-9-]{36}/'||c.inventory_id::text||'-[a-f0-9]{32}-ask-[a-f0-9]{32}\.jpg$')
    OR p_path~('^'||p_actor::text||'/(?:[a-f0-9]{32}-)?ask-[a-f0-9]{32}\.jpg$'))
   AND to_jsonb(m)->'answer_context'->>'photo_path'=p_path)
  OR EXISTS(SELECT 1 FROM public.app_image_previews p WHERE p.storage_path=p_path AND p.actor_id=p_actor AND p.expires_at>now()
   AND (p.inventory_id IS NULL OR public.findez_inventory_role(p.inventory_id,p_actor) IS NOT NULL))
 )
$$;
REVOKE ALL ON FUNCTION public.findez_can_read_item_image(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_can_read_item_image(uuid,text) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_register_image_preview(p_actor uuid,p_inventory uuid,p_path text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT public.findez_actor_active(p_actor) OR public.findez_item_image_path('/storage/v1/object/public/item-images/'||p_path) IS DISTINCT FROM p_path
  OR (p_inventory IS NOT NULL AND public.findez_inventory_role(p_inventory,p_actor) IS NULL) THEN RAISE insufficient_privilege; END IF;
 -- Service-only callers generate a new unguessable path for every upload.
 INSERT INTO public.app_image_previews(storage_path,actor_id,inventory_id) VALUES(p_path,p_actor,p_inventory);
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.findez_register_image_preview(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_register_image_preview(uuid,uuid,text) TO service_role;

-- Referencing a private image must not turn knowledge of its URL into access.
-- Persisted photos stop using temporary preview grants; deletions immediately
-- remove their authorization through the current source rows above.
CREATE OR REPLACE FUNCTION public.findez_guard_item_image_reference() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor(); path text;
BEGIN
 FOR path IN SELECT public.findez_record_image_paths(to_jsonb(NEW)) LOOP
  IF actor IS NOT NULL AND NOT public.findez_can_read_item_image(actor,path) THEN
   RAISE insufficient_privilege USING message='You do not have access to this image. Upload your own photo.';
  END IF;
 END LOOP;
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION public.findez_consume_image_preview() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 DELETE FROM public.app_image_previews WHERE storage_path IN (SELECT public.findez_record_image_paths(to_jsonb(NEW)));
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_guard_item_image_reference(),public.findez_consume_image_preview() FROM PUBLIC,anon,authenticated,service_role;
DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['items','item_events','capture_reviews','messages'] LOOP
 EXECUTE format('DROP TRIGGER IF EXISTS permission_item_image_reference ON public.%I',t);
 EXECUTE format('CREATE TRIGGER permission_item_image_reference BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.findez_guard_item_image_reference()',t);
 EXECUTE format('DROP TRIGGER IF EXISTS permission_consume_image_preview ON public.%I',t);
 EXECUTE format('CREATE TRIGGER permission_consume_image_preview AFTER INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.findez_consume_image_preview()',t);
END LOOP; END $$;
CREATE INDEX IF NOT EXISTS permission_item_image_path ON public.items(public.findez_item_image_path(image_url));
CREATE INDEX IF NOT EXISTS permission_event_image_path ON public.item_events(public.findez_item_image_path(image_url));
-- Preview metadata is not saved inventory content. Preserve the existing
-- guarded deletion/cleanup contracts for empty and populated inventories.
CREATE OR REPLACE FUNCTION pg_temp.private_photo_patch(target regprocedure,old_sql text,new_sql text) RETURNS void
LANGUAGE plpgsql AS $$ DECLARE definition text:=pg_get_functiondef(target); BEGIN
 IF position(new_sql IN definition)>0 THEN RETURN; END IF;
 IF position(old_sql IN definition)=0 THEN RAISE EXCEPTION 'Private photo source differs for %',target; END IF;
 EXECUTE replace(definition,old_sql,new_sql);
END $$;
SELECT pg_temp.private_photo_patch('public.findez_delete_inventory_contents(uuid,uuid,text)',
 $old$'app_inventory_members','app_inventory_access_requests','app_access_invitations','memory_events')$old$,
 $new$'app_inventory_members','app_inventory_access_requests','app_access_invitations','memory_events','app_image_previews')$new$);
SELECT pg_temp.private_photo_patch('public.findez_delete_inventory_contents(uuid,uuid,text)',
 $old$ ) objects;$old$,
 $new$ UNION ALL SELECT jsonb_build_object('kind','image','path',storage_path,'owner',split_part(storage_path,'/',1))
  FROM public.app_image_previews WHERE inventory_id=p_inventory
 ) objects;$new$);
SELECT pg_temp.private_photo_patch('public.findez_delete_empty_inventory(uuid,uuid,text)',
 $old$'app_inventory_members','app_inventory_access_requests','app_access_invitations','memory_events')$old$,
 $new$'app_inventory_members','app_inventory_access_requests','app_access_invitations','memory_events','app_image_previews')$new$);
SELECT pg_temp.private_photo_patch('public.findez_delete_empty_inventory(uuid,uuid,text)',
 $old$ INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)$old$,
 $new$ INSERT INTO public.app_inventory_deletions(inventory_id,actor_id,files)
 SELECT p_inventory,p_actor,jsonb_agg(jsonb_build_object('kind','image','path',storage_path,'owner',split_part(storage_path,'/',1)))
 FROM public.app_image_previews WHERE inventory_id=p_inventory HAVING count(*)>0;
 INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)$new$);
SELECT pg_temp.private_photo_patch('public.findez_delete_empty_inventory(uuid,uuid,text)',
 $old$RETURN jsonb_build_object('deleted',true,'inventory_id',p_inventory);$old$,
 $new$RETURN jsonb_build_object('deleted',true,'inventory_id',p_inventory,'file_cleanup_pending',
 EXISTS(SELECT 1 FROM public.app_inventory_deletions WHERE inventory_id=p_inventory));$new$);
SELECT pg_temp.private_photo_patch('public.findez_prepare_account_deletion(uuid,jsonb)',
 $old$ UNION ALL SELECT value FROM jsonb_array_elements(p_files)$old$,
 $new$ UNION ALL SELECT jsonb_build_object('kind','image','path',storage_path,'owner',split_part(storage_path,'/',1))
  FROM public.app_image_previews WHERE actor_id=p_actor
  UNION ALL SELECT value FROM jsonb_array_elements(p_files)$new$);

UPDATE storage.buckets SET public=false WHERE id='item-images';
DROP POLICY IF EXISTS permission_private_item_images ON storage.objects;
CREATE POLICY permission_private_item_images ON storage.objects AS RESTRICTIVE FOR ALL TO anon,authenticated
 USING(bucket_id<>'item-images') WITH CHECK(bucket_id<>'item-images');
NOTIFY pgrst,'reload schema';
COMMIT;

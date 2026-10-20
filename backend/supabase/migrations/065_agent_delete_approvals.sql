-- Only an authenticated human session may confirm; API keys can prepare/poll.
BEGIN;
CREATE TABLE IF NOT EXISTS public.api_agent_delete_approvals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), key_id uuid NOT NULL REFERENCES public.api_keys(id) ON DELETE CASCADE,
 request_id uuid NOT NULL, actor_id uuid NOT NULL, kind text NOT NULL CHECK(kind IN ('item','space','inventory','workspace')),
 resource_id uuid NOT NULL, preview jsonb NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','confirmed','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL DEFAULT now()+interval '15 minutes',
 receipt jsonb, UNIQUE(key_id,request_id)
);
ALTER TABLE public.api_agent_delete_approvals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.api_agent_delete_approvals FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.api_agent_delete_approvals TO service_role;

CREATE TABLE IF NOT EXISTS public.api_agent_file_deletions (
 approval_id uuid PRIMARY KEY, files jsonb NOT NULL, completed boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);
ALTER TABLE public.api_agent_file_deletions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.api_agent_file_deletions FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.api_agent_file_deletions TO service_role;

CREATE OR REPLACE FUNCTION public.findez_agent_delete_snapshot(p_key uuid,p_kind text,p_resource uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE authority jsonb; inv uuid; actor uuid; role_name text; snap jsonb:='{}'; t record;
 digest text; n bigint; impacts jsonb; item_count bigint; space_count bigint; row_record record;
BEGIN
 IF p_kind NOT IN ('item','space','inventory','workspace') THEN RAISE invalid_parameter_value; END IF;
 authority:=public.findez_agent_authority(p_key,CASE WHEN p_kind='item' THEN 'items:delete' ELSE 'structure:delete' END,p_kind,p_resource);
 inv:=(authority->>'inventory_id')::uuid; actor:=(authority->>'actor_id')::uuid;
 IF p_kind='workspace' THEN
  IF authority->>'owner_id'<>actor::text THEN RAISE insufficient_privilege; END IF;
  IF EXISTS(SELECT 1 FROM public.app_inventories WHERE team_id=p_resource)
   OR EXISTS(SELECT 1 FROM public.team_spaces WHERE team_id=p_resource)
   OR EXISTS(SELECT 1 FROM public.app_physical_locations WHERE team_id=p_resource)
   THEN RAISE check_violation USING MESSAGE='Delete or move inventories and physical locations before deleting this workspace'; END IF;
  SELECT jsonb_build_object('workspace',to_jsonb(workspace_row)-'join_code',
   'members',(SELECT coalesce(jsonb_agg(to_jsonb(m) ORDER BY user_id),'[]') FROM public.team_memberships m WHERE team_id=p_resource)) INTO snap
   FROM public.teams workspace_row WHERE team_id=p_resource;
  impacts:=jsonb_build_object('workspaces',1,'inventories',0,'items',0);
 ELSE
  role_name:=public.findez_inventory_role(inv,actor);
  IF p_kind='item' AND NOT coalesce(role_name IN ('owner','admin','editor'),false)
   OR p_kind='space' AND NOT coalesce(role_name IN ('owner','admin'),false)
   OR p_kind='inventory' AND NOT coalesce(public.findez_can_administer_inventory(inv,actor),false)
   THEN RAISE insufficient_privilege; END IF;
  -- Freeze all inventory content during snapshot/confirmation. Changes anywhere
  -- in the inventory conservatively invalidate a pending deletion.
  FOR t IN SELECT c.table_name FROM information_schema.columns c
   JOIN pg_tables p ON p.schemaname=c.table_schema AND p.tablename=c.table_name
   WHERE c.table_schema='public' AND c.column_name='inventory_id'
    AND c.table_name NOT IN ('app_access_audit','app_inventory_deletions') ORDER BY c.table_name LOOP
   FOR row_record IN EXECUTE format('SELECT 1 FROM public.%I WHERE inventory_id=$1 FOR UPDATE',t.table_name) USING inv LOOP NULL; END LOOP;
   EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),%L ORDER BY md5(to_jsonb(x)::text)),%L)) FROM public.%I x WHERE inventory_id=$1','|','',t.table_name)
    INTO n,digest USING inv;
   snap:=snap||jsonb_build_object(t.table_name,jsonb_build_object('count',n,'digest',digest));
  END LOOP;
  SELECT count(*) INTO item_count FROM public.items WHERE inventory_id=inv
   AND (p_kind='inventory' OR p_kind='space' AND space_id=p_resource OR p_kind='item' AND item_id=p_resource);
  SELECT count(*) INTO space_count FROM public.spaces WHERE inventory_id=inv AND (p_kind='inventory' OR p_kind='space' AND id=p_resource);
  impacts:=jsonb_build_object('inventories',CASE WHEN p_kind='inventory' THEN 1 ELSE 0 END,'spaces',space_count,'items',item_count,
   'related_records',CASE WHEN p_kind='inventory' THEN (SELECT jsonb_object_agg(key,value->'count') FROM jsonb_each(snap)
    WHERE key NOT IN ('items','spaces','app_inventories')) ELSE '{}' END);
 END IF;
 RETURN authority||jsonb_build_object('kind',p_kind,'resource_id',p_resource,'impact',impacts,
  'fingerprint',public.findez_chat_item_fingerprint(snap),
  'warning','Deletion is permanent. Saved contents and dependent records are removed; references may be detached. Changes since this preview require a new request.');
END $$;

CREATE OR REPLACE FUNCTION public.findez_agent_prepare_delete(p_key uuid,p_request uuid,p_kind text,p_resource uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE preview jsonb; saved public.api_agent_delete_approvals;
BEGIN
 preview:=public.findez_agent_delete_snapshot(p_key,p_kind,p_resource);
 PERFORM pg_advisory_xact_lock(hashtextextended('findez:agent-delete:'||p_key::text||':'||p_request::text,0));
 SELECT * INTO saved FROM public.api_agent_delete_approvals WHERE key_id=p_key AND request_id=p_request;
 IF FOUND THEN
  IF saved.kind<>p_kind OR saved.resource_id<>p_resource THEN RAISE invalid_parameter_value; END IF;
 ELSE
  INSERT INTO public.api_agent_delete_approvals(key_id,request_id,actor_id,kind,resource_id,preview)
   VALUES(p_key,p_request,(preview->>'actor_id')::uuid,p_kind,p_resource,preview) RETURNING * INTO saved;
 END IF;
 RETURN to_jsonb(saved)-'actor_id'||jsonb_build_object('preview',saved.preview-'fingerprint');
END $$;

CREATE OR REPLACE FUNCTION public.findez_agent_confirm_delete(p_actor uuid,p_approval uuid,p_decision text,p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE saved public.api_agent_delete_approvals; current_preview jsonb; v_receipt jsonb; inv uuid; affected integer; files jsonb; item_ids uuid[];
BEGIN
 -- The HTTP caller of this RPC must be a real user session, never an API key.
 IF p_decision NOT IN ('confirm','cancel') OR NOT public.findez_actor_active(p_actor) THEN RAISE insufficient_privilege; END IF;
 SELECT * INTO STRICT saved FROM public.api_agent_delete_approvals WHERE id=p_approval AND actor_id=p_actor FOR UPDATE;
 IF saved.status<>'pending' THEN RETURN jsonb_build_object('id',saved.id,'status',saved.status,'receipt',saved.receipt); END IF;
 IF p_decision='cancel' THEN
  UPDATE public.api_agent_delete_approvals SET status='cancelled' WHERE id=saved.id;
  RETURN jsonb_build_object('id',saved.id,'status','cancelled');
 END IF;
 IF saved.expires_at<=now() THEN RAISE check_violation USING MESSAGE='approval_expired'; END IF;
 current_preview:=public.findez_agent_delete_snapshot(saved.key_id,saved.kind,saved.resource_id);
 IF current_preview IS DISTINCT FROM saved.preview OR p_name IS DISTINCT FROM saved.preview->>'name'
 THEN RAISE serialization_failure USING MESSAGE='preview_changed'; END IF;
 inv:=(current_preview->>'inventory_id')::uuid;
 IF saved.kind IN ('space','item') THEN
  SELECT coalesce(array_agg(item_id),'{}') INTO item_ids FROM public.items WHERE inventory_id=inv
   AND (saved.kind='space' AND space_id=saved.resource_id OR saved.kind='item' AND item_id=saved.resource_id);
  SELECT coalesce(jsonb_agg(DISTINCT file),'[]') INTO files FROM (
   SELECT jsonb_build_object('kind','image','url',image_url,'owner',user_id) AS file FROM public.items WHERE item_id=ANY(item_ids) AND image_url IS NOT NULL
   UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',user_id) FROM public.item_events WHERE item_id=ANY(item_ids) AND image_url IS NOT NULL
   UNION ALL SELECT jsonb_build_object('kind','document','path',storage_path,'owner',user_id) FROM public.documents WHERE item_id=ANY(item_ids) AND storage_path IS NOT NULL
   UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',user_id) FROM public.capture_reviews
    WHERE (resolved_item_id=ANY(item_ids) OR saved.kind='space' AND space_id=saved.resource_id) AND image_url IS NOT NULL
   UNION ALL SELECT jsonb_build_object('kind','image','url',source_frame_url,'owner',user_id) FROM public.capture_reviews
    WHERE (resolved_item_id=ANY(item_ids) OR saved.kind='space' AND space_id=saved.resource_id) AND source_frame_url IS NOT NULL
   UNION ALL SELECT jsonb_build_object('kind','image','url',v #>> '{}','owner',r.user_id) FROM public.capture_reviews r
    CROSS JOIN LATERAL jsonb_path_query(r.scan_evidence,'$.** ? (@.type() == "string")') v
    WHERE (r.resolved_item_id=ANY(item_ids) OR saved.kind='space' AND r.space_id=saved.resource_id) AND (v #>> '{}') LIKE '%/storage/v1/object/%'
  ) objects;
  INSERT INTO public.api_agent_file_deletions(approval_id,files) VALUES(saved.id,files);
 END IF;
 IF saved.kind='inventory' THEN
  v_receipt:=public.findez_delete_inventory_contents(p_actor,saved.resource_id,p_name);
 ELSIF saved.kind='workspace' THEN
  IF NOT public.findez_delete_inventory_team(saved.resource_id,p_actor) THEN RAISE no_data_found; END IF;
  v_receipt:=jsonb_build_object('deleted',true,'workspace_id',saved.resource_id);
 ELSIF saved.kind='space' THEN
  DELETE FROM public.spaces WHERE id=saved.resource_id AND inventory_id=inv;
  GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>1 THEN RAISE check_violation; END IF;
  v_receipt:=jsonb_build_object('deleted',true,'space_id',saved.resource_id);
 ELSE
  DELETE FROM public.items WHERE item_id=saved.resource_id AND inventory_id=inv;
  GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>1 THEN RAISE check_violation; END IF;
  v_receipt:=jsonb_build_object('deleted',true,'item_id',saved.resource_id);
 END IF;
 IF saved.kind IN ('space','item') THEN v_receipt:=v_receipt||jsonb_build_object('file_cleanup_id',saved.id); END IF;
 v_receipt:=v_receipt||jsonb_build_object('confirmed_at',now(),'impact',saved.preview->'impact','owner_id',saved.preview->>'owner_id');
 UPDATE public.api_agent_delete_approvals SET status='confirmed',receipt=v_receipt WHERE id=saved.id;
 INSERT INTO public.app_access_audit(actor_id,organization_id,action,target_id,changes)
 VALUES(p_actor,(saved.preview->>'organization_id')::uuid,'agent_delete_confirmed',saved.resource_id,
  jsonb_build_object('key_id',saved.key_id,'approval_id',saved.id,'kind',saved.kind,'impact',saved.preview->'impact'));
 RETURN jsonb_build_object('id',saved.id,'status','confirmed','receipt',v_receipt);
END $$;
REVOKE ALL ON FUNCTION public.findez_agent_delete_snapshot(uuid,text,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.findez_agent_prepare_delete(uuid,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.findez_agent_confirm_delete(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_agent_delete_snapshot(uuid,text,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.findez_agent_prepare_delete(uuid,uuid,text,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.findez_agent_confirm_delete(uuid,uuid,text,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

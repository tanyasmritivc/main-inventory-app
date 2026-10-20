-- Business conflicts must not use SQLSTATE 40001: PostgREST 14 retries it indefinitely.
-- The API already maps check_violation to HTTP 409. Authorization and deletion are unchanged.
BEGIN;
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
 THEN RAISE check_violation USING MESSAGE='preview_changed'; END IF;
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
NOTIFY pgrst,'reload schema';
COMMIT;

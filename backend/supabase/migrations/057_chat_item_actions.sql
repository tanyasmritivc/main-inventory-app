-- Confirm a frozen proposal stored in the actor's existing private chat message.
-- No historical rows are rewritten. The item write and receipt are one transaction.
BEGIN;
CREATE OR REPLACE FUNCTION public.findez_chat_item_fingerprint(p_item jsonb) RETURNS text
LANGUAGE sql IMMUTABLE STRICT SET search_path=public AS $$
 SELECT encode(sha256(convert_to(p_item::text,'UTF8')),'hex')
$$;
REVOKE ALL ON FUNCTION public.findez_chat_item_fingerprint(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_chat_item_fingerprint(jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.findez_chat_delete_snapshot(p_actor uuid,p_inventory uuid,p_items uuid[]) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE rows jsonb;
BEGIN
 IF array_length(p_items,1) NOT BETWEEN 1 AND 100 OR array_length(p_items,1) IS NULL
  OR (SELECT count(DISTINCT x) FROM unnest(p_items) x)<>array_length(p_items,1) THEN RAISE invalid_parameter_value; END IF;
 PERFORM public.findez_lock_inventory_authority(p_inventory,p_actor);
 IF NOT coalesce(public.findez_inventory_role(p_inventory,p_actor) IN ('owner','admin','editor'),false) THEN RAISE insufficient_privilege; END IF;
 SELECT jsonb_agg(jsonb_build_object('item_id',i.item_id,'name',i.name,'quantity',i.quantity,'location',i.location,
  'snapshot',public.findez_chat_item_fingerprint(to_jsonb(i))) ORDER BY i.item_id) INTO rows
 FROM public.items i WHERE i.inventory_id=p_inventory AND i.item_id=ANY(p_items);
 IF jsonb_array_length(rows) IS DISTINCT FROM array_length(p_items,1) THEN RAISE no_data_found; END IF;
 RETURN rows;
END $$;
REVOKE ALL ON FUNCTION public.findez_chat_delete_snapshot(uuid,uuid,uuid[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_chat_delete_snapshot(uuid,uuid,uuid[]) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_chat_item_action(
 p_actor uuid,p_inventory uuid,p_action uuid,p_decision text,p_item_limit integer DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.app_inventories; message_id uuid; conversation uuid; context jsonb;
 action jsonb; entry jsonb; result jsonb; receipts jsonb:='[]';
 target public.items; destination public.spaces; ordinal integer:=0; role_name text;
 count_items integer; inserted_id uuid; headers jsonb; affected integer;
BEGIN
 IF p_decision NOT IN ('read','confirm','cancel') OR (p_item_limit IS NOT NULL AND p_item_limit<0) THEN RAISE invalid_parameter_value; END IF;
 PERFORM public.findez_lock_inventory_authority(p_inventory,p_actor);
 role_name:=public.findez_inventory_role(p_inventory,p_actor);
 IF role_name IS NULL THEN RAISE insufficient_privilege; END IF;
 SELECT * INTO STRICT inv FROM public.app_inventories WHERE inventory_id=p_inventory;
 SELECT m.id,m.conversation_id,m.answer_context,a.value
 INTO STRICT message_id,conversation,context,action
 FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
 CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(m.answer_context->'pending_actions')='array'
  THEN m.answer_context->'pending_actions' ELSE '[]'::jsonb END) a(value)
 WHERE c.user_id=p_actor AND c.inventory_id=p_inventory AND m.inventory_id=p_inventory
  AND m.role='assistant' AND a.value->>'id'=p_action::text FOR UPDATE OF m;
 IF action->>'inventory_id' IS DISTINCT FROM p_inventory::text OR action->'version' IS DISTINCT FROM '1'::jsonb
  OR NOT coalesce(action->>'operation' IN ('add','delete'),false) OR NOT coalesce(action->>'status' IN ('pending','confirmed','cancelled'),false)
 THEN RAISE check_violation; END IF;
 IF p_decision='read' THEN RETURN action||jsonb_build_object('conversation_id',conversation); END IF;
 IF p_decision='confirm' AND role_name NOT IN ('owner','admin','editor') THEN RAISE insufficient_privilege; END IF;
 IF action->>'status'<>'pending' THEN RETURN action||jsonb_build_object('conversation_id',conversation); END IF;
 IF p_decision='confirm' AND (jsonb_typeof(action->'expires_at') IS DISTINCT FROM 'string' OR (action->>'expires_at')::timestamptz<now() OR jsonb_typeof(action->'items') IS DISTINCT FROM 'array'
  OR jsonb_array_length(action->'items') NOT BETWEEN 1 AND 100 OR octet_length(action::text)>131072) THEN RAISE check_violation; END IF;
 IF p_decision='cancel' THEN
  action:=action||jsonb_build_object('status','cancelled','items',
   (SELECT coalesce(jsonb_agg(value-'before'-'image_url'-'source_frame_url'-'crop_path'),'[]') FROM jsonb_array_elements(action->'items')));
 ELSE
  -- Ensure image-reference/audit triggers see the verified actor, never a model argument.
  headers:=coalesce(nullif(current_setting('request.headers',true),'')::jsonb,'{}');
  PERFORM set_config('request.headers',(headers||jsonb_build_object('x-findez-actor',p_actor))::text,true);
  count_items:=jsonb_array_length(action->'items');
  IF action->>'operation'='add' THEN
   PERFORM pg_advisory_xact_lock(hashtextextended('findez:item-limit:'||inv.owner_user_id::text,0));
   IF p_item_limit IS NOT NULL AND (SELECT count(*)+count_items>p_item_limit FROM public.items WHERE user_id=inv.owner_user_id) THEN RAISE check_violation; END IF;
   FOR entry IN SELECT value FROM jsonb_array_elements(action->'items') LOOP
    ordinal:=ordinal+1;
    IF jsonb_typeof(entry) IS DISTINCT FROM 'object' OR jsonb_typeof(entry->'name') IS DISTINCT FROM 'string'
     OR jsonb_typeof(entry->'category') IS DISTINCT FROM 'string' OR jsonb_typeof(entry->'location') IS DISTINCT FROM 'string' OR nullif(btrim(entry->>'name'),'') IS NULL
     OR length(entry->>'name')>200 OR nullif(btrim(entry->>'category'),'') IS NULL OR length(entry->>'category')>100
     OR jsonb_typeof(entry->'quantity') IS DISTINCT FROM 'number'
     OR (entry->>'quantity')::numeric NOT BETWEEN 0 AND 1000000
     OR trunc((entry->>'quantity')::numeric)<>(entry->>'quantity')::numeric OR length(coalesce(entry->>'notes',''))>2000
    THEN RAISE check_violation; END IF;
    SELECT * INTO STRICT destination FROM public.spaces WHERE id=(entry->>'space_id')::uuid
     AND inventory_id=p_inventory AND name=entry->>'location' FOR SHARE;
    inserted_id:=md5(p_action::text||':'||ordinal)::uuid;
    INSERT INTO public.items(item_id,user_id,inventory_id,name,category,quantity,location,space_id,notes,image_url)
    VALUES(inserted_id,inv.owner_user_id,p_inventory,btrim(entry->>'name'),btrim(entry->>'category'),
     (entry->>'quantity')::integer,destination.name,destination.id,nullif(entry->>'notes',''),nullif(entry->>'image_url','')) RETURNING * INTO target;
    IF target.item_id IS DISTINCT FROM inserted_id THEN RAISE check_violation; END IF;
    IF nullif(entry->>'source_frame_url','') IS NOT NULL AND entry->>'source_frame_url' IS DISTINCT FROM target.image_url THEN
     INSERT INTO public.item_events(event_id,item_id,user_id,inventory_id,event_type,content,image_url)
     VALUES(gen_random_uuid(),target.item_id,inv.owner_user_id,p_inventory,'photo','Original scan photo',entry->>'source_frame_url');
     GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>1 THEN RAISE check_violation; END IF;
    END IF;
    receipts:=receipts||jsonb_build_array(jsonb_build_object('item_id',target.item_id,'name',target.name,'category',target.category,'quantity',target.quantity,'location',target.location));
   END LOOP;
  ELSE
   IF (SELECT count(DISTINCT value->>'item_id') FROM jsonb_array_elements(action->'items'))<>count_items THEN RAISE check_violation; END IF;
   -- Lock the complete frozen selection before deleting any row. A rename,
   -- movement or quantity change invalidates the whole confirmation.
   PERFORM 1 FROM public.items WHERE inventory_id=p_inventory AND item_id IN
    (SELECT (value->>'item_id')::uuid FROM jsonb_array_elements(action->'items')) ORDER BY item_id FOR UPDATE;
   FOR entry IN SELECT value FROM jsonb_array_elements(action->'items') LOOP
    SELECT * INTO STRICT target FROM public.items WHERE item_id=(entry->>'item_id')::uuid AND inventory_id=p_inventory;
    IF entry->>'snapshot' IS DISTINCT FROM public.findez_chat_item_fingerprint(to_jsonb(target))
     OR entry->>'name' IS DISTINCT FROM target.name OR entry->'quantity' IS DISTINCT FROM to_jsonb(target.quantity)
     OR entry->>'location' IS DISTINCT FROM target.location THEN RAISE check_violation; END IF;
    receipts:=receipts||jsonb_build_array(jsonb_build_object('item_id',target.item_id,'name',target.name,'category',target.category,'quantity',target.quantity,'location',target.location));
   END LOOP;
   DELETE FROM public.items WHERE inventory_id=p_inventory AND item_id IN
    (SELECT (value->>'item_id')::uuid FROM jsonb_array_elements(action->'items'));
   GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>count_items THEN RAISE check_violation; END IF;
  END IF;
  result:=jsonb_build_object('operation',action->>'operation','items',receipts,'count',count_items,'confirmed_at',now());
  action:=action||jsonb_build_object('status','confirmed','receipt',result,'items',receipts);
  INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
   VALUES(p_actor,inv.team_id,p_inventory,'chat_items_'||(action->>'operation'),p_action,jsonb_build_object('count',count_items));
  GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>1 THEN RAISE check_violation; END IF;
 END IF;
 UPDATE public.messages SET answer_context=jsonb_set(context,'{pending_actions}',
  (SELECT jsonb_agg(CASE WHEN value->>'id'=p_action::text THEN action ELSE value END)
   FROM jsonb_array_elements(context->'pending_actions'))) WHERE id=message_id;
 GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>1 THEN RAISE check_violation; END IF;
 RETURN action||jsonb_build_object('conversation_id',conversation);
END $$;
REVOKE ALL ON FUNCTION public.findez_chat_item_action(uuid,uuid,uuid,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_chat_item_action(uuid,uuid,uuid,text,integer) TO service_role;
-- Persisted pending cards retain only their actor's reviewed photo references.
-- A BEFORE image guard validates every reference before the preview is consumed.
CREATE OR REPLACE FUNCTION public.findez_pending_chat_image(p_actor uuid,p_path text) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE record_row record; action_row jsonb; item_row jsonb; expiry timestamptz;
BEGIN
 FOR record_row IN SELECT m.answer_context,m.created_at,c.inventory_id FROM public.messages m
  JOIN public.conversations c ON c.id=m.conversation_id
  WHERE c.user_id=p_actor AND m.inventory_id=c.inventory_id AND m.role='assistant'
   AND m.created_at>=now()-interval '31 minutes' AND m.answer_context ? 'pending_actions'
   AND public.findez_inventory_role(c.inventory_id,p_actor) IS NOT NULL LOOP
  IF jsonb_typeof(record_row.answer_context->'pending_actions') IS DISTINCT FROM 'array' THEN CONTINUE; END IF;
  FOR action_row IN SELECT value FROM jsonb_array_elements(record_row.answer_context->'pending_actions') LOOP
   IF action_row->>'operation' IS DISTINCT FROM 'add' OR action_row->>'status' IS DISTINCT FROM 'pending'
    OR action_row->>'inventory_id' IS DISTINCT FROM record_row.inventory_id::text
    OR jsonb_typeof(action_row->'items') IS DISTINCT FROM 'array' THEN CONTINUE; END IF;
   BEGIN expiry:=(action_row->>'expires_at')::timestamptz;
   EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN CONTINUE; END;
   IF expiry IS NULL OR expiry<=now() OR expiry>record_row.created_at+interval '30 minutes' THEN CONTINUE; END IF;
   FOR item_row IN SELECT value FROM jsonb_array_elements(action_row->'items') LOOP
    IF p_path=public.findez_item_image_path(item_row->>'image_url')
     OR p_path=public.findez_item_image_path(item_row->>'source_frame_url') THEN RETURN true; END IF;
   END LOOP;
  END LOOP;
 END LOOP;
 RETURN false;
END $$;
REVOKE ALL ON FUNCTION public.findez_pending_chat_image(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_pending_chat_image(uuid,text) TO service_role;
DO $$
DECLARE definition text:=pg_get_functiondef('public.findez_can_read_item_image(uuid,text)'::regprocedure);
 marker text:='  OR EXISTS(SELECT 1 FROM public.app_image_previews';
BEGIN
 IF position('findez_pending_chat_image(p_actor,p_path)' IN definition)>0 THEN RETURN; END IF;
 IF position(marker IN definition)=0 THEN RAISE EXCEPTION 'Private photo authorization source differs'; END IF;
 EXECUTE replace(definition,marker,'  OR public.findez_pending_chat_image(p_actor,p_path)'||chr(10)||marker);
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

-- Preserve private Auto Extract draft photos beyond the temporary upload grant.
-- No customer rows, tables, policies or existing permission branches are changed.
BEGIN;
CREATE OR REPLACE FUNCTION public.findez_chat_capture_image(p_actor uuid,p_path text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT public.findez_actor_active(p_actor) AND p_path LIKE p_actor::text||'/%' AND EXISTS(
  SELECT 1 FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
  WHERE c.user_id=p_actor AND c.world_key IS NOT NULL AND m.role='assistant'
   AND m.answer_context->'chat_capture'->>'id'=m.id::text
   AND m.answer_context->'chat_capture'->>'version'='1'
   AND (c.world_key='personal' OR EXISTS(SELECT 1 FROM public.app_organization_members om
    WHERE om.organization_id::text=c.world_key AND om.user_id=p_actor))
   AND p_path IN (SELECT public.findez_image_paths(m.answer_context->'chat_capture'))
 )
$$;
REVOKE ALL ON FUNCTION public.findez_chat_capture_image(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_chat_capture_image(uuid,text) TO service_role;
DO $$
DECLARE definition text:=pg_get_functiondef('public.findez_can_read_item_image(uuid,text)'::regprocedure);
 marker text:='  OR public.findez_pending_world_image(p_actor,p_path)';
BEGIN
 IF position('findez_chat_capture_image' IN definition)>0 THEN RETURN; END IF;
 IF position(marker IN definition)=0 THEN RAISE EXCEPTION 'Photo authorization source differs'; END IF;
 EXECUTE replace(definition,marker,'  OR public.findez_chat_capture_image(p_actor,p_path)'||chr(10)||marker);
END $$;
COMMIT;

BEGIN;
-- Atomic durable receipt plus existing snapshot-checked edit/move transaction.
CREATE OR REPLACE FUNCTION public.findez_world_direct_action(
 p_actor uuid,p_world text,p_conversation uuid,p_turn uuid,p_action jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE mid uuid; existing jsonb; action_id uuid; inventory uuid; result jsonb;
BEGIN
 IF NOT coalesce(public.findez_actor_active(p_actor),false) OR p_action->'version' IS DISTINCT FROM '2'::jsonb
  OR NOT coalesce(p_action->>'operation' IN ('edit','move','reorder'),false)
  OR p_action->>'status' IS DISTINCT FROM 'pending' OR p_action->>'world' IS DISTINCT FROM p_world
  OR p_action->>'turn_id' IS DISTINCT FROM p_turn::text OR p_action->'direct' IS DISTINCT FROM 'true'::jsonb THEN RAISE check_violation; END IF;
 -- Request identity belongs to this private conversation and signed-in actor.
 PERFORM 1 FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
  WHERE m.id=p_turn AND m.conversation_id=p_conversation AND m.role='user'
  AND c.user_id=p_actor AND c.world_key=p_world;
 IF NOT FOUND THEN RAISE insufficient_privilege; END IF;
 action_id:=(p_action->>'id')::uuid;
 inventory:=(p_action->>'inventory_id')::uuid;
 PERFORM pg_advisory_xact_lock(hashtextextended('findez:direct:'||action_id,0));
 mid:=md5('findez:direct-receipt:'||action_id)::uuid;
 SELECT answer_context->'pending_actions'->0 INTO existing FROM public.messages WHERE id=mid AND conversation_id=p_conversation;
 IF existing IS NULL THEN
  INSERT INTO public.messages(id,conversation_id,role,content,answer_context)
  VALUES(mid,p_conversation,'assistant','',jsonb_build_object('direct_receipt',true,'turn_id',p_turn,'pending_actions',jsonb_build_array(p_action)));
 ELSE
  IF existing->>'world' IS DISTINCT FROM p_world OR existing->>'turn_id' IS DISTINCT FROM p_turn::text THEN RAISE check_violation; END IF;
  inventory:=(existing->>'inventory_id')::uuid;
 END IF;
 result:=public.findez_world_item_change(p_actor,p_world,inventory,action_id,'confirm');
 IF result->>'status' IS DISTINCT FROM 'confirmed' THEN RAISE check_violation; END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.findez_world_direct_action(uuid,text,uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_world_direct_action(uuid,text,uuid,uuid,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

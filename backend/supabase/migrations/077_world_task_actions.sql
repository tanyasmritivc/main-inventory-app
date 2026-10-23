-- One confirmation commits structure and its exact dependent item operations.
-- Reuse existing authority locks, snapshots, quotas, audit and retry receipts.
BEGIN;
-- Old clients must not confirm only the structure half of a composite card.
DO $$
DECLARE definition text:=pg_get_functiondef('public.findez_world_structure_action(uuid,text,uuid,text,jsonb)'::regprocedure);
 marker text:='  proposed_plan:=action->''plan'';';
BEGIN
 IF position('findez.world_task_action' IN definition)>0 THEN RETURN; END IF;
 IF position(marker IN definition)=0 THEN RAISE EXCEPTION 'Structure action source differs'; END IF;
 EXECUTE replace(definition,marker,marker||chr(10)||
  '  IF action->''version''=''2''::jsonb AND current_setting(''findez.world_task_action'',true) IS DISTINCT FROM p_action::text THEN RAISE check_violation; END IF;');
END $$;
CREATE OR REPLACE FUNCTION public.findez_world_task_action(
 p_actor uuid,p_world text,p_action uuid,p_decision text,
 p_space_limits jsonb DEFAULT NULL,p_item_limits jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE mid uuid; context jsonb; original jsonb; action jsonb; target jsonb;
 entry jsonb; prepared jsonb; child jsonb; completed jsonb; children jsonb:='[]';
 inv uuid; source_inv uuid; owner_id uuid; space public.spaces; child_id uuid;
 ordinal integer:=0; total integer:=0; results jsonb:='[]'; links jsonb:='[]';
BEGIN
 IF NOT coalesce(public.findez_actor_active(p_actor),false) THEN RAISE insufficient_privilege; END IF;
 -- Match the existing structure transaction lock order.
 IF p_world<>'personal' THEN PERFORM 1 FROM public.app_organizations WHERE organization_id=p_world::uuid FOR UPDATE; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('findez:world:'||p_actor::text||':'||p_world,0));
 -- Lock the durable intent before executing anything. Old cards remain valid.
 SELECT m.id,m.answer_context,a.value INTO STRICT mid,context,original
 FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
 CROSS JOIN LATERAL jsonb_array_elements(coalesce(m.answer_context->'world_actions','[]')) a(value)
 WHERE c.user_id=p_actor AND c.world_key=p_world AND m.role='assistant'
 AND a.value->>'id'=p_action::text FOR UPDATE OF m;
 PERFORM set_config('findez.world_task_action',p_action::text,true);
 action:=public.findez_world_structure_action(p_actor,p_world,p_action,p_decision,p_space_limits);
 IF original->>'status'<>'pending' OR action->>'status'<>'confirmed' THEN RETURN action; END IF;
 FOR target IN SELECT value FROM jsonb_array_elements(action->'plan'->'inventories') LOOP
  SELECT (value->>'inventory_id')::uuid INTO STRICT inv
   FROM jsonb_array_elements(action->'receipt'->'inventories')
   WHERE value->>'name'=target->>'name';
  SELECT owner_user_id INTO STRICT owner_id FROM public.app_inventories WHERE inventory_id=inv;
  FOR space IN SELECT * FROM public.spaces WHERE inventory_id=inv AND name IN
   (SELECT jsonb_array_elements_text(target->'spaces')) LOOP
   links:=links||jsonb_build_array(jsonb_build_object('kind','space','id',space.id,
    'inventory_id',inv,'label',space.name,'href','findez://space/'||inv||'/'||space.id));
  END LOOP;
  IF jsonb_typeof(coalesce(target->'items','[]'))<>'array' OR jsonb_typeof(coalesce(target->'moves','[]'))<>'array' THEN RAISE check_violation; END IF;
  total:=total+jsonb_array_length(coalesce(target->'items','[]'))+jsonb_array_length(coalesce(target->'moves','[]'));
  IF total>100 THEN RAISE check_violation; END IF;
  prepared:='[]';
  FOR entry IN SELECT value FROM jsonb_array_elements(coalesce(target->'items','[]')) LOOP
   SELECT * INTO STRICT space FROM public.spaces WHERE inventory_id=inv AND name=entry->>'location';
   prepared:=prepared||jsonb_build_array(entry||jsonb_build_object('space_id',space.id));
  END LOOP;
  IF jsonb_array_length(prepared)>0 THEN
   IF original->'version' IS DISTINCT FROM '2'::jsonb OR p_item_limits IS NULL OR NOT (p_item_limits ? owner_id::text) THEN RAISE check_violation; END IF;
   ordinal:=ordinal+1; child_id:=md5(p_action::text||':task:'||ordinal)::uuid;
   child:=jsonb_build_object('id',child_id,'version',1,'world',p_world,'inventory_id',inv,
    'operation','add','status','pending','expires_at',original->'expires_at','items',prepared);
   UPDATE public.messages SET answer_context=jsonb_set(answer_context,'{pending_actions}',
    coalesce(answer_context->'pending_actions','[]')||jsonb_build_array(child)) WHERE id=mid;
   completed:=public.findez_chat_item_action(p_actor,inv,child_id,'confirm',(p_item_limits->>owner_id::text)::integer);
   results:=results||jsonb_build_array(completed);
   children:=children||jsonb_build_array(child_id);
  END IF;
  FOR entry IN SELECT value FROM jsonb_array_elements(coalesce(target->'moves','[]')) LOOP
   IF original->'version' IS DISTINCT FROM '2'::jsonb THEN RAISE check_violation; END IF;
   SELECT * INTO STRICT space FROM public.spaces WHERE inventory_id=inv AND name=entry->>'target_location';
   source_inv:=(entry->>'inventory_id')::uuid;
   ordinal:=ordinal+1; child_id:=md5(p_action::text||':task:'||ordinal)::uuid;
   child:=jsonb_build_object('id',child_id,'version',2,'world',p_world,'inventory_id',source_inv,
    'operation','move','status','pending','expires_at',original->'expires_at',
    'items',jsonb_build_array((entry-'inventory_id')||jsonb_build_object('target_inventory_id',inv,
     'target_space_id',space.id,'target_location',space.name,'details',jsonb_build_array('Move to '||space.name))));
   UPDATE public.messages SET answer_context=jsonb_set(answer_context,'{pending_actions}',
    coalesce(answer_context->'pending_actions','[]')||jsonb_build_array(child)) WHERE id=mid;
   completed:=public.findez_world_item_change(p_actor,p_world,source_inv,child_id,'confirm');
   results:=results||jsonb_build_array(completed);
   children:=children||jsonb_build_array(child_id);
  END LOOP;
 END LOOP;
 -- Child receipts live inside this single card, not as a second review step.
 action:=action||jsonb_build_object('receipt',action->'receipt'||jsonb_build_object(
  'item_actions',results,'resource_links',links,'item_count',total));
 UPDATE public.messages SET answer_context=jsonb_set(jsonb_set(answer_context,'{world_actions}',
  (SELECT jsonb_agg(CASE WHEN value->>'id'=p_action::text THEN action ELSE value END)
   FROM jsonb_array_elements(answer_context->'world_actions'))),'{pending_actions}',
  (SELECT coalesce(jsonb_agg(value),'[]') FROM jsonb_array_elements(coalesce(answer_context->'pending_actions','[]'))
   WHERE NOT (children ? (value->>'id')))) WHERE id=mid;
 RETURN action;
END $$;
REVOKE ALL ON FUNCTION public.findez_world_task_action(uuid,text,uuid,text,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_world_task_action(uuid,text,uuid,text,jsonb,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

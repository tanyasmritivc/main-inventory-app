-- Add organization-private Chat and atomic, additive structure creation.
-- No existing inventory, item, Space or conversation is rewritten.
BEGIN;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS world_key text;
CREATE INDEX IF NOT EXISTS conversations_world_actor ON public.conversations(user_id,world_key,updated_at DESC) WHERE world_key IS NOT NULL;
-- World histories remain private even if legacy inventory read policies expand.
CREATE OR REPLACE FUNCTION public.findez_read_world_conversation(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS(SELECT 1 FROM public.conversations c WHERE c.id=p_id AND
  (c.world_key IS NULL OR (c.user_id=auth.uid() AND public.findez_actor_active(auth.uid())
   AND (c.world_key='personal' OR EXISTS(SELECT 1 FROM public.app_organization_members m
    WHERE m.organization_id::text=c.world_key AND m.user_id=auth.uid())))))
$$;
REVOKE ALL ON FUNCTION public.findez_read_world_conversation(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.findez_read_world_conversation(uuid) TO authenticated,service_role;
DROP POLICY IF EXISTS world_chat_private_read ON public.conversations;
CREATE POLICY world_chat_private_read ON public.conversations AS RESTRICTIVE FOR SELECT TO authenticated
 USING(public.findez_read_world_conversation(id));
DROP POLICY IF EXISTS world_chat_private_read ON public.messages;
CREATE POLICY world_chat_private_read ON public.messages AS RESTRICTIVE FOR SELECT TO authenticated
 USING(public.findez_read_world_conversation(conversation_id));
CREATE OR REPLACE FUNCTION public.findez_world_structure_action(p_actor uuid,p_world text,p_action uuid,p_decision text,p_space_limits jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE mid uuid; context jsonb; action jsonb; proposed_plan jsonb; entry jsonb; space_name text;
 org uuid; ws uuid; owner_id uuid; inv uuid; saved jsonb; output jsonb:='[]';
 org_role text; inv_role text; headers jsonb; space_limit integer;
BEGIN
 IF NOT coalesce(public.findez_actor_active(p_actor),false) OR NOT coalesce(p_decision IN ('confirm','cancel'),false) OR p_world IS NULL THEN RAISE insufficient_privilege; END IF;
 IF p_world<>'personal' THEN
  org:=p_world::uuid;
  PERFORM 1 FROM public.app_organizations WHERE organization_id=org FOR UPDATE;
  SELECT role INTO org_role FROM public.app_organization_members WHERE organization_id=org AND user_id=p_actor;
  IF org_role IS NULL THEN RAISE insufficient_privilege; END IF;
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('findez:world:'||p_actor::text||':'||p_world,0));
 SELECT m.id,m.answer_context,a.value INTO STRICT mid,context,action
 FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
 CROSS JOIN LATERAL jsonb_array_elements(coalesce(m.answer_context->'world_actions','[]')) a(value)
 WHERE c.user_id=p_actor AND c.world_key=p_world AND m.role='assistant'
 AND a.value->>'id'=p_action::text FOR UPDATE OF m;
 IF action->>'world' IS DISTINCT FROM p_world OR NOT coalesce(action->>'status' IN ('pending','confirmed','cancelled'),false) THEN RAISE check_violation; END IF;
 IF action->>'status'<>'pending' THEN RETURN action; END IF;
 IF p_decision='cancel' THEN action:=action||'{"status":"cancelled"}'::jsonb;
 ELSE
  IF action->>'expires_at' IS NULL OR (action->>'expires_at')::timestamptz<=now() THEN RAISE check_violation; END IF;
  proposed_plan:=action->'plan';
  IF jsonb_typeof(proposed_plan->'inventories') IS DISTINCT FROM 'array' OR jsonb_array_length(proposed_plan->'inventories') NOT BETWEEN 1 AND 10
   OR ((nullif(proposed_plan->>'workspace_id','') IS NULL) = (nullif(proposed_plan->>'workspace_name','') IS NULL)) THEN RAISE check_violation; END IF;
  headers:=coalesce(nullif(current_setting('request.headers',true),'')::jsonb,'{}');
  PERFORM set_config('request.headers',(headers||jsonb_build_object('x-findez-actor',p_actor))::text,true);
  IF nullif(proposed_plan->>'workspace_id','') IS NOT NULL THEN
   IF proposed_plan->>'workspace_id'='personal' THEN
    IF org IS NOT NULL THEN RAISE insufficient_privilege; END IF;
    ws:=NULL; owner_id:=p_actor;
   ELSE
    ws:=(proposed_plan->>'workspace_id')::uuid;
    SELECT owner_user_id INTO STRICT owner_id FROM public.teams WHERE team_id=ws AND organization_id IS NOT DISTINCT FROM org FOR UPDATE;
    IF NOT coalesce(public.findez_workspace_role(ws,p_actor) IN ('owner','mentor'),false) THEN RAISE insufficient_privilege; END IF;
   END IF;
  ELSE
   IF org IS NULL OR org_role NOT IN ('owner','admin') OR nullif(btrim(proposed_plan->>'workspace_name'),'') IS NULL OR length(proposed_plan->>'workspace_name')>100 THEN RAISE insufficient_privilege; END IF;
   -- Reuse only an exact existing workspace; never rename or move it.
   IF (SELECT count(*) FROM public.teams WHERE organization_id=org AND lower(name)=lower(btrim(proposed_plan->>'workspace_name')))>1 THEN RAISE check_violation; END IF;
   SELECT team_id,owner_user_id INTO ws,owner_id FROM public.teams WHERE organization_id=org AND lower(name)=lower(btrim(proposed_plan->>'workspace_name'));
   IF ws IS NULL THEN
    saved:=public.findez_manage_collaboration(p_actor,'workspace_create',jsonb_build_object('organization_id',org,'name',btrim(proposed_plan->>'workspace_name')));
    ws:=(saved->>'team_id')::uuid;
    SELECT owner_user_id INTO STRICT owner_id FROM public.teams WHERE team_id=ws;
   END IF;
  END IF;
  FOR entry IN SELECT value FROM jsonb_array_elements(proposed_plan->'inventories') LOOP
   IF nullif(btrim(entry->>'name'),'') IS NULL OR length(entry->>'name')>100 OR jsonb_typeof(entry->'spaces') IS DISTINCT FROM 'array' OR jsonb_array_length(entry->'spaces')>30 THEN RAISE check_violation; END IF;
   IF (SELECT count(*) FROM public.app_inventories WHERE owner_user_id=owner_id AND team_id IS NOT DISTINCT FROM ws AND lower(name)=lower(btrim(entry->>'name')))>1 THEN RAISE check_violation; END IF;
   SELECT inventory_id INTO inv FROM public.app_inventories WHERE owner_user_id=owner_id AND team_id IS NOT DISTINCT FROM ws AND lower(name)=lower(btrim(entry->>'name'));
   IF inv IS NULL THEN
    saved:=public.findez_create_inventory(p_actor,ws,btrim(entry->>'name'),'workspace');
    inv:=(saved->>'inventory_id')::uuid;
   END IF;
   IF inv IS NULL THEN RAISE check_violation; END IF;
   PERFORM public.findez_lock_inventory_authority(inv,p_actor);
   inv_role:=public.findez_inventory_role(inv,p_actor);
   IF NOT coalesce(inv_role IN ('owner','admin','editor'),false) THEN RAISE insufficient_privilege; END IF;
   FOR space_name IN SELECT jsonb_array_elements_text(entry->'spaces') LOOP
    IF nullif(btrim(space_name),'') IS NULL OR length(space_name)>100 THEN RAISE check_violation; END IF;
    IF p_space_limits IS NULL OR NOT (p_space_limits ? owner_id::text) THEN RAISE check_violation; END IF;
    space_limit:=(p_space_limits->>owner_id::text)::integer;
    PERFORM pg_advisory_xact_lock(hashtextextended('findez:space-limit:'||owner_id::text,0));
    IF NOT EXISTS(SELECT 1 FROM public.spaces WHERE inventory_id=inv AND lower(name)=lower(btrim(space_name))) THEN
     IF space_limit IS NOT NULL AND (SELECT count(*) FROM public.spaces WHERE user_id=owner_id)>=space_limit THEN RAISE check_violation; END IF;
     INSERT INTO public.spaces(id,user_id,inventory_id,name) VALUES(gen_random_uuid(),owner_id,inv,btrim(space_name));
    END IF;
   END LOOP;
   output:=output||jsonb_build_array(jsonb_build_object('inventory_id',inv,'name',entry->>'name','spaces',entry->'spaces'));
  END LOOP;
  action:=action||jsonb_build_object('status','confirmed','receipt',jsonb_build_object('workspace_id',coalesce(ws::text,'personal'),'inventories',output,'confirmed_at',now()));
  INSERT INTO public.app_access_audit(actor_id,organization_id,team_id,action,target_id,changes)
   VALUES(p_actor,org,ws,'chat_structure_create',p_action,jsonb_build_object('inventories',output));
 END IF;
 UPDATE public.messages SET answer_context=jsonb_set(context,'{world_actions}',
  (SELECT jsonb_agg(CASE WHEN value->>'id'=p_action::text THEN action ELSE value END) FROM jsonb_array_elements(context->'world_actions'))) WHERE id=mid;
 RETURN action;
END $$;
REVOKE ALL ON FUNCTION public.findez_world_structure_action(uuid,text,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_world_structure_action(uuid,text,uuid,text,jsonb) TO service_role;

-- Only the service can create/update world chat payloads. Otherwise an authenticated
-- client could forge an assistant proposal using the original author-owned policies.
CREATE OR REPLACE FUNCTION public.findez_guard_world_chat() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE k text; old_k text;
BEGIN
 IF TG_TABLE_NAME='conversations' THEN
  k:=CASE WHEN TG_OP='DELETE' THEN OLD.world_key ELSE NEW.world_key END;
  IF TG_OP='UPDATE' THEN old_k:=OLD.world_key; END IF;
 ELSE
  SELECT world_key INTO k FROM public.conversations WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.conversation_id ELSE NEW.conversation_id END;
  IF TG_OP='UPDATE' THEN SELECT world_key INTO old_k FROM public.conversations WHERE id=OLD.conversation_id; END IF;
 END IF;
 IF (k IS NOT NULL OR old_k IS NOT NULL) AND auth.uid() IS NOT NULL THEN RAISE insufficient_privilege; END IF;
 IF TG_TABLE_NAME='conversations' THEN
  IF TG_OP='UPDATE' AND OLD.world_key IS DISTINCT FROM NEW.world_key THEN RAISE check_violation; END IF;
 END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
REVOKE ALL ON FUNCTION public.findez_guard_world_chat() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS world_chat_guard ON public.conversations;
CREATE TRIGGER world_chat_guard BEFORE INSERT OR UPDATE OR DELETE ON public.conversations FOR EACH ROW EXECUTE FUNCTION public.findez_guard_world_chat();
DROP TRIGGER IF EXISTS world_chat_guard ON public.messages;
CREATE TRIGGER world_chat_guard BEFORE INSERT OR UPDATE OR DELETE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.findez_guard_world_chat();

CREATE OR REPLACE FUNCTION public.findez_world_inventory_matches(p_actor uuid,p_world text,p_inventory uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT p_world IS NOT NULL AND public.findez_actor_active(p_actor)
  AND public.findez_inventory_role(p_inventory,p_actor) IS NOT NULL
  AND EXISTS(SELECT 1 FROM public.app_inventories i LEFT JOIN public.teams t USING(team_id)
   WHERE i.inventory_id=p_inventory AND coalesce(t.organization_id::text,'personal')=p_world
    AND (t.organization_id IS NULL OR EXISTS(SELECT 1 FROM public.app_organization_members m WHERE m.organization_id=t.organization_id AND m.user_id=p_actor)))
$$;
REVOKE ALL ON FUNCTION public.findez_world_inventory_matches(uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_world_inventory_matches(uuid,text,uuid) TO service_role;

-- Extend the existing, tested atomic item transaction. All its item snapshots,
-- permission locks, quotas, image checks and replay receipts remain in force.
DO $$
DECLARE definition text:=pg_get_functiondef('public.findez_chat_item_action(uuid,uuid,uuid,text,integer)'::regprocedure);
 marker text:='c.inventory_id=p_inventory AND m.inventory_id=p_inventory';
BEGIN
 IF position('findez_world_inventory_matches' IN definition)>0 THEN RETURN; END IF;
 IF position(marker IN definition)=0 THEN RAISE EXCEPTION 'Chat action source differs'; END IF;
 EXECUTE replace(definition,marker,'((c.world_key IS NULL AND c.inventory_id=p_inventory AND m.inventory_id=p_inventory) OR (a.value->>''world''=c.world_key AND public.findez_world_inventory_matches(p_actor,c.world_key,p_inventory)))');
END $$;

CREATE OR REPLACE FUNCTION public.findez_pending_world_image(p_actor uuid,p_path text) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE r record; a jsonb; i jsonb;
BEGIN
 FOR r IN SELECT m.answer_context,c.world_key FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
  WHERE c.user_id=p_actor AND c.world_key IS NOT NULL AND m.role='assistant' AND m.created_at>now()-interval '31 minutes' LOOP
  FOR a IN SELECT value FROM jsonb_array_elements(coalesce(r.answer_context->'pending_actions','[]')) LOOP
   IF a->>'operation'='add' AND a->>'status'='pending' AND a->>'world'=r.world_key
    AND (a->>'expires_at')::timestamptz>now()
    AND public.findez_world_inventory_matches(p_actor,r.world_key,(a->>'inventory_id')::uuid) THEN
    FOR i IN SELECT value FROM jsonb_array_elements(a->'items') LOOP
     IF p_path IN (public.findez_item_image_path(i->>'image_url'),public.findez_item_image_path(i->>'source_frame_url')) THEN RETURN true; END IF;
    END LOOP;
   END IF;
  END LOOP;
 END LOOP;
 RETURN false;
END $$;
REVOKE ALL ON FUNCTION public.findez_pending_world_image(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_pending_world_image(uuid,text) TO service_role;
DO $$
DECLARE definition text:=pg_get_functiondef('public.findez_can_read_item_image(uuid,text)'::regprocedure);
 marker text:='  OR public.findez_pending_chat_image(p_actor,p_path)';
BEGIN
 IF position('findez_pending_world_image' IN definition)>0 THEN RETURN; END IF;
 IF position(marker IN definition)=0 THEN RAISE EXCEPTION 'Photo authorization source differs'; END IF;
 EXECUTE replace(definition,marker,'  OR public.findez_pending_world_image(p_actor,p_path)'||chr(10)||marker);
END $$;
NOTIFY pgrst,'reload schema';

COMMIT;

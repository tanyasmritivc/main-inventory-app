-- Service-only delegated management, with current key authority and atomic receipts.
BEGIN;
CREATE TABLE IF NOT EXISTS public.api_agent_operations (
 key_id uuid NOT NULL REFERENCES public.api_keys(id) ON DELETE CASCADE,
 request_id uuid NOT NULL, request jsonb NOT NULL, receipt jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(key_id,request_id)
);
ALTER TABLE public.api_agent_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.api_agent_operations FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.api_agent_operations TO service_role;

CREATE OR REPLACE FUNCTION public.findez_agent_authority(p_key uuid,p_scope text,p_kind text,p_resource uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE k public.api_keys; org uuid; ws uuid; inv uuid; owner_id uuid; title text; actor uuid;
BEGIN
 SELECT * INTO STRICT k FROM public.api_keys WHERE id=p_key FOR SHARE;
 actor:=k.org_id;
 IF k.organization_id IS NULL OR k.workspace_id IS NOT NULL OR k.revoked_at IS NOT NULL
  OR k.expires_at<=now() OR NOT public.findez_actor_active(actor)
  OR NOT p_scope=ANY(k.scopes) THEN RAISE insufficient_privilege; END IF;
 PERFORM 1 FROM public.app_organizations WHERE organization_id=k.organization_id FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.app_organization_members
  WHERE organization_id=k.organization_id AND user_id=actor AND role IN ('owner','admin')) THEN RAISE insufficient_privilege; END IF;
 IF p_kind='organization' THEN
  IF p_resource IS DISTINCT FROM k.organization_id THEN RAISE insufficient_privilege; END IF;
  SELECT organization_id,owner_user_id,name INTO org,owner_id,title FROM public.app_organizations WHERE organization_id=p_resource;
 ELSIF p_kind='workspace' THEN
  SELECT organization_id,team_id,owner_user_id,name INTO org,ws,owner_id,title FROM public.teams WHERE team_id=p_resource FOR UPDATE;
 ELSIF p_kind IN ('inventory','space','item') THEN
  IF p_kind='inventory' THEN inv:=p_resource;
  ELSIF p_kind='space' THEN SELECT inventory_id INTO inv FROM public.spaces WHERE id=p_resource;
  ELSE SELECT inventory_id INTO inv FROM public.items WHERE item_id=p_resource; END IF;
  SELECT t.organization_id,i.team_id INTO org,ws FROM public.app_inventories i JOIN public.teams t ON t.team_id=i.team_id WHERE i.inventory_id=inv;
  IF org IS DISTINCT FROM k.organization_id THEN RAISE insufficient_privilege; END IF;
  PERFORM public.findez_lock_inventory_authority(inv,actor);
  SELECT owner_user_id,name INTO owner_id,title FROM public.app_inventories WHERE inventory_id=inv;
  IF p_kind='space' THEN SELECT name INTO STRICT title FROM public.spaces WHERE id=p_resource AND inventory_id=inv FOR UPDATE;
  ELSIF p_kind='item' THEN SELECT name INTO STRICT title FROM public.items WHERE item_id=p_resource AND inventory_id=inv FOR UPDATE; END IF;
 ELSE RAISE invalid_parameter_value; END IF;
 IF org IS DISTINCT FROM k.organization_id OR title IS NULL THEN RAISE insufficient_privilege; END IF;
 PERFORM set_config('request.headers',(coalesce(nullif(current_setting('request.headers',true),'')::jsonb,'{}')
  ||jsonb_build_object('x-findez-actor',actor))::text,true);
 RETURN jsonb_build_object('actor_id',actor,'organization_id',org,'workspace_id',ws,'inventory_id',inv,'owner_id',owner_id,'name',title);
END $$;

CREATE OR REPLACE FUNCTION public.findez_agent_manage(p_key uuid,p_request uuid,p_operation text,p_kind text,p_resource uuid,p_data jsonb,p_space_limit integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE authority jsonb; actor uuid; ws uuid; inv uuid; receipt jsonb; previous public.api_agent_operations;
 request jsonb; required_scope text; expected_kind text; target jsonb; changed uuid; role_name text;
BEGIN
 IF p_operation IN ('member_invite','member_change','member_remove','invitation_cancel','inventory_policy') THEN required_scope:='members:write';
 ELSE required_scope:='structure:write'; END IF;
 expected_kind:=CASE WHEN p_operation IN ('organization_rename','workspace_create') THEN 'organization'
  WHEN p_operation IN ('workspace_rename','inventory_create','location_create') THEN 'workspace'
  WHEN p_operation IN ('inventory_rename','space_create','inventory_policy','location_attach') THEN 'inventory'
  WHEN p_operation IN ('space_rename','space_move') THEN 'space'
  WHEN p_operation IN ('member_invite','member_change','member_remove','invitation_cancel') AND p_kind IN ('organization','workspace','inventory') THEN p_kind END;
 IF expected_kind IS NULL OR expected_kind<>p_kind OR jsonb_typeof(p_data)<>'object' THEN RAISE invalid_parameter_value; END IF;
 authority:=public.findez_agent_authority(p_key,required_scope,p_kind,p_resource);
 actor:=(authority->>'actor_id')::uuid; ws:=(authority->>'workspace_id')::uuid; inv:=(authority->>'inventory_id')::uuid;
 request:=jsonb_build_object('operation',p_operation,'kind',p_kind,'resource_id',p_resource,'data',p_data);
 PERFORM pg_advisory_xact_lock(hashtextextended('findez:agent-operation:'||p_key::text||':'||p_request::text,0));
 SELECT * INTO previous FROM public.api_agent_operations WHERE key_id=p_key AND request_id=p_request;
 IF FOUND THEN
  IF previous.request<>request THEN RAISE invalid_parameter_value USING MESSAGE='request_id_reused'; END IF;
  RETURN previous.receipt||CASE WHEN previous.receipt ? 'invitation_id' THEN jsonb_build_object('_skip_delivery',true) ELSE '{}'::jsonb END;
 END IF;
 IF p_operation IN ('organization_rename','workspace_rename','inventory_rename','workspace_create','inventory_create','space_create','space_rename','location_create')
  AND (p_data->>'name' IS NULL OR length(btrim(p_data->>'name')) NOT BETWEEN 1 AND 100) THEN RAISE invalid_parameter_value; END IF;
 IF p_operation='organization_rename' THEN
  IF authority->>'owner_id'<>actor::text THEN RAISE insufficient_privilege; END IF;
  UPDATE public.app_organizations SET name=btrim(p_data->>'name') WHERE organization_id=p_resource RETURNING jsonb_build_object('organization_id',organization_id,'name',name) INTO receipt;
 ELSIF p_operation='workspace_create' THEN
  receipt:=public.findez_manage_collaboration(actor,'workspace_create',p_data||jsonb_build_object('organization_id',p_resource));
 ELSIF p_operation='workspace_rename' THEN
  IF authority->>'owner_id'<>actor::text THEN RAISE insufficient_privilege; END IF;
  UPDATE public.teams SET name=btrim(p_data->>'name') WHERE team_id=p_resource RETURNING jsonb_build_object('workspace_id',team_id,'name',name) INTO receipt;
 ELSIF p_operation='inventory_create' THEN
  receipt:=public.findez_create_inventory(actor,ws,btrim(p_data->>'name'),coalesce(p_data->>'access_mode','workspace'));
 ELSIF p_operation='inventory_rename' THEN
  IF NOT public.findez_can_administer_inventory(inv,actor) THEN RAISE insufficient_privilege; END IF;
  UPDATE public.app_inventories SET name=btrim(p_data->>'name') WHERE inventory_id=inv RETURNING jsonb_build_object('inventory_id',inventory_id,'name',name) INTO receipt;
 ELSIF p_operation='space_create' THEN
  receipt:=public.findez_get_or_create_inventory_space(actor,inv,p_data->>'name',p_space_limit);
 ELSIF p_operation='space_rename' THEN
  IF NOT coalesce(public.findez_inventory_role(inv,actor) IN ('owner','admin','editor'),false) THEN RAISE insufficient_privilege; END IF;
  UPDATE public.spaces SET name=btrim(p_data->>'name') WHERE id=p_resource AND inventory_id=inv RETURNING jsonb_build_object('id',id,'name',name,'inventory_id',inventory_id) INTO receipt;
  UPDATE public.items SET location=btrim(p_data->>'name') WHERE inventory_id=inv AND space_id=p_resource;
 ELSIF p_operation='space_move' THEN
  target:=public.findez_agent_authority(p_key,required_scope,'inventory',(p_data->>'inventory_id')::uuid);
  IF target->>'workspace_id' IS DISTINCT FROM ws::text OR NOT coalesce(public.findez_inventory_role(inv,actor) IN ('owner','admin','editor'),false)
   OR NOT coalesce(public.findez_inventory_role((target->>'inventory_id')::uuid,actor) IN ('owner','admin','editor'),false) THEN RAISE insufficient_privilege; END IF;
  PERFORM public.findez_move_inventory_space(p_resource,(target->>'inventory_id')::uuid);
  receipt:=jsonb_build_object('id',p_resource,'inventory_id',target->>'inventory_id','moved',true);
 ELSIF p_operation='inventory_policy' THEN
  receipt:=public.findez_manage_collaboration(actor,'inventory_policy',p_data||jsonb_build_object('inventory_id',inv));
 ELSIF p_operation IN ('location_create','location_attach') THEN
  receipt:=public.findez_manage_collaboration(actor,p_operation,p_data||jsonb_build_object('team_id',ws,'inventory_id',inv));
 ELSIF p_operation IN ('member_change','member_remove') AND p_kind='organization' THEN
  receipt:=public.findez_manage_collaboration(actor,'organization_member',jsonb_build_object('organization_id',p_resource,
   'user_id',p_data->>'user_id','role',CASE WHEN p_operation='member_remove' THEN 'none' ELSE p_data->>'role' END));
 ELSIF p_operation IN ('member_invite','member_change','member_remove') THEN
  receipt:=public.findez_access_invitation(actor,CASE WHEN p_operation='member_invite' THEN 'create' ELSE 'change' END,
   p_data||jsonb_build_object('scope',p_kind,'resource_id',p_resource,'role',CASE WHEN p_operation='member_remove' THEN 'none' ELSE p_data->>'role' END));
 ELSIF p_operation='invitation_cancel' THEN
  PERFORM 1 FROM public.app_access_invitations WHERE invitation_id=(p_data->>'invitation_id')::uuid AND scope=p_kind AND resource_id=p_resource FOR UPDATE;
  IF NOT FOUND THEN RAISE no_data_found; END IF;
  receipt:=public.findez_access_invitation(actor,'cancel',jsonb_build_object('invitation_id',p_data->>'invitation_id'));
 END IF;
 IF receipt IS NULL THEN RAISE check_violation USING MESSAGE='missing_receipt'; END IF;
 INSERT INTO public.api_agent_operations(key_id,request_id,request,receipt) VALUES(p_key,p_request,request,receipt);
 INSERT INTO public.app_access_audit(actor_id,organization_id,team_id,inventory_id,action,target_id,changes)
 VALUES(actor,(authority->>'organization_id')::uuid,ws,inv,'agent_'||p_operation,p_resource,jsonb_build_object('key_id',p_key,'request_id',p_request));
 RETURN receipt;
END $$;
REVOKE ALL ON FUNCTION public.findez_agent_authority(uuid,text,text,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.findez_agent_manage(uuid,uuid,text,text,uuid,jsonb,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_agent_authority(uuid,text,text,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.findez_agent_manage(uuid,uuid,text,text,uuid,jsonb,integer) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

-- Explicit move-or-delete choices. Installing this migration changes no records.
BEGIN;
CREATE OR REPLACE FUNCTION public.findez_removal_authority(p_actor uuid,p_kind text,p_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE title text; owner_id uuid; inv uuid;
BEGIN
 IF NOT public.findez_actor_active(p_actor) THEN RAISE insufficient_privilege; END IF;
 IF p_kind='organization' THEN
  SELECT name,owner_user_id INTO title,owner_id FROM public.app_organizations WHERE organization_id=p_id FOR UPDATE;
  IF title IS NOT NULL AND (owner_id<>p_actor OR NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=p_id AND user_id=p_actor AND role='owner')) THEN RAISE insufficient_privilege; END IF;
 ELSIF p_kind='workspace' THEN
  SELECT name,owner_user_id INTO title,owner_id FROM public.teams WHERE team_id=p_id FOR UPDATE;
  IF title IS NOT NULL AND NOT (coalesce(public.findez_workspace_role(p_id,p_actor) IN ('owner','mentor'),false) OR coalesce(public.findez_workspace_organization_admin(p_id,p_actor),false)) THEN RAISE insufficient_privilege; END IF;
 ELSIF p_kind='inventory' THEN
  PERFORM public.findez_lock_inventory_authority(p_id,p_actor);
  SELECT name INTO title FROM public.app_inventories WHERE inventory_id=p_id FOR UPDATE;
  IF title IS NOT NULL AND NOT coalesce(public.findez_can_administer_inventory(p_id,p_actor),false) THEN RAISE insufficient_privilege; END IF;
 ELSIF p_kind='space' THEN
  SELECT inventory_id INTO inv FROM public.spaces WHERE id=p_id;
  IF inv IS NOT NULL THEN PERFORM public.findez_lock_inventory_authority(inv,p_actor); END IF;
  SELECT name INTO title FROM public.spaces WHERE id=p_id FOR UPDATE;
  IF title IS NOT NULL AND NOT coalesce(public.findez_inventory_role(inv,p_actor) IN ('owner','admin'),false) THEN RAISE insufficient_privilege; END IF;
 ELSE RAISE invalid_parameter_value; END IF;
 IF title IS NULL THEN RAISE no_data_found; END IF;
 RETURN title;
END $$;
REVOKE ALL ON FUNCTION public.findez_removal_authority(uuid,text,uuid) FROM PUBLIC,anon,authenticated,service_role;

-- Internal moves explicitly unlink legacy workspace-Space associations without
-- the older unlink trigger moving each Space to a different default inventory.
CREATE OR REPLACE FUNCTION pg_temp.removal_patch(target regprocedure,old_sql text,new_sql text) RETURNS void
LANGUAGE plpgsql AS $$ DECLARE definition text:=pg_get_functiondef(target); BEGIN
 IF position(new_sql IN definition)>0 THEN RETURN; END IF;
 IF position(old_sql IN definition)=0 THEN RAISE EXCEPTION 'Unexpected definition for %',target; END IF;
 EXECUTE replace(definition,old_sql,new_sql);
END $$;
SELECT pg_temp.removal_patch('public.findez_team_space_inventory()', 'BEGIN', $new$BEGIN
  IF TG_OP='DELETE' AND current_setting('findez.lifecycle_unlink',true)='true' THEN RETURN OLD; END IF;$new$);

-- Workspace Admins can remove peer Admins; designated Owners stay protected.
SELECT pg_temp.removal_patch('public.findez_guard_workspace_assignment()',
 $old$IF TG_OP<>'INSERT' AND (OLD.role='owner' OR OLD.role='mentor' AND caller<>'owner') THEN RAISE insufficient_privilege; END IF;$old$,
 $new$IF TG_OP<>'INSERT' AND (OLD.role='owner' OR TG_OP<>'DELETE' AND OLD.role='mentor' AND caller<>'owner') THEN RAISE insufficient_privilege; END IF;$new$);
SELECT pg_temp.removal_patch('public.findez_delete_inventory_team(uuid,uuid)',
 $old$IF NOT public.findez_actor_active(p_actor_id) OR (owner_id<>p_actor_id AND NOT coalesce(public.findez_workspace_organization_admin(p_team_id,p_actor_id),false)) THEN RAISE insufficient_privilege USING message='Workspace owner or organization administrator required'; END IF;$old$,
 $new$IF NOT public.findez_actor_active(p_actor_id) OR NOT coalesce(public.findez_workspace_role(p_team_id,p_actor_id) IN ('owner','mentor'),false) THEN RAISE insufficient_privilege USING message='Workspace owner or administrator required'; END IF;$new$);

SELECT pg_temp.removal_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)',
 $old$(old_value->>'role'='mentor' AND caller<>'owner')$old$,
 $new$(old_value->>'role'='mentor' AND caller<>'owner' AND role_name<>'none')$new$);

CREATE OR REPLACE FUNCTION public.findez_removal_preview(p_actor uuid,p_kind text,p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE title text; ws_count int:=0; inv_count int:=0; space_count int:=0; item_count int:=0;
 inv_ids uuid[]; options jsonb:='[]'; can_move boolean:=true;
BEGIN
 title:=public.findez_removal_authority(p_actor,p_kind,p_id);
 IF p_kind='organization' THEN
  SELECT count(*) INTO ws_count FROM public.teams WHERE organization_id=p_id;
  SELECT array_agg(inventory_id) INTO inv_ids FROM public.app_inventories WHERE team_id IN(SELECT team_id FROM public.teams WHERE organization_id=p_id);
 ELSIF p_kind='workspace' THEN
  SELECT array_agg(inventory_id) INTO inv_ids FROM public.app_inventories WHERE team_id=p_id;
 ELSIF p_kind='inventory' THEN
  inv_ids:=ARRAY[p_id];
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.team_id,'name',coalesce(o.name||' / ','')||t.name) ORDER BY t.name),'[]') INTO options
   FROM public.app_inventories i JOIN public.teams t ON t.owner_user_id=i.owner_user_id AND t.team_id IS DISTINCT FROM i.team_id
   LEFT JOIN public.app_organizations o ON o.organization_id=t.organization_id
   WHERE i.inventory_id=p_id AND coalesce(public.findez_workspace_role(t.team_id,p_actor) IN ('owner','mentor'),false);
  IF EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=p_id AND team_id IS NOT NULL) THEN options:=jsonb_build_array(jsonb_build_object('id','personal','name','Existing owner’s Personal area'))||options; END IF;
  can_move:=jsonb_array_length(options)>0;
 ELSE
  SELECT count(*) INTO item_count FROM public.items WHERE space_id=p_id;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.name) ORDER BY d.name),'[]') INTO options
   FROM public.spaces s JOIN public.spaces d ON d.inventory_id=s.inventory_id AND d.id<>s.id WHERE s.id=p_id;
  can_move:=jsonb_array_length(options)>0;
 END IF;
 IF inv_ids IS NOT NULL THEN
  inv_count:=cardinality(inv_ids);
  SELECT count(*) INTO space_count FROM public.spaces WHERE inventory_id=ANY(inv_ids);
  SELECT count(*) INTO item_count FROM public.items WHERE inventory_id=ANY(inv_ids);
 END IF;
 RETURN jsonb_build_object('kind',p_kind,'id',p_id,'name',title,'workspaces',ws_count,'inventories',inv_count,'spaces',space_count,'items',item_count,'can_move',can_move,'destinations',options);
END $$;
REVOKE ALL ON FUNCTION public.findez_removal_preview(uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_removal_preview(uuid,text,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_detach_inventory(p_inventory uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.app_inventories; new_name text; flag text;
BEGIN
 SELECT * INTO STRICT inv FROM public.app_inventories WHERE inventory_id=p_inventory FOR UPDATE;
 IF inv.team_id IS NULL THEN RETURN; END IF;
 flag:=current_setting('findez.lifecycle_unlink',true);
 PERFORM set_config('findez.lifecycle_unlink','true',true);
 DELETE FROM public.team_spaces WHERE space_id IN(SELECT id FROM public.spaces WHERE inventory_id=p_inventory);
 PERFORM set_config('findez.lifecycle_unlink',coalesce(flag,''),true);
 new_name:=inv.name;
 IF EXISTS(SELECT 1 FROM public.app_inventories WHERE owner_user_id=inv.owner_user_id AND team_id IS NULL AND lower(name)=lower(new_name)) THEN
  new_name:=left(inv.name,55)||' - '||p_inventory::text;
 END IF;
 UPDATE public.spaces SET physical_location_id=NULL WHERE inventory_id=p_inventory;
 UPDATE public.items SET workspace_id=NULL WHERE inventory_id=p_inventory;
 UPDATE public.app_inventories SET team_id=NULL,is_default=false,name=new_name,access_mode='legacy' WHERE inventory_id=p_inventory;
 DELETE FROM public.app_inventory_members WHERE inventory_id=p_inventory;
 DELETE FROM public.app_inventory_access_requests WHERE inventory_id=p_inventory;
 DELETE FROM public.app_access_invitations WHERE inventory_id=p_inventory;
 UPDATE public.project_kits SET share_id=NULL WHERE inventory_id=p_inventory;
 DELETE FROM public.team_shares WHERE inventory_id=p_inventory;
END $$;
REVOKE ALL ON FUNCTION public.findez_detach_inventory(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.findez_remove_resource(p_actor uuid,p_kind text,p_id uuid,p_name text,p_action text,p_destination uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE title text; headers text; flag text; inv record; ws record; s public.spaces; destination public.spaces; receipt jsonb;
 cleanup uuid[]:='{}'; old_team uuid; preview jsonb;
BEGIN
 IF p_action NOT IN ('move','delete') THEN RAISE invalid_parameter_value; END IF;
 BEGIN title:=public.findez_removal_authority(p_actor,p_kind,p_id);
 EXCEPTION WHEN no_data_found THEN
  SELECT changes->'receipt' INTO receipt FROM public.app_access_audit WHERE actor_id=p_actor AND target_id=p_id AND action='resource_removal' AND changes->>'kind'=p_kind ORDER BY created_at DESC LIMIT 1;
  IF receipt IS NOT NULL THEN RETURN receipt; END IF; RAISE;
 END;
 IF p_name IS DISTINCT FROM title THEN RAISE serialization_failure; END IF;
 preview:=public.findez_removal_preview(p_actor,p_kind,p_id);
 IF p_action='move' AND NOT (preview->>'can_move')::boolean THEN RAISE invalid_parameter_value; END IF;
 IF p_kind='space' AND p_action='move' THEN
  SELECT * INTO STRICT s FROM public.spaces WHERE id=p_id;
  SELECT * INTO destination FROM public.spaces WHERE id=p_destination AND id<>p_id AND inventory_id=s.inventory_id FOR UPDATE;
  IF NOT FOUND THEN RAISE invalid_parameter_value; END IF;
 ELSIF p_kind='inventory' AND p_action='move' AND p_destination IS NOT NULL THEN
  PERFORM 1 FROM public.app_inventories i JOIN public.teams t ON t.owner_user_id=i.owner_user_id WHERE i.inventory_id=p_id AND t.team_id=p_destination AND t.team_id IS DISTINCT FROM i.team_id FOR UPDATE OF t;
  IF NOT FOUND OR NOT coalesce(public.findez_workspace_role(p_destination,p_actor) IN ('owner','mentor'),false) THEN RAISE insufficient_privilege; END IF;
 ELSIF p_kind='inventory' AND p_action='move' AND NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=p_id AND team_id IS NOT NULL) THEN RAISE invalid_parameter_value;
 ELSIF p_destination IS NOT NULL THEN RAISE invalid_parameter_value; END IF;
 headers:=current_setting('request.headers',true);
 -- Authority is checked and locked above. Internal parent changes do not use
 -- the generic row-editor guards, which deliberately disallow reparenting.
 PERFORM set_config('request.headers',(coalesce(nullif(headers,'')::jsonb,'{}')-'x-findez-actor')::text,true);
 flag:=current_setting('findez.lifecycle_unlink',true);
 PERFORM set_config('findez.lifecycle_unlink','true',true);
 IF p_kind='organization' AND p_action='move' THEN
  -- Keep workspace memberships and contents; only remove the org boundary.
  UPDATE public.teams SET organization_id=NULL WHERE organization_id=p_id;
  DELETE FROM public.app_organizations WHERE organization_id=p_id;
 ELSIF p_kind IN ('organization','workspace') THEN
  FOR ws IN SELECT * FROM public.teams WHERE (p_kind='organization' AND organization_id=p_id) OR (p_kind='workspace' AND team_id=p_id) ORDER BY team_id FOR UPDATE LOOP
   FOR inv IN SELECT * FROM public.app_inventories WHERE team_id=ws.team_id ORDER BY inventory_id FOR UPDATE LOOP
    IF p_action='move' THEN PERFORM public.findez_detach_inventory(inv.inventory_id);
    ELSE
     PERFORM public.findez_delete_inventory_contents(p_actor,inv.inventory_id,inv.name);
     cleanup:=array_append(cleanup,inv.inventory_id);
    END IF;
   END LOOP;
   PERFORM public.findez_delete_inventory_team(ws.team_id,p_actor);
  END LOOP;
  IF p_kind='organization' THEN DELETE FROM public.app_organizations WHERE organization_id=p_id; END IF;
 ELSIF p_kind='inventory' THEN
  IF p_action='move' THEN
   PERFORM public.findez_detach_inventory(p_id);
   IF p_destination IS NOT NULL THEN
    SELECT * INTO inv FROM public.app_inventories WHERE inventory_id=p_id;
    UPDATE public.app_inventories SET team_id=p_destination,access_mode='workspace',is_default=false,
     name=CASE WHEN EXISTS(SELECT 1 FROM public.app_inventories d WHERE d.team_id=p_destination AND lower(d.name)=lower(inv.name)) THEN left(inv.name,55)||' - '||p_id::text ELSE inv.name END WHERE inventory_id=p_id;
    UPDATE public.items SET workspace_id=p_destination WHERE inventory_id=p_id;
    DELETE FROM public.app_inventory_members WHERE inventory_id=p_id;
    DELETE FROM public.app_inventory_access_requests WHERE inventory_id=p_id;
    DELETE FROM public.app_access_invitations WHERE inventory_id=p_id;
    UPDATE public.project_kits SET share_id=NULL WHERE inventory_id=p_id;
    DELETE FROM public.team_shares WHERE inventory_id=p_id;
    INSERT INTO public.team_spaces(team_id,space_id,linked_by) SELECT p_destination,id,p_actor FROM public.spaces WHERE inventory_id=p_id ON CONFLICT(space_id) DO NOTHING;
   END IF;
  ELSE
   PERFORM public.findez_delete_inventory_contents(p_actor,p_id,title); cleanup:=ARRAY[p_id];
  END IF;
 ELSE
  SELECT * INTO STRICT s FROM public.spaces WHERE id=p_id;
  IF p_action='move' THEN
   -- Preserve IDs, photos, bins, task/history links and review provenance.
   UPDATE public.bins b SET name=left(b.name,60)||' - '||left(b.id::text,8) WHERE b.space_id=p_id AND EXISTS(SELECT 1 FROM public.bins d WHERE d.space_id=destination.id AND d.name=b.name);
   UPDATE public.bins SET space_id=destination.id WHERE space_id=p_id;
   UPDATE public.items SET space_id=destination.id,location=destination.name WHERE space_id=p_id;
   UPDATE public.capture_reviews SET space_id=destination.id,location=destination.name WHERE space_id=p_id;
   UPDATE public.project_kits SET location=destination.name,share_id=NULL WHERE inventory_id=s.inventory_id AND lower(location)=lower(s.name);
  END IF;
  DELETE FROM public.spaces WHERE id=p_id;
 END IF;
 receipt:=jsonb_build_object('kind',p_kind,'id',p_id,'action',p_action,'deleted',NOT(p_kind='inventory' AND p_action='move'),'moved',p_action='move','cleanup_inventories',to_jsonb(cleanup));
 INSERT INTO public.app_access_audit(actor_id,action,target_id,changes) VALUES(p_actor,'resource_removal',p_id,jsonb_build_object('kind',p_kind,'before',preview,'receipt',receipt,'destination',p_destination));
 PERFORM set_config('findez.lifecycle_unlink',coalesce(flag,''),true);
 PERFORM set_config('request.headers',coalesce(headers,''),true);
 RETURN receipt;
END $$;
REVOKE ALL ON FUNCTION public.findez_remove_resource(uuid,text,uuid,text,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_remove_resource(uuid,text,uuid,text,text,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_remove_organization_member(p_actor uuid,p_organization uuid,p_member uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE owner_id uuid; target_role text; headers text; ws record;
BEGIN
 IF NOT public.findez_actor_active(p_actor) THEN RAISE insufficient_privilege; END IF;
 SELECT owner_user_id INTO owner_id FROM public.app_organizations WHERE organization_id=p_organization FOR UPDATE;
 IF NOT FOUND THEN RAISE no_data_found; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=p_organization AND user_id=p_actor AND role IN ('owner','admin')) THEN RAISE insufficient_privilege; END IF;
 SELECT role INTO target_role FROM public.app_organization_members WHERE organization_id=p_organization AND user_id=p_member FOR UPDATE;
 IF p_member=owner_id OR target_role='owner' THEN RAISE insufficient_privilege; END IF;
 IF target_role IS NULL THEN RETURN jsonb_build_object('removed',true,'user_id',p_member); END IF;
 headers:=current_setting('request.headers',true);
 PERFORM set_config('request.headers',(coalesce(nullif(headers,'')::jsonb,'{}')-'x-findez-actor')::text,true);
 FOR ws IN SELECT * FROM public.teams WHERE organization_id=p_organization ORDER BY team_id FOR UPDATE LOOP
  IF ws.owner_user_id=p_member THEN
   INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws.team_id,owner_id,'owner') ON CONFLICT(team_id,user_id) DO UPDATE SET role='owner';
   UPDATE public.teams SET owner_user_id=owner_id WHERE team_id=ws.team_id;
  END IF;
 END LOOP;
 DELETE FROM public.app_inventory_members m USING public.app_inventories i,public.teams t WHERE m.user_id=p_member AND m.inventory_id=i.inventory_id AND i.team_id=t.team_id AND t.organization_id=p_organization;
 DELETE FROM public.team_members m USING public.team_shares s,public.app_inventories i,public.teams t WHERE m.member_user_id=p_member AND m.share_id=s.share_id AND s.inventory_id=i.inventory_id AND i.team_id=t.team_id AND t.organization_id=p_organization;
 DELETE FROM public.team_memberships m USING public.teams t WHERE m.user_id=p_member AND m.team_id=t.team_id AND t.organization_id=p_organization;
 UPDATE public.app_access_invitations SET status='cancelled',decided_at=now() WHERE organization_id=p_organization AND status='pending' AND (invited_by=p_member OR lower(recipient_email)=(SELECT lower(email) FROM auth.users WHERE id=p_member));
 DELETE FROM public.app_organization_members WHERE organization_id=p_organization AND user_id=p_member;
 INSERT INTO public.app_access_audit(actor_id,organization_id,action,target_id,changes) VALUES(p_actor,p_organization,'organization_member_removed',p_member,jsonb_build_object('previous_role',target_role,'workspace_owner_successor',owner_id));
 PERFORM set_config('request.headers',coalesce(headers,''),true);
 RETURN jsonb_build_object('removed',true,'user_id',p_member);
END $$;
REVOKE ALL ON FUNCTION public.findez_remove_organization_member(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_remove_organization_member(uuid,uuid,uuid) TO service_role;

NOTIFY pgrst,'reload schema';
COMMIT;

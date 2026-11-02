-- User-approved target policy. No customer records are created or deleted here.
-- Workspace role names remain owner/mentor/member/viewer for old clients.
BEGIN;
ALTER TABLE public.app_access_invitations ADD COLUMN IF NOT EXISTS inventory_assignment_before jsonb;
ALTER TABLE public.app_inventory_members ADD COLUMN IF NOT EXISTS permission_revision uuid NOT NULL DEFAULT gen_random_uuid();
CREATE OR REPLACE FUNCTION public.findez_inventory_assignment_revision() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$ BEGIN NEW.permission_revision:=gen_random_uuid(); RETURN NEW; END $$;
REVOKE ALL ON FUNCTION public.findez_inventory_assignment_revision() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS permission_inventory_assignment_revision ON public.app_inventory_members;
CREATE TRIGGER permission_inventory_assignment_revision BEFORE UPDATE ON public.app_inventory_members
 FOR EACH ROW EXECUTE FUNCTION public.findez_inventory_assignment_revision();
ALTER TABLE public.app_inventory_members DROP CONSTRAINT IF EXISTS app_inventory_members_role_check;
ALTER TABLE public.app_inventory_members ADD CONSTRAINT app_inventory_members_role_check
 CHECK(role IN ('owner','admin','editor','viewer','none'));

CREATE OR REPLACE FUNCTION public.findez_actor_active(p_actor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=p_actor
  AND nullif(to_jsonb(u)->>'deleted_at','') IS NULL
  AND (nullif(to_jsonb(u)->>'banned_until','') IS NULL
       OR (to_jsonb(u)->>'banned_until')::timestamptz<=now()))
$$;
REVOKE ALL ON FUNCTION public.findez_actor_active(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_actor_active(uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.findez_active_storage_account() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT public.findez_actor_active(auth.uid())
$$;

CREATE OR REPLACE FUNCTION public.findez_workspace_role(p_workspace uuid,p_actor uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT m.role FROM public.teams t JOIN public.team_memberships m USING(team_id)
 WHERE t.team_id=p_workspace AND m.user_id=p_actor AND public.findez_actor_active(p_actor)
 AND (t.organization_id IS NULL OR EXISTS(SELECT 1 FROM public.app_organization_members om
  WHERE om.organization_id=t.organization_id AND om.user_id=p_actor))
$$;
REVOKE ALL ON FUNCTION public.findez_workspace_role(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_workspace_role(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_inventory_role(p_inventory uuid,p_actor uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT CASE
  WHEN NOT public.findez_actor_active(p_actor) THEN NULL
  WHEN i.team_id IS NULL THEN CASE WHEN i.owner_user_id=p_actor THEN 'owner' END
  WHEN w.role IS NULL THEN NULL
  WHEN g.role='none' THEN NULL
  WHEN g.role IS NOT NULL THEN g.role
  WHEN i.access_mode='restricted' THEN NULL
  ELSE CASE w.role WHEN 'owner' THEN 'owner' WHEN 'mentor' THEN 'admin'
   WHEN 'member' THEN 'editor' WHEN 'viewer' THEN 'viewer' END END
 FROM public.app_inventories i
 CROSS JOIN LATERAL (SELECT public.findez_workspace_role(i.team_id,p_actor) AS role) w
 LEFT JOIN public.app_inventory_members g ON g.inventory_id=i.inventory_id AND g.user_id=p_actor
 WHERE i.inventory_id=p_inventory
$$;

CREATE OR REPLACE FUNCTION public.findez_can_administer_inventory(p_inventory uuid,p_actor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(public.findez_inventory_role(i.inventory_id,p_actor) IN ('owner','admin')
  OR public.findez_workspace_role(i.team_id,p_actor) IN ('owner','mentor'),false)
 FROM public.app_inventories i WHERE i.inventory_id=p_inventory
$$;
REVOKE ALL ON FUNCTION public.findez_can_administer_inventory(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_can_administer_inventory(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_create_inventory(p_actor uuid,p_workspace uuid,p_name text,p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE resource public.app_inventories; owner_id uuid:=p_actor; caller text; first_inventory boolean;
BEGIN
 IF NOT public.findez_actor_active(p_actor) THEN RAISE insufficient_privilege; END IF;
 IF p_mode NOT IN ('workspace','restricted') OR length(btrim(p_name)) NOT BETWEEN 1 AND 100 THEN RAISE invalid_parameter_value; END IF;
 IF p_workspace IS NOT NULL THEN
  SELECT owner_user_id INTO owner_id FROM public.teams WHERE team_id=p_workspace FOR UPDATE;
  caller:=public.findez_workspace_role(p_workspace,p_actor);
  IF caller IS NULL OR caller NOT IN ('owner','mentor') THEN RAISE insufficient_privilege; END IF;
 ELSE
  PERFORM 1 FROM auth.users WHERE id=p_actor FOR UPDATE;
  caller:='owner';
 END IF;
 first_inventory:=NOT EXISTS(SELECT 1 FROM public.app_inventories
  WHERE owner_user_id=owner_id AND team_id IS NOT DISTINCT FROM p_workspace);
 INSERT INTO public.app_inventories(owner_user_id,team_id,created_by_user_id,name,is_default,access_mode,default_role)
  VALUES(owner_id,p_workspace,p_actor,btrim(p_name),first_inventory,p_mode,'viewer') RETURNING * INTO resource;
 IF p_mode='restricted' AND p_workspace IS NOT NULL THEN
  INSERT INTO public.app_inventory_members(inventory_id,user_id,role)
   VALUES(resource.inventory_id,p_actor,CASE caller WHEN 'owner' THEN 'owner' ELSE 'admin' END);
 END IF;
 INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
 VALUES(p_actor,p_workspace,resource.inventory_id,'inventory_create',resource.inventory_id,
  jsonb_build_object('access_mode',p_mode));
 RETURN to_jsonb(resource);
END $$;
REVOKE ALL ON FUNCTION public.findez_create_inventory(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_create_inventory(uuid,uuid,text,text) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_inventory_fences(p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(jsonb_build_object('inventory_id',i.inventory_id,
  'team_id',i.team_id,'role',public.findez_inventory_role(i.inventory_id,p_actor))),'[]'::jsonb)
 FROM public.app_inventories i WHERE i.team_id IS NOT NULL OR i.access_mode<>'legacy'
 OR EXISTS(SELECT 1 FROM public.app_inventory_members m WHERE m.inventory_id=i.inventory_id)
$$;

CREATE OR REPLACE FUNCTION public.findez_inventory_policy(p_inventory uuid,p_write boolean) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.app_inventories; role_name text; claims jsonb; actor uuid;
BEGIN
 SELECT * INTO inv FROM public.app_inventories WHERE inventory_id=p_inventory;
 IF NOT FOUND THEN RETURN false; END IF;
 claims:=nullif(current_setting('request.jwt.claims',true),'')::jsonb;
 IF claims ? 'api_key_id' THEN
  role_name:=public.findez_inventory_role(p_inventory,inv.owner_user_id);
  RETURN public.findez_api_can_access_workspace(inv.team_id)
   AND public.findez_workspace_role(inv.team_id,inv.owner_user_id)='owner'
   AND role_name IS NOT NULL AND (NOT p_write OR role_name IN ('owner','admin','editor'));
 END IF;
 actor:=public.findez_request_actor();
 IF NOT public.findez_actor_active(actor) THEN RETURN false; END IF;
 -- Preserve the original row-level owner/Shared Space policies for private
 -- legacy inventories. This does not expose a whole inventory to a recipient.
 IF inv.team_id IS NULL AND inv.access_mode='legacy' AND NOT EXISTS(
  SELECT 1 FROM public.app_inventory_members WHERE inventory_id=p_inventory) THEN RETURN true; END IF;
 role_name:=public.findez_inventory_role(p_inventory,actor);
 RETURN coalesce(role_name IS NOT NULL AND (NOT p_write OR role_name IN ('owner','admin','editor')),false);
END $$;

CREATE OR REPLACE FUNCTION public.findez_directory_entry(p_inventory uuid,p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT jsonb_build_object('inventory_id',i.inventory_id,'workspace_id',coalesce(i.team_id::text,'personal'),
  'name',i.name,'description',i.directory_description,'can_open',r.role IS NOT NULL,
  'can_edit',coalesce(r.role IN ('owner','admin','editor'),false),
  'can_manage',a.allowed,'can_rename',a.allowed,'directory_visibility',i.directory_visibility,'role',r.role)
  || CASE WHEN r.role IS NOT NULL THEN jsonb_build_object('item_count',
    (SELECT count(*) FROM public.items x WHERE x.inventory_id=i.inventory_id)) ELSE '{}'::jsonb END
 FROM public.app_inventories i
 CROSS JOIN LATERAL (SELECT public.findez_inventory_role(i.inventory_id,p_actor) AS role) r
 CROSS JOIN LATERAL (SELECT coalesce(public.findez_can_administer_inventory(i.inventory_id,p_actor),false) AS allowed) a
 WHERE i.inventory_id=p_inventory AND (r.role IS NOT NULL OR a.allowed)
$$;

CREATE OR REPLACE FUNCTION public.findez_can_invite_access(actor uuid,kind text,resource uuid,requested text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE caller text;
BEGIN
 IF NOT public.findez_actor_active(actor) THEN RETURN false; END IF;
 IF kind='organization' THEN
  SELECT role INTO caller FROM public.app_organization_members WHERE organization_id=resource AND user_id=actor;
  RETURN coalesce(caller IN ('owner','admin') AND requested IN ('member','admin') AND (requested<>'admin' OR caller='owner'),false);
 ELSIF kind='workspace' THEN
  caller:=public.findez_workspace_role(resource,actor);
  RETURN coalesce(caller IN ('owner','mentor') AND requested IN ('admin','editor','viewer') AND (requested<>'admin' OR caller='owner'),false);
 ELSIF kind='inventory' THEN
  RETURN coalesce(public.findez_can_administer_inventory(resource,actor)
   AND requested IN ('admin','editor','viewer','inherit'),false);
 END IF;
 RETURN false;
END $$;

-- Assert the reviewed prior source before replacing narrow branches. Do not
-- silently apply against drifted functions, and make rehearsed replay safe.
CREATE OR REPLACE FUNCTION pg_temp.permission_patch(target regprocedure,old_sql text,new_sql text) RETURNS void
LANGUAGE plpgsql AS $$ DECLARE definition text:=pg_get_functiondef(target); BEGIN
 IF position(new_sql IN definition)>0 THEN RETURN; END IF;
 IF position(old_sql IN definition)=0 THEN RAISE EXCEPTION 'Permission source differs for %',target; END IF;
 EXECUTE replace(definition,old_sql,new_sql);
END $$;

-- Serialize authority with workspace membership/ownership changes.
CREATE OR REPLACE FUNCTION public.findez_lock_inventory_authority(p_inventory uuid,p_actor uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE ws uuid; org uuid; expected_ws uuid;
BEGIN
 SELECT team_id INTO ws FROM public.app_inventories WHERE inventory_id=p_inventory;
 IF NOT FOUND THEN RAISE no_data_found; END IF;
 IF ws IS NOT NULL THEN
  SELECT organization_id INTO org FROM public.teams WHERE team_id=ws;
  IF org IS NOT NULL THEN PERFORM 1 FROM public.app_organizations WHERE organization_id=org FOR UPDATE; END IF;
  PERFORM 1 FROM public.teams WHERE team_id=ws FOR UPDATE;
  IF NOT FOUND THEN RAISE no_data_found; END IF;
 END IF;
 SELECT team_id INTO expected_ws FROM public.app_inventories WHERE inventory_id=p_inventory FOR UPDATE;
 IF NOT FOUND OR expected_ws IS DISTINCT FROM ws THEN RAISE serialization_failure; END IF;
END $$;
REVOKE ALL ON FUNCTION public.findez_lock_inventory_authority(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_lock_inventory_authority(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_guard_workspace_assignment() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor(); ws uuid:=coalesce(NEW.team_id,OLD.team_id); caller text; parent public.teams;
BEGIN
 IF actor IS NULL THEN RETURN coalesce(NEW,OLD); END IF;
 SELECT * INTO parent FROM public.teams WHERE team_id=ws FOR UPDATE;
 IF NOT FOUND AND TG_OP='DELETE' THEN RETURN OLD; END IF;
 IF NOT FOUND OR NOT public.findez_actor_active(actor) THEN RAISE insufficient_privilege; END IF;
 caller:=public.findez_workspace_role(ws,actor);
 IF TG_OP='INSERT' AND NEW.user_id=actor AND NEW.role='owner' AND parent.owner_user_id=actor
  AND NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws)
  AND (parent.organization_id IS NULL OR EXISTS(SELECT 1 FROM public.app_organization_members
   WHERE organization_id=parent.organization_id AND user_id=actor AND role IN ('owner','admin'))) THEN RETURN NEW; END IF;
 IF TG_OP='DELETE' AND OLD.user_id=actor AND OLD.role<>'owner' THEN RETURN OLD; END IF;
 IF caller IS NULL OR caller NOT IN ('owner','mentor') THEN RAISE insufficient_privilege; END IF;
 IF TG_OP<>'INSERT' AND (OLD.role='owner' OR OLD.role='mentor' AND caller<>'owner') THEN RAISE insufficient_privilege; END IF;
 IF TG_OP='UPDATE' AND (NEW.team_id<>OLD.team_id OR NEW.user_id<>OLD.user_id) THEN RAISE insufficient_privilege; END IF;
 IF TG_OP<>'DELETE' AND (NEW.role='owner' OR NEW.role='mentor' AND caller<>'owner') THEN RAISE insufficient_privilege; END IF;
 RETURN coalesce(NEW,OLD);
END $$;
REVOKE ALL ON FUNCTION public.findez_guard_workspace_assignment() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS permission_workspace_assignment ON public.team_memberships;
CREATE TRIGGER permission_workspace_assignment BEFORE INSERT OR UPDATE OR DELETE ON public.team_memberships
 FOR EACH ROW EXECUTE FUNCTION public.findez_guard_workspace_assignment();

CREATE OR REPLACE FUNCTION public.findez_guard_inventory_administration() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor();
BEGIN
 IF actor IS NULL THEN RETURN coalesce(NEW,OLD); END IF;
 IF TG_OP='DELETE' AND OLD.team_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.teams WHERE team_id=OLD.team_id) THEN RETURN OLD; END IF;
 PERFORM public.findez_lock_inventory_authority(OLD.inventory_id,actor);
 IF NOT coalesce(public.findez_can_administer_inventory(OLD.inventory_id,actor),false) THEN RAISE insufficient_privilege; END IF;
 IF TG_OP='UPDATE' AND (NEW.owner_user_id<>OLD.owner_user_id OR NEW.team_id IS DISTINCT FROM OLD.team_id) THEN RAISE insufficient_privilege; END IF;
 RETURN coalesce(NEW,OLD);
END $$;
REVOKE ALL ON FUNCTION public.findez_guard_inventory_administration() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS permission_inventory_administration ON public.app_inventories;
CREATE TRIGGER permission_inventory_administration BEFORE UPDATE OR DELETE ON public.app_inventories
 FOR EACH ROW EXECUTE FUNCTION public.findez_guard_inventory_administration();

SELECT pg_temp.permission_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)',
 $old$ELSIF p_action IN ('inventory_policy','inventory_member') THEN$old$,
 $new$ELSIF p_action IN ('inventory_policy','inventory_member') THEN
  PERFORM public.findez_lock_inventory_authority(inv,p_actor);$new$);

SELECT pg_temp.permission_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)',
 $old$(old_value->>'role'='admin' AND caller<>'owner')$old$,
 $new$(old_value->>'role'='admin' AND caller<>'owner' AND role_name<>'none')$new$);
SELECT pg_temp.permission_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)',
 $old$caller:=public.findez_inventory_role(inv,p_actor);
  IF ws IS NULL OR caller IS NULL OR caller NOT IN ('owner','admin') THEN RAISE insufficient_privilege; END IF;$old$,
 $new$caller:=public.findez_inventory_role(inv,p_actor);
  IF ws IS NULL OR NOT coalesce(public.findez_can_administer_inventory(inv,p_actor),false) THEN RAISE insufficient_privilege; END IF;$new$);
SELECT pg_temp.permission_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)',
 $old$IF EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=target AND role IN ('owner','mentor')) THEN RAISE check_violation USING message='Workspace administrators retain inventory administration.'; END IF;$old$,
 $new$-- Content assignments, including No access, also apply to workspace administrators.$new$);
SELECT pg_temp.permission_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)',
 $old$IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN RAISE insufficient_privilege; END IF;$old$,
 $new$IF NOT public.findez_actor_active(p_actor) THEN RAISE insufficient_privilege; END IF;$new$);
SELECT pg_temp.permission_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)',
 $old$SELECT role INTO caller FROM public.team_memberships WHERE team_id=ws AND user_id=p_actor;$old$,
 $new$caller:=public.findez_workspace_role(ws,p_actor);$new$);

SELECT pg_temp.permission_patch('public.findez_workspace_directory(uuid,text,jsonb)',
 $old$IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN RAISE insufficient_privilege; END IF;$old$,
 $new$IF NOT public.findez_actor_active(p_actor) THEN RAISE insufficient_privilege; END IF;$new$);
SELECT pg_temp.permission_patch('public.findez_workspace_directory(uuid,text,jsonb)',
 $old$(public.findez_inventory_role(i.inventory_id,p_actor) IS NOT NULL OR (i.directory_visibility='workspace' AND ws IS NOT NULL))$old$,
 $new$(public.findez_inventory_role(i.inventory_id,p_actor) IS NOT NULL OR public.findez_can_administer_inventory(i.inventory_id,p_actor))$new$);
SELECT pg_temp.permission_patch('public.findez_workspace_directory(uuid,text,jsonb)',
 $old$public.findez_inventory_role(i.inventory_id,p_actor) IN ('owner','admin')$old$,
 $new$public.findez_can_administer_inventory(i.inventory_id,p_actor)$new$);

SELECT pg_temp.permission_patch('public.findez_access_invitation(uuid,text,jsonb)',
 $old$IF target=p_actor THEN RAISE check_violation; END IF;$old$,
 $new$IF target=p_actor AND kind<>'inventory' THEN RAISE check_violation; END IF;$new$);
SELECT pg_temp.permission_patch('public.findez_access_invitation(uuid,text,jsonb)',
 $old$invited_by_name,role,code_hash)$old$,
 $new$invited_by_name,role,code_hash,inventory_assignment_before)$new$);
SELECT pg_temp.permission_patch('public.findez_access_invitation(uuid,text,jsonb)',
 $old$requested,p_data->>'code_hash') RETURNING * INTO r;$old$,
 $new$requested,p_data->>'code_hash',CASE WHEN kind='inventory' THEN coalesce(
    (SELECT jsonb_build_object('exists',true,'role',m.role,'revision',m.permission_revision) FROM public.app_inventory_members m
     WHERE m.inventory_id=inv AND m.user_id=target),'{"exists":false}'::jsonb) END) RETURNING * INTO r;$new$);
-- Already present inventory overrides are changed immediately; new content
-- grants still require recipient consent. A workspace admin may explicitly
-- grant themselves content access using that same review/accept flow.
SELECT pg_temp.permission_patch('public.findez_access_invitation(uuid,text,jsonb)',
 $old$ELSIF public.findez_inventory_role(r.resource_id,p_actor) IS NULL THEN$old$,
 $new$ELSE
    IF coalesce(r.inventory_assignment_before,'{"exists":false}'::jsonb) IS DISTINCT FROM coalesce(
     (SELECT jsonb_build_object('exists',true,'role',m.role,'revision',m.permission_revision) FROM public.app_inventory_members m
      WHERE m.inventory_id=r.resource_id AND m.user_id=p_actor),'{"exists":false}'::jsonb) THEN
     RAISE check_violation USING message='Inventory access changed. Ask for a new invitation.';
    END IF;$new$);

DO $$ DECLARE target text; BEGIN
 FOREACH target IN ARRAY ARRAY['findez_delete_empty_inventory','findez_delete_inventory_contents'] LOOP
  PERFORM pg_temp.permission_patch(format('public.%I(uuid,uuid,text)',target)::regprocedure,
   $old$SELECT * INTO inv FROM public.app_inventories WHERE inventory_id=p_inventory FOR UPDATE;$old$,
   $new$PERFORM public.findez_lock_inventory_authority(p_inventory,p_actor);
 SELECT * INTO inv FROM public.app_inventories WHERE inventory_id=p_inventory FOR UPDATE;$new$);
  PERFORM pg_temp.permission_patch(format('public.%I(uuid,uuid,text)',target)::regprocedure,
   $old$coalesce(public.findez_inventory_role(p_inventory,p_actor) IN ('owner','admin'),false)$old$,
   $new$coalesce(public.findez_can_administer_inventory(p_inventory,p_actor),false)$new$);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.findez_guard_space_deletion() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor();
BEGIN
 IF actor IS NOT NULL AND EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=OLD.inventory_id) THEN
  PERFORM public.findez_lock_inventory_authority(OLD.inventory_id,actor);
  IF NOT coalesce(public.findez_inventory_role(OLD.inventory_id,actor) IN ('owner','admin'),false) THEN
   RAISE insufficient_privilege USING message='Only inventory owners and admins can delete a Space.';
  END IF;
 END IF;
 RETURN OLD;
END $$;
REVOKE ALL ON FUNCTION public.findez_guard_space_deletion() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS permission_space_delete ON public.spaces;
CREATE TRIGGER permission_space_delete BEFORE DELETE ON public.spaces
 FOR EACH ROW EXECUTE FUNCTION public.findez_guard_space_deletion();
CREATE OR REPLACE FUNCTION public.findez_can_delete_space(p_inventory uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(public.findez_inventory_role(p_inventory,public.findez_request_actor()) IN ('owner','admin'),false)
$$;
REVOKE ALL ON FUNCTION public.findez_can_delete_space(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.findez_can_delete_space(uuid) TO authenticated,service_role;
DROP POLICY IF EXISTS permission_space_delete ON public.spaces;
CREATE POLICY permission_space_delete ON public.spaces AS RESTRICTIVE FOR DELETE TO authenticated
 USING (public.findez_can_delete_space(inventory_id));

-- Ownership is transferred in one transaction. No data is copied, reparented,
-- exposed or automatically granted in restricted inventories.
CREATE OR REPLACE FUNCTION public.findez_transfer_resource_owner(p_actor uuid,p_scope text,p_resource uuid,p_target uuid,p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE title text; previous_owner uuid; org uuid;
BEGIN
 IF NOT public.findez_actor_active(p_actor) OR NOT public.findez_actor_active(p_target) OR p_target=p_actor THEN RAISE insufficient_privilege; END IF;
 IF p_scope='organization' THEN
  SELECT name,owner_user_id INTO title,previous_owner FROM public.app_organizations WHERE organization_id=p_resource FOR UPDATE;
  IF previous_owner IS DISTINCT FROM p_actor OR NOT EXISTS(SELECT 1 FROM public.app_organization_members
   WHERE organization_id=p_resource AND user_id=p_actor AND role='owner') THEN RAISE insufficient_privilege; END IF;
  PERFORM 1 FROM public.app_organization_members WHERE organization_id=p_resource AND user_id=p_target FOR UPDATE;
  IF NOT FOUND THEN RAISE check_violation USING message='Choose a current organization member.'; END IF;
 ELSIF p_scope='workspace' THEN
  SELECT name,owner_user_id,organization_id INTO title,previous_owner,org FROM public.teams WHERE team_id=p_resource FOR UPDATE;
  IF previous_owner IS DISTINCT FROM p_actor OR public.findez_workspace_role(p_resource,p_actor) IS DISTINCT FROM 'owner' THEN RAISE insufficient_privilege; END IF;
  PERFORM 1 FROM public.team_memberships WHERE team_id=p_resource AND user_id=p_target FOR UPDATE;
  IF NOT FOUND OR public.findez_workspace_role(p_resource,p_target) IS NULL THEN RAISE check_violation USING message='Choose a current workspace member.'; END IF;
 ELSE RAISE invalid_parameter_value; END IF;
 IF title IS NULL OR p_name IS DISTINCT FROM title THEN RAISE invalid_parameter_value USING message='The resource name changed. Reopen the confirmation.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_target AND email_confirmed_at IS NOT NULL) THEN RAISE check_violation USING message='The new owner must confirm their email first.'; END IF;
 IF p_scope='organization' THEN
  UPDATE public.app_organization_members SET role='owner' WHERE organization_id=p_resource AND user_id=p_target;
  UPDATE public.app_organization_members SET role='admin' WHERE organization_id=p_resource AND user_id=p_actor;
  UPDATE public.app_organizations SET owner_user_id=p_target WHERE organization_id=p_resource;
 ELSE
  UPDATE public.team_memberships SET role='owner' WHERE team_id=p_resource AND user_id=p_target;
  UPDATE public.team_memberships SET role='mentor' WHERE team_id=p_resource AND user_id=p_actor;
  UPDATE public.teams SET owner_user_id=p_target WHERE team_id=p_resource;
 END IF;
 INSERT INTO public.app_access_audit(actor_id,organization_id,team_id,action,target_id,changes)
 VALUES(p_actor,CASE WHEN p_scope='organization' THEN p_resource ELSE org END,
  CASE WHEN p_scope='workspace' THEN p_resource END,'ownership_transfer',p_target,
  jsonb_build_object('scope',p_scope,'previous_owner',p_actor,'new_owner',p_target));
 RETURN jsonb_build_object('transferred',true,'scope',p_scope,'resource_id',p_resource,'owner_user_id',p_target);
END $$;
REVOKE ALL ON FUNCTION public.findez_transfer_resource_owner(uuid,text,uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_transfer_resource_owner(uuid,text,uuid,uuid,text) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_create_legacy_workspace(p_actor uuid,p_data jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE saved public.teams; attempt integer; failed_constraint text;
BEGIN
 IF NOT public.findez_actor_active(p_actor) THEN RAISE insufficient_privilege; END IF;
 IF length(btrim(p_data->>'name')) NOT BETWEEN 1 AND 100 THEN RAISE invalid_parameter_value; END IF;
 FOR attempt IN 1..5 LOOP
  BEGIN
   INSERT INTO public.teams(name,owner_user_id,program,custom_category,join_code)
    VALUES(btrim(p_data->>'name'),p_actor,p_data->>'program',p_data->>'custom_category',public.findez_workspace_join_code()) RETURNING * INTO saved;
   EXIT;
  EXCEPTION WHEN unique_violation THEN
   GET STACKED DIAGNOSTICS failed_constraint=CONSTRAINT_NAME;
   IF failed_constraint<>'teams_join_code_key' OR attempt=5 THEN RAISE; END IF;
  END;
 END LOOP;
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(saved.team_id,p_actor,'owner');
 RETURN to_jsonb(saved);
END $$;
REVOKE ALL ON FUNCTION public.findez_create_legacy_workspace(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_create_legacy_workspace(uuid,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_preserve_resource_owner() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE resource uuid; designated uuid;
BEGIN
 IF TG_TABLE_NAME IN ('app_organization_members','app_organizations') THEN
  resource:=coalesce(NEW.organization_id,OLD.organization_id);
  SELECT owner_user_id INTO designated FROM public.app_organizations WHERE organization_id=resource FOR UPDATE;
  IF FOUND AND NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=resource AND user_id=designated AND role='owner') THEN
   RAISE check_violation USING message='Transfer organization ownership before removing or demoting its owner.';
  END IF;
 ELSE
  resource:=coalesce(NEW.team_id,OLD.team_id);
  SELECT owner_user_id INTO designated FROM public.teams WHERE team_id=resource FOR UPDATE;
  IF FOUND AND NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=resource AND user_id=designated AND role='owner') THEN
   RAISE check_violation USING message='Transfer workspace ownership before removing or demoting its owner.';
  END IF;
 END IF;
 RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.findez_preserve_resource_owner() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS permission_organization_owner ON public.app_organization_members;
CREATE CONSTRAINT TRIGGER permission_organization_owner AFTER INSERT OR UPDATE OR DELETE ON public.app_organization_members
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.findez_preserve_resource_owner();
DROP TRIGGER IF EXISTS permission_workspace_owner ON public.team_memberships;
CREATE CONSTRAINT TRIGGER permission_workspace_owner AFTER INSERT OR UPDATE OR DELETE ON public.team_memberships
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.findez_preserve_resource_owner();

DROP TRIGGER IF EXISTS permission_organization_parent_owner ON public.app_organizations;
CREATE CONSTRAINT TRIGGER permission_organization_parent_owner AFTER INSERT OR UPDATE ON public.app_organizations
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.findez_preserve_resource_owner();
DROP TRIGGER IF EXISTS permission_workspace_parent_owner ON public.teams;
CREATE CONSTRAINT TRIGGER permission_workspace_parent_owner AFTER INSERT OR UPDATE ON public.teams
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.findez_preserve_resource_owner();

NOTIFY pgrst,'reload schema';
COMMIT;

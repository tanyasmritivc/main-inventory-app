-- Organization-wide administrator access and task assignment attribution.
-- This supersedes the restricted-content rule for organization Owners/Admins.
-- Ordinary workspace membership, Viewers and personal inventories stay scoped.
BEGIN;
CREATE OR REPLACE FUNCTION public.findez_organization_role(p_organization uuid,p_actor uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT role FROM public.app_organization_members
 WHERE organization_id=p_organization AND user_id=p_actor AND public.findez_actor_active(p_actor)
$$;
REVOKE ALL ON FUNCTION public.findez_organization_role(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_organization_role(uuid,uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.findez_workspace_organization_admin(p_workspace uuid,p_actor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(public.findez_organization_role(t.organization_id,p_actor) IN ('owner','admin'),false)
 FROM public.teams t WHERE t.team_id=p_workspace
$$;
REVOKE ALL ON FUNCTION public.findez_workspace_organization_admin(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_workspace_organization_admin(uuid,uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.findez_workspace_role(p_workspace uuid,p_actor uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT CASE om.role WHEN 'owner' THEN 'owner' WHEN 'admin' THEN 'mentor' ELSE m.role END
 FROM public.teams t LEFT JOIN public.team_memberships m ON m.team_id=t.team_id AND m.user_id=p_actor
 LEFT JOIN public.app_organization_members om ON om.organization_id=t.organization_id AND om.user_id=p_actor
 WHERE t.team_id=p_workspace AND public.findez_actor_active(p_actor)
 AND (t.organization_id IS NULL OR om.user_id IS NOT NULL)
$$;
CREATE OR REPLACE FUNCTION public.findez_inventory_role(p_inventory uuid,p_actor uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT CASE
  WHEN NOT public.findez_actor_active(p_actor) THEN NULL
  WHEN i.team_id IS NULL THEN CASE WHEN i.owner_user_id=p_actor THEN 'owner' END
  WHEN public.findez_workspace_organization_admin(i.team_id,p_actor) THEN
   CASE w.role WHEN 'owner' THEN 'owner' ELSE 'admin' END
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
CREATE OR REPLACE FUNCTION public.findez_directory_entry(p_inventory uuid,p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT jsonb_build_object('inventory_id',i.inventory_id,'workspace_id',coalesce(i.team_id::text,'personal'),
  'name',i.name,'description',i.directory_description,'can_open',r.role IS NOT NULL,
  'can_edit',coalesce(r.role IN ('owner','admin','editor'),false),
  'can_manage',a.allowed,'can_rename',(a.allowed OR coalesce(r.role IN ('owner','admin','editor'),false)),'directory_visibility',i.directory_visibility,'role',r.role)
  || CASE WHEN r.role IS NOT NULL THEN jsonb_build_object('item_count',
    (SELECT count(*) FROM public.items x WHERE x.inventory_id=i.inventory_id)) ELSE '{}'::jsonb END
 FROM public.app_inventories i
 CROSS JOIN LATERAL (SELECT public.findez_inventory_role(i.inventory_id,p_actor) AS role) r
 CROSS JOIN LATERAL (SELECT coalesce(public.findez_can_administer_inventory(i.inventory_id,p_actor),false) AS allowed) a
 WHERE i.inventory_id=p_inventory AND (r.role IS NOT NULL OR a.allowed)
$$;
CREATE OR REPLACE FUNCTION public.findez_guard_inventory_administration() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor();
BEGIN
 IF actor IS NULL THEN RETURN coalesce(NEW,OLD); END IF;
 IF TG_OP='DELETE' AND OLD.team_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.teams WHERE team_id=OLD.team_id) THEN RETURN OLD; END IF;
 PERFORM public.findez_lock_inventory_authority(OLD.inventory_id,actor);
 IF NOT coalesce(public.findez_can_administer_inventory(OLD.inventory_id,actor),false) THEN
  IF TG_OP<>'UPDATE' OR NOT coalesce(public.findez_inventory_role(OLD.inventory_id,actor)='editor',false)
   OR (to_jsonb(NEW)-'name') IS DISTINCT FROM (to_jsonb(OLD)-'name') THEN RAISE insufficient_privilege; END IF;
 END IF;
 IF TG_OP='UPDATE' AND (NEW.owner_user_id<>OLD.owner_user_id OR NEW.team_id IS DISTINCT FROM OLD.team_id) THEN RAISE insufficient_privilege; END IF;
 RETURN coalesce(NEW,OLD);
END $$;
CREATE OR REPLACE FUNCTION public.findez_can_invite_access(actor uuid,kind text,resource uuid,requested text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE caller text;
BEGIN
 IF NOT public.findez_actor_active(actor) THEN RETURN false; END IF;
 IF kind='organization' THEN
  SELECT role INTO caller FROM public.app_organization_members WHERE organization_id=resource AND user_id=actor;
  RETURN coalesce(caller IN ('owner','admin') AND requested IN ('member','admin'),false);
 ELSIF kind='workspace' THEN
  caller:=public.findez_workspace_role(resource,actor);
  RETURN coalesce(caller IN ('owner','mentor') AND requested IN ('admin','editor','viewer') AND (requested<>'admin' OR caller='owner' OR public.findez_workspace_organization_admin(resource,actor)),false);
 ELSIF kind='inventory' THEN
  RETURN coalesce(public.findez_can_administer_inventory(resource,actor)
   AND requested IN ('admin','editor','viewer','inherit'),false);
 END IF;
 RETURN false;
END $$;
CREATE OR REPLACE FUNCTION public.findez_guard_workspace_assignment() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor(); ws uuid:=coalesce(NEW.team_id,OLD.team_id); caller text; parent public.teams;
BEGIN
 IF actor IS NULL THEN RETURN coalesce(NEW,OLD); END IF;
 SELECT * INTO parent FROM public.teams WHERE team_id=ws FOR UPDATE;
 IF NOT FOUND AND TG_OP='DELETE' THEN RETURN OLD; END IF;
 IF NOT FOUND OR NOT public.findez_actor_active(actor) THEN RAISE insufficient_privilege; END IF;
 caller:=public.findez_workspace_role(ws,actor);
 IF public.findez_workspace_organization_admin(ws,actor) THEN caller:='owner'; END IF;
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
CREATE OR REPLACE FUNCTION public.findez_transfer_resource_owner(p_actor uuid,p_scope text,p_resource uuid,p_target uuid,p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE title text; previous_owner uuid; org uuid;
BEGIN
 IF NOT public.findez_actor_active(p_actor) OR NOT public.findez_actor_active(p_target) OR p_target=p_actor THEN RAISE insufficient_privilege; END IF;
 IF p_scope='organization' THEN
  SELECT name,owner_user_id INTO title,previous_owner FROM public.app_organizations WHERE organization_id=p_resource FOR UPDATE;
  IF NOT EXISTS(SELECT 1 FROM public.app_organization_members
   WHERE organization_id=p_resource AND user_id=p_actor AND role IN ('owner','admin')) THEN RAISE insufficient_privilege; END IF;
  PERFORM 1 FROM public.app_organization_members WHERE organization_id=p_resource AND user_id=p_target FOR UPDATE;
  IF NOT FOUND THEN RAISE check_violation USING message='Choose a current organization member.'; END IF;
 ELSIF p_scope='workspace' THEN
  SELECT name,owner_user_id,organization_id INTO title,previous_owner,org FROM public.teams WHERE team_id=p_resource FOR UPDATE;
  IF (previous_owner IS DISTINCT FROM p_actor OR public.findez_workspace_role(p_resource,p_actor) IS DISTINCT FROM 'owner') AND NOT coalesce(public.findez_workspace_organization_admin(p_resource,p_actor),false) THEN RAISE insufficient_privilege; END IF;
  PERFORM 1 FROM public.team_memberships WHERE team_id=p_resource AND user_id=p_target FOR UPDATE;
  IF NOT FOUND OR public.findez_workspace_role(p_resource,p_target) IS NULL THEN RAISE check_violation USING message='Choose a current workspace member.'; END IF;
 ELSE RAISE invalid_parameter_value; END IF;
 IF p_target=previous_owner THEN RAISE check_violation USING message='This person is already the owner.'; END IF;
 IF title IS NULL OR p_name IS DISTINCT FROM title THEN RAISE invalid_parameter_value USING message='The resource name changed. Reopen the confirmation.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_target AND email_confirmed_at IS NOT NULL) THEN RAISE check_violation USING message='The new owner must confirm their email first.'; END IF;
 IF p_scope='organization' THEN
  UPDATE public.app_organization_members SET role='owner' WHERE organization_id=p_resource AND user_id=p_target;
  UPDATE public.app_organization_members SET role='admin' WHERE organization_id=p_resource AND user_id=previous_owner;
  UPDATE public.app_organizations SET owner_user_id=p_target WHERE organization_id=p_resource;
 ELSE
  UPDATE public.team_memberships SET role='owner' WHERE team_id=p_resource AND user_id=p_target;
  UPDATE public.team_memberships SET role='mentor' WHERE team_id=p_resource AND user_id=previous_owner;
  UPDATE public.teams SET owner_user_id=p_target WHERE team_id=p_resource;
 END IF;
 INSERT INTO public.app_access_audit(actor_id,organization_id,team_id,action,target_id,changes)
 VALUES(p_actor,CASE WHEN p_scope='organization' THEN p_resource ELSE org END,
  CASE WHEN p_scope='workspace' THEN p_resource END,'ownership_transfer',p_target,
  jsonb_build_object('scope',p_scope,'previous_owner',previous_owner,'new_owner',p_target));
 RETURN jsonb_build_object('transferred',true,'scope',p_scope,'resource_id',p_resource,'owner_user_id',p_target);
END $$;
CREATE OR REPLACE FUNCTION pg_temp.access_patch(target regprocedure,old_sql text,new_sql text) RETURNS void
LANGUAGE plpgsql AS $$ DECLARE definition text:=pg_get_functiondef(target); BEGIN
 IF position(new_sql IN definition)>0 THEN RETURN; END IF;
 IF position(old_sql IN definition)=0 THEN RAISE EXCEPTION 'Permission source differs for %',target; END IF;
 EXECUTE replace(definition,old_sql,new_sql);
END $$;
SELECT pg_temp.access_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)', $old$IF old_value->>'role'='owner' OR (role_name='admin' AND caller<>'owner') OR (old_value->>'role'='admin' AND caller<>'owner' AND role_name<>'none') THEN RAISE insufficient_privilege; END IF;$old$, $new$IF old_value->>'role'='owner' THEN RAISE insufficient_privilege; END IF;$new$);
SELECT pg_temp.access_patch('public.findez_manage_collaboration_legacy(uuid,text,jsonb)', $old$caller:=public.findez_workspace_role(ws,p_actor);$old$, $new$caller:=public.findez_workspace_role(ws,p_actor);
  IF public.findez_workspace_organization_admin(ws,p_actor) THEN caller:='owner'; END IF;$new$);
SELECT pg_temp.access_patch('public.findez_delete_inventory_team(uuid,uuid)', $old$IF owner_id<>p_actor_id THEN RAISE insufficient_privilege USING message='Team owner required'; END IF;$old$, $new$IF NOT public.findez_actor_active(p_actor_id) OR (owner_id<>p_actor_id AND NOT coalesce(public.findez_workspace_organization_admin(p_team_id,p_actor_id),false)) THEN RAISE insufficient_privilege USING message='Workspace owner or organization administrator required'; END IF;$new$);
-- Capture the actual assigning actor. Legacy assignments remain unknown rather
-- than inventing an attribution to the task creator.
ALTER TABLE public.team_board_tasks ADD COLUMN IF NOT EXISTS assigned_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
CREATE OR REPLACE FUNCTION public.findez_task_assignment_actor() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor();
BEGIN
 IF TG_OP='INSERT' THEN
  NEW.assigned_by:=CASE WHEN NEW.assigned_to IS NOT NULL THEN coalesce(actor,NEW.created_by) END;
 ELSIF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
  NEW.assigned_by:=CASE WHEN NEW.assigned_to IS NOT NULL THEN actor END;
 ELSE NEW.assigned_by:=OLD.assigned_by;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_task_assignment_actor() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS task_assignment_actor ON public.team_board_tasks;
CREATE TRIGGER task_assignment_actor BEFORE INSERT OR UPDATE ON public.team_board_tasks
 FOR EACH ROW EXECUTE FUNCTION public.findez_task_assignment_actor();
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS join_code_created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
CREATE OR REPLACE FUNCTION public.findez_invite_link_actor() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN NEW.join_code_created_by:=coalesce(public.findez_request_actor(),NEW.owner_user_id);
 ELSIF NEW.join_code IS DISTINCT FROM OLD.join_code THEN
  NEW.join_code_created_by:=coalesce(public.findez_request_actor(),NEW.join_code_created_by);
 ELSE NEW.join_code_created_by:=OLD.join_code_created_by;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_invite_link_actor() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS invite_link_actor ON public.teams;
CREATE TRIGGER invite_link_actor BEFORE INSERT OR UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.findez_invite_link_actor();
-- Rename authorization is checked in the same transaction as the write.
CREATE OR REPLACE FUNCTION public.findez_guard_resource_name() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor();
BEGIN
 IF actor IS NULL OR NEW.name IS NOT DISTINCT FROM OLD.name THEN RETURN NEW; END IF;
 IF TG_TABLE_NAME='teams' THEN
  PERFORM 1 FROM public.app_organization_members WHERE organization_id=OLD.organization_id AND user_id=actor FOR SHARE;
  PERFORM 1 FROM public.team_memberships WHERE team_id=OLD.team_id AND user_id=actor FOR SHARE;
  IF NOT coalesce(public.findez_workspace_role(OLD.team_id,actor) IN ('owner','mentor','member'),false) THEN RAISE insufficient_privilege; END IF;
 ELSE
  PERFORM 1 FROM public.app_organization_members WHERE organization_id=OLD.organization_id AND user_id=actor FOR SHARE;
  IF NOT coalesce(public.findez_organization_role(OLD.organization_id,actor) IN ('owner','admin'),false) THEN RAISE insufficient_privilege; END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_guard_resource_name() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS resource_name_authority ON public.teams;
CREATE TRIGGER resource_name_authority BEFORE UPDATE OF name ON public.teams FOR EACH ROW EXECUTE FUNCTION public.findez_guard_resource_name();
DROP TRIGGER IF EXISTS resource_name_authority ON public.app_organizations;
CREATE TRIGGER resource_name_authority BEFORE UPDATE OF name ON public.app_organizations FOR EACH ROW EXECUTE FUNCTION public.findez_guard_resource_name();
COMMIT;

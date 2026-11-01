-- Additive collaboration hierarchy. Existing workspaces and grants are retained.
BEGIN;
CREATE TABLE public.app_organizations (
  organization_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 100),
  owner_user_id uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.app_organization_members (
  organization_id uuid NOT NULL REFERENCES public.app_organizations ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK(role IN ('owner','admin','member')),
  PRIMARY KEY(organization_id,user_id)
);
ALTER TABLE public.teams ADD COLUMN organization_id uuid REFERENCES public.app_organizations;
ALTER TABLE public.app_inventories ADD COLUMN access_mode text NOT NULL DEFAULT 'legacy'
  CHECK(access_mode IN ('legacy','workspace','restricted'));
ALTER TABLE public.app_inventories ADD COLUMN default_role text NOT NULL DEFAULT 'viewer'
  CHECK(default_role IN ('editor','viewer'));
CREATE TABLE public.app_inventory_members (
  inventory_id uuid NOT NULL REFERENCES public.app_inventories ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK(role IN ('admin','editor','viewer','none')),
  PRIMARY KEY(inventory_id,user_id)
);
CREATE TABLE public.app_physical_locations (
  location_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES public.teams ON DELETE CASCADE,
  parent_id uuid REFERENCES public.app_physical_locations,
  name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 100),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX physical_location_siblings ON public.app_physical_locations
  (team_id,coalesce(parent_id,'00000000-0000-0000-0000-000000000000'::uuid),lower(name));
ALTER TABLE public.spaces ADD COLUMN physical_location_id uuid REFERENCES public.app_physical_locations;
CREATE UNIQUE INDEX inventory_physical_location ON public.spaces(inventory_id,physical_location_id)
  WHERE physical_location_id IS NOT NULL;
CREATE TABLE public.app_access_audit (
  audit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid, organization_id uuid, team_id uuid, inventory_id uuid,
  action text NOT NULL, target_id uuid, changes jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX access_audit_inventory ON public.app_access_audit(inventory_id,created_at DESC);
CREATE INDEX access_audit_workspace ON public.app_access_audit(team_id,created_at DESC);
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['app_organizations','app_organization_members','app_inventory_members','app_physical_locations','app_access_audit'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon,authenticated',t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
  END LOOP;
END $$;

CREATE FUNCTION public.findez_inventory_role(p_inventory uuid,p_actor uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT CASE
   WHEN i.team_id IS NULL THEN CASE WHEN i.owner_user_id=p_actor THEN 'owner' END
   WHEN m.role='owner' THEN 'owner'
   WHEN m.role='mentor' THEN 'admin'
   WHEN m.user_id IS NULL THEN NULL
   WHEN grant_row.role='none' THEN NULL
   WHEN grant_row.role IS NOT NULL THEN grant_row.role
   WHEN i.access_mode='restricted' THEN NULL
   WHEN i.access_mode='legacy' THEN CASE m.role WHEN 'member' THEN 'editor' ELSE 'viewer' END
   ELSE i.default_role END
 FROM public.app_inventories i
 LEFT JOIN public.team_memberships m ON m.team_id=i.team_id AND m.user_id=p_actor
 LEFT JOIN public.app_inventory_members grant_row ON grant_row.inventory_id=i.inventory_id AND grant_row.user_id=p_actor
 WHERE i.inventory_id=p_inventory
$$;
REVOKE ALL ON FUNCTION public.findez_inventory_role(uuid,uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_inventory_role(uuid,uuid) TO service_role;

-- Application queries keep their original authorization and add these exclusions.
-- Return one JSON value so PostgREST's row cap cannot truncate access rules.
CREATE FUNCTION public.findez_inventory_fences(p_actor uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(jsonb_agg(jsonb_build_object('inventory_id',i.inventory_id,
   'team_id',i.team_id,'role',public.findez_inventory_role(i.inventory_id,p_actor))),'[]'::jsonb)
 FROM public.app_inventories i WHERE i.access_mode<>'legacy'
   OR EXISTS(SELECT 1 FROM public.app_inventory_members m WHERE m.inventory_id=i.inventory_id)
$$;
REVOKE ALL ON FUNCTION public.findez_inventory_fences(uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_inventory_fences(uuid) TO service_role;

-- Only trusted service-role requests may supply a verified application actor.
CREATE FUNCTION public.findez_request_actor() RETURNS uuid LANGUAGE sql STABLE
SET search_path=public AS $$
 SELECT CASE WHEN nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role'='service_role'
 THEN nullif(nullif(current_setting('request.headers',true),'')::jsonb->>'x-findez-actor','')::uuid
 ELSE auth.uid() END
$$;
CREATE FUNCTION public.findez_inventory_policy(p_inventory uuid,p_write boolean)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.app_inventories; role_name text; claims jsonb;
BEGIN
 SELECT * INTO inv FROM public.app_inventories WHERE inventory_id=p_inventory;
 IF NOT FOUND THEN RETURN false; END IF;
 -- Legacy access is still governed by all existing ownership/sharing policies.
 IF inv.access_mode='legacy' AND NOT EXISTS(SELECT 1 FROM public.app_inventory_members WHERE inventory_id=p_inventory) THEN RETURN true; END IF;
 claims:=nullif(current_setting('request.jwt.claims',true),'')::jsonb;
 -- Integration keys already require workspace ownership, scopes and non-revocation.
 IF claims ? 'api_key_id' THEN RETURN public.findez_api_can_access_workspace(inv.team_id); END IF;
 role_name:=public.findez_inventory_role(p_inventory,public.findez_request_actor());
 RETURN coalesce(role_name IS NOT NULL AND (NOT p_write OR role_name IN ('owner','admin','editor')),false);
END $$;
REVOKE ALL ON FUNCTION public.findez_inventory_policy(uuid,boolean) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.findez_inventory_policy(uuid,boolean) TO authenticated,service_role;

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['items','spaces','bins','documents','activity_log','capture_reviews','conversations','messages','checkouts','item_events','project_kits','project_kit_items','project_kit_reservations','conversation_history','query_logs'] LOOP
  IF to_regclass('public.'||t) IS NOT NULL THEN
   EXECUTE format('CREATE POLICY inventory_scope_read ON public.%I AS RESTRICTIVE FOR SELECT TO authenticated USING (public.findez_inventory_policy(inventory_id,false))',t);
   EXECUTE format('CREATE POLICY inventory_scope_insert ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.findez_inventory_policy(inventory_id,true))',t);
   EXECUTE format('CREATE POLICY inventory_scope_update ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.findez_inventory_policy(inventory_id,true)) WITH CHECK (public.findez_inventory_policy(inventory_id,true))',t);
   EXECUTE format('CREATE POLICY inventory_scope_delete ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated USING (public.findez_inventory_policy(inventory_id,true))',t);
  END IF;
 END LOOP;
END $$;

CREATE FUNCTION public.findez_guard_inventory_write() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor(); inv uuid;
BEGIN
 inv:=CASE WHEN TG_OP='DELETE' THEN OLD.inventory_id ELSE NEW.inventory_id END;
 IF actor IS NOT NULL AND NOT public.findez_inventory_policy(inv,TG_TABLE_NAME NOT IN ('conversations','messages','conversation_history','query_logs','inventory_user_memory','inventory_conversation_sessions','activity_log')) THEN
  RAISE insufficient_privilege USING message='Inventory access denied.';
 END IF;
 IF TG_OP='UPDATE' AND OLD.inventory_id IS DISTINCT FROM NEW.inventory_id AND actor IS NOT NULL AND NOT public.findez_inventory_policy(OLD.inventory_id,true) THEN
  RAISE insufficient_privilege USING message='Source inventory access denied.';
 END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['items','spaces','bins','documents','capture_reviews','conversations','messages','checkouts','item_events','project_kits','project_kit_items','project_kit_reservations','conversation_history','query_logs','inventory_user_memory','inventory_conversation_sessions','activity_log'] LOOP
  IF to_regclass('public.'||t) IS NOT NULL THEN
   EXECUTE format('CREATE TRIGGER zz_inventory_access BEFORE INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.findez_guard_inventory_write()',t);
  END IF;
 END LOOP;
END $$;

CREATE FUNCTION public.findez_audit_item_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE before_value jsonb; after_value jsonb; actor uuid:=public.findez_request_actor();
BEGIN
 IF actor IS NULL THEN RETURN coalesce(NEW,OLD); END IF;
 IF TG_OP<>'INSERT' THEN before_value:=jsonb_build_object('quantity',OLD.quantity,'location',OLD.location,'space_id',OLD.space_id,'bin_id',to_jsonb(OLD)->'bin_id'); END IF;
 IF TG_OP<>'DELETE' THEN after_value:=jsonb_build_object('quantity',NEW.quantity,'location',NEW.location,'space_id',NEW.space_id,'bin_id',to_jsonb(NEW)->'bin_id'); END IF;
 IF before_value IS DISTINCT FROM after_value THEN
  INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
   SELECT actor,i.team_id,i.inventory_id,'item_'||lower(TG_OP),coalesce(NEW.item_id,OLD.item_id),jsonb_build_object('before',before_value,'after',after_value,'location_evidence','recorded')
   FROM public.app_inventories i WHERE i.inventory_id=coalesce(NEW.inventory_id,OLD.inventory_id);
 END IF;
 RETURN coalesce(NEW,OLD);
END $$;
CREATE TRIGGER items_access_audit AFTER INSERT OR UPDATE OR DELETE ON public.items
 FOR EACH ROW EXECUTE FUNCTION public.findez_audit_item_change();

CREATE FUNCTION public.findez_physical_location_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 IF TG_TABLE_NAME='app_physical_locations' THEN
  IF TG_OP='UPDATE' AND (NEW.parent_id IS DISTINCT FROM OLD.parent_id OR NEW.team_id<>OLD.team_id) THEN
   RAISE check_violation USING message='Location reparenting requires an explicit move workflow.';
  END IF;
  IF NEW.parent_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.app_physical_locations WHERE location_id=NEW.parent_id AND team_id=NEW.team_id) THEN
   RAISE check_violation USING message='Choose a parent in this workspace.';
  END IF;
 ELSE
  IF NEW.physical_location_id IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.app_physical_locations l JOIN public.app_inventories i ON i.team_id=l.team_id
   WHERE l.location_id=NEW.physical_location_id AND i.inventory_id=NEW.inventory_id) THEN
   RAISE check_violation USING message='Location belongs to another workspace.';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER physical_location_parent BEFORE INSERT OR UPDATE ON public.app_physical_locations FOR EACH ROW EXECUTE FUNCTION public.findez_physical_location_guard();
CREATE TRIGGER zz_space_physical_location BEFORE INSERT OR UPDATE ON public.spaces FOR EACH ROW EXECUTE FUNCTION public.findez_physical_location_guard();

-- All membership and policy writes below are one transaction with an audit row.
CREATE FUNCTION public.findez_manage_collaboration(p_actor uuid,p_action text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE org uuid:=(p_data->>'organization_id')::uuid; ws uuid:=(p_data->>'team_id')::uuid;
 inv uuid:=(p_data->>'inventory_id')::uuid; target uuid:=(p_data->>'user_id')::uuid;
 role_name text:=p_data->>'role'; caller text; saved jsonb; old_value jsonb;
 resource uuid; location_name text; location_parent uuid; physical uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN RAISE insufficient_privilege; END IF;
 IF p_action='organization_create' THEN
  INSERT INTO public.app_organizations(name,owner_user_id) VALUES(btrim(p_data->>'name'),p_actor) RETURNING organization_id,to_jsonb(app_organizations.*) INTO org,saved;
  INSERT INTO public.app_organization_members VALUES(org,p_actor,'owner');
 ELSIF p_action='organization_member' THEN
  PERFORM 1 FROM public.app_organizations WHERE organization_id=org FOR UPDATE;
  SELECT role INTO caller FROM public.app_organization_members WHERE organization_id=org AND user_id=p_actor;
  IF caller IS NULL OR caller NOT IN ('owner','admin') THEN RAISE insufficient_privilege; END IF;
  IF target IS NULL THEN SELECT id INTO target FROM auth.users WHERE lower(email)=lower(btrim(p_data->>'email')); END IF;
  IF target IS NULL THEN RAISE no_data_found USING message='Ask this person to create a FindEZ account first.'; END IF;
  SELECT to_jsonb(m.*) INTO old_value FROM public.app_organization_members m WHERE organization_id=org AND user_id=target;
  IF old_value->>'role'='owner' OR (role_name='admin' AND caller<>'owner') OR (old_value->>'role'='admin' AND caller<>'owner') THEN RAISE insufficient_privilege; END IF;
  IF role_name='none' THEN
   IF EXISTS(SELECT 1 FROM public.teams t JOIN public.team_memberships m USING(team_id) WHERE t.organization_id=org AND m.user_id=target) THEN
    RAISE check_violation USING message='Remove this person from organization workspaces first.';
   END IF;
   DELETE FROM public.app_organization_members WHERE organization_id=org AND user_id=target;
  ELSE
   IF role_name NOT IN ('admin','member') THEN RAISE check_violation; END IF;
   INSERT INTO public.app_organization_members VALUES(org,target,role_name) ON CONFLICT(organization_id,user_id) DO UPDATE SET role=excluded.role;
  END IF;
 ELSIF p_action='workspace_create' THEN
  PERFORM 1 FROM public.app_organizations WHERE organization_id=org FOR UPDATE;
  SELECT role INTO caller FROM public.app_organization_members WHERE organization_id=org AND user_id=p_actor;
  IF caller IS NULL OR caller NOT IN ('owner','admin') THEN RAISE insufficient_privilege; END IF;
  INSERT INTO public.teams(name,owner_user_id,program,custom_category,join_code,organization_id)
   VALUES(btrim(p_data->>'name'),p_actor,'custom','Project',upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),org)
   RETURNING team_id,to_jsonb(teams.*)-'join_code' INTO ws,saved;
  INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,p_actor,'owner');
  UPDATE public.app_inventories SET access_mode='workspace',default_role='viewer' WHERE team_id=ws;
 ELSIF p_action='workspace_attach' THEN
  PERFORM 1 FROM public.app_organizations WHERE organization_id=org FOR UPDATE;
  SELECT role INTO caller FROM public.app_organization_members WHERE organization_id=org AND user_id=p_actor;
  IF caller IS NULL OR caller NOT IN ('owner','admin') THEN RAISE insufficient_privilege; END IF;
  PERFORM 1 FROM public.teams WHERE team_id=ws AND owner_user_id=p_actor AND organization_id IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE insufficient_privilege; END IF;
  IF EXISTS(SELECT 1 FROM public.team_memberships m WHERE m.team_id=ws AND NOT EXISTS(
    SELECT 1 FROM public.app_organization_members om WHERE om.organization_id=org AND om.user_id=m.user_id)) THEN
   RAISE check_violation USING message='Add existing workspace members to the organization first.';
  END IF;
  UPDATE public.teams SET organization_id=org WHERE team_id=ws RETURNING to_jsonb(teams.*)-'join_code' INTO saved;
 ELSIF p_action='workspace_member' THEN
  PERFORM 1 FROM public.teams WHERE team_id=ws FOR UPDATE;
  SELECT organization_id INTO org FROM public.teams WHERE team_id=ws;
  SELECT role INTO caller FROM public.team_memberships WHERE team_id=ws AND user_id=p_actor;
  IF caller IS NULL OR caller NOT IN ('owner','mentor') THEN RAISE insufficient_privilege; END IF;
  IF org IS NULL THEN RAISE check_violation USING message='Use workspace invitations for independent workspaces.'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=target) THEN RAISE check_violation USING message='Assign an organization member.'; END IF;
  SELECT to_jsonb(m.*) INTO old_value FROM public.team_memberships m WHERE team_id=ws AND user_id=target;
  IF old_value->>'role'='owner' OR (role_name='admin' AND caller<>'owner') OR (old_value->>'role'='mentor' AND caller<>'owner') THEN RAISE insufficient_privilege; END IF;
  IF role_name='none' THEN
   DELETE FROM public.team_memberships WHERE team_id=ws AND user_id=target;
  ELSE
   IF role_name NOT IN ('admin','editor','viewer') THEN RAISE check_violation; END IF;
   INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,target,CASE role_name WHEN 'admin' THEN 'mentor' WHEN 'editor' THEN 'member' ELSE 'viewer' END)
    ON CONFLICT(team_id,user_id) DO UPDATE SET role=excluded.role;
  END IF;
 ELSIF p_action IN ('inventory_policy','inventory_member') THEN
  PERFORM 1 FROM public.app_inventories WHERE inventory_id=inv FOR UPDATE;
  SELECT team_id INTO ws FROM public.app_inventories WHERE inventory_id=inv;
  caller:=public.findez_inventory_role(inv,p_actor);
  IF ws IS NULL OR caller IS NULL OR caller NOT IN ('owner','admin') THEN RAISE insufficient_privilege; END IF;
  IF p_action='inventory_policy' THEN
   SELECT to_jsonb(i.*) INTO old_value FROM public.app_inventories i WHERE inventory_id=inv;
   IF p_data->>'access_mode' NOT IN ('workspace','restricted') OR p_data->>'default_role' NOT IN ('editor','viewer') THEN RAISE check_violation; END IF;
   UPDATE public.app_inventories SET access_mode=p_data->>'access_mode',default_role=p_data->>'default_role' WHERE inventory_id=inv;
  ELSE
   IF NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=target) THEN RAISE check_violation USING message='Assign a workspace member.'; END IF;
   IF EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=target AND role IN ('owner','mentor')) THEN RAISE check_violation USING message='Workspace administrators retain inventory administration.'; END IF;
   SELECT to_jsonb(m.*) INTO old_value FROM public.app_inventory_members m WHERE inventory_id=inv AND user_id=target;
   IF role_name='inherit' THEN DELETE FROM public.app_inventory_members WHERE inventory_id=inv AND user_id=target;
   ELSE
    INSERT INTO public.app_inventory_members VALUES(inv,target,role_name) ON CONFLICT(inventory_id,user_id) DO UPDATE SET role=excluded.role;
   END IF;
  END IF;
 ELSIF p_action='location_create' THEN
  SELECT role INTO caller FROM public.team_memberships WHERE team_id=ws AND user_id=p_actor;
  IF caller IS NULL OR caller NOT IN ('owner','mentor') THEN RAISE insufficient_privilege; END IF;
  INSERT INTO public.app_physical_locations(team_id,parent_id,name) VALUES(ws,(p_data->>'parent_id')::uuid,btrim(p_data->>'name')) RETURNING location_id,to_jsonb(app_physical_locations.*) INTO resource,saved;
 ELSIF p_action='location_attach' THEN
  caller:=public.findez_inventory_role(inv,p_actor);
  IF caller IS NULL OR caller NOT IN ('owner','admin') THEN RAISE insufficient_privilege; END IF;
  SELECT team_id INTO ws FROM public.app_inventories WHERE inventory_id=inv;
  physical:=(p_data->>'location_id')::uuid;
  SELECT name,parent_id INTO location_name,location_parent FROM public.app_physical_locations WHERE location_id=physical AND team_id=ws;
  IF NOT FOUND THEN RAISE no_data_found; END IF;
  WHILE location_parent IS NOT NULL LOOP
   SELECT name||' / '||location_name,parent_id INTO location_name,location_parent FROM public.app_physical_locations WHERE location_id=location_parent AND team_id=ws;
  END LOOP;
  IF length(location_name)>200 THEN RAISE check_violation USING message='Use shorter location names.'; END IF;
  INSERT INTO public.spaces(user_id,inventory_id,name,physical_location_id)
   SELECT owner_user_id,inv,location_name,physical FROM public.app_inventories WHERE inventory_id=inv
   RETURNING id,to_jsonb(spaces.*) INTO resource,saved;
 ELSE RAISE invalid_parameter_value; END IF;
 IF ws IS NOT NULL THEN SELECT organization_id INTO org FROM public.teams WHERE team_id=ws; END IF;
 INSERT INTO public.app_access_audit(actor_id,organization_id,team_id,inventory_id,action,target_id,changes)
 VALUES(p_actor,org,ws,inv,p_action,coalesce(target,resource),jsonb_build_object('before',old_value,'after',p_data-'email'));
 RETURN coalesce(saved,jsonb_build_object('saved',true));
END $$;
REVOKE ALL ON FUNCTION public.findez_manage_collaboration(uuid,text,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_manage_collaboration(uuid,text,jsonb) TO service_role;

-- Revoked workspace members cannot regain an old override by rejoining.
CREATE FUNCTION public.findez_revoke_inventory_grants() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 DELETE FROM public.app_inventory_members m USING public.app_inventories i
 WHERE m.inventory_id=i.inventory_id AND i.team_id=OLD.team_id AND m.user_id=OLD.user_id;
 RETURN OLD;
END $$;
CREATE TRIGGER workspace_member_revoke AFTER DELETE ON public.team_memberships FOR EACH ROW EXECUTE FUNCTION public.findez_revoke_inventory_grants();
-- Expose added inventory metadata through the existing, server-only summary view.
CREATE OR REPLACE VIEW public.app_inventory_summaries AS SELECT inv.inventory_id,inv.owner_user_id,inv.team_id,inv.created_by_user_id,inv.name,inv.is_default,inv.created_at,
 (SELECT count(*) FROM public.items i WHERE i.inventory_id=inv.inventory_id) AS item_count, inv.access_mode,inv.default_role FROM public.app_inventories inv;
-- Organization membership and workspace assignment are separate requirements.
CREATE FUNCTION public.findez_workspace_member_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE org uuid;
BEGIN
 SELECT organization_id INTO org FROM public.teams WHERE team_id=NEW.team_id;
 IF org IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=NEW.user_id) THEN
  RAISE check_violation USING message='Add this person to the organization before assigning the workspace.';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER workspace_organization_member BEFORE INSERT OR UPDATE ON public.team_memberships FOR EACH ROW EXECUTE FUNCTION public.findez_workspace_member_guard();
CREATE FUNCTION public.findez_audit_workspace_member() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor(); ws uuid:=coalesce(NEW.team_id,OLD.team_id);
BEGIN
 IF actor IS NOT NULL THEN
  INSERT INTO public.app_access_audit(actor_id,organization_id,team_id,action,target_id,changes)
   SELECT actor,organization_id,ws,'workspace_member_'||lower(TG_OP),coalesce(NEW.user_id,OLD.user_id),
    jsonb_build_object('before',CASE WHEN TG_OP<>'INSERT' THEN to_jsonb(OLD) END,'after',CASE WHEN TG_OP<>'DELETE' THEN to_jsonb(NEW) END)
   FROM public.teams WHERE team_id=ws;
 END IF;
 RETURN coalesce(NEW,OLD);
END $$;
CREATE TRIGGER workspace_membership_audit AFTER INSERT OR UPDATE OR DELETE ON public.team_memberships FOR EACH ROW EXECUTE FUNCTION public.findez_audit_workspace_member();
NOTIFY pgrst,'reload schema';
COMMIT;

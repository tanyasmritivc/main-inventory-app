-- Account deletion removes identity/private content, never shared contributions.
-- Installation changes functions/triggers only; no customer records are rewritten.
BEGIN;
CREATE OR REPLACE FUNCTION public.findez_prepare_account_deletion(p_actor uuid,p_files jsonb DEFAULT '[]')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE files jsonb;
BEGIN
 PERFORM 1 FROM auth.users WHERE id=p_actor FOR UPDATE;
 IF NOT FOUND THEN RAISE insufficient_privilege; END IF;
 IF EXISTS(SELECT 1 FROM public.app_organizations WHERE owner_user_id=p_actor) THEN
  RETURN jsonb_build_object('ready',false,'code','OWNERSHIP_REQUIRED','error','Transfer ownership of the organizations you own before deleting your account. Open Organizations to choose a new owner.');
 END IF;
 IF jsonb_typeof(p_files)<>'array' THEN RAISE invalid_parameter_value; END IF;
 SELECT coalesce(jsonb_agg(DISTINCT file),'[]') INTO files FROM (
  SELECT jsonb_build_object('kind','document','path',storage_path,'owner',p_actor) AS file FROM public.documents WHERE user_id=p_actor AND storage_path IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',p_actor) FROM public.items WHERE user_id=p_actor AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',p_actor) FROM public.item_events WHERE user_id=p_actor AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',image_url,'owner',p_actor) FROM public.capture_reviews WHERE user_id=p_actor AND image_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','url',source_frame_url,'owner',p_actor) FROM public.capture_reviews WHERE user_id=p_actor AND source_frame_url IS NOT NULL
  UNION ALL SELECT jsonb_build_object('kind','image','path',storage_path,'owner',split_part(storage_path,'/',1)) FROM public.app_image_previews WHERE actor_id=p_actor
  UNION ALL SELECT value FROM jsonb_array_elements(p_files)
 ) objects;
 INSERT INTO public.app_account_deletions(actor_id,files) VALUES(p_actor,files)
 ON CONFLICT(actor_id) DO UPDATE SET files=(SELECT coalesce(jsonb_agg(DISTINCT value),'[]') FROM jsonb_array_elements(app_account_deletions.files||EXCLUDED.files));
 RETURN jsonb_build_object('ready',true);
END $$;

-- Runs in the SAME transaction as Auth's DELETE. Any Auth/FK failure rolls back
-- every ownership/content change. Preparation alone never changes shared data.
CREATE OR REPLACE FUNCTION public.findez_preserve_shared_account_content() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE ws record; successor uuid; prior_headers text; prior_claims text; ready jsonb;
BEGIN
 ready:=public.findez_prepare_account_deletion(OLD.id);
 IF ready->>'ready' IS DISTINCT FROM 'true' THEN
  RAISE check_violation USING MESSAGE='Transfer organization ownership before deleting your account.';
 END IF;
 prior_headers:=current_setting('request.headers',true);
 prior_claims:=current_setting('request.jwt.claims',true);
 -- Trusted Auth deletion, not a client permission-management operation.
 PERFORM set_config('request.headers','{}',true);
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
 FOR ws IN SELECT * FROM public.teams WHERE owner_user_id=OLD.id ORDER BY team_id FOR UPDATE LOOP
  successor:=NULL;
  IF ws.organization_id IS NOT NULL THEN
   SELECT owner_user_id INTO STRICT successor FROM public.app_organizations WHERE organization_id=ws.organization_id FOR UPDATE;
  ELSE
   -- Retain independent shared workspaces for the remaining accepted members.
   -- Prefer another Owner, then Admin, then Editor, then Viewer, oldest first.
   SELECT m.user_id INTO successor FROM public.team_memberships m JOIN auth.users u ON u.id=m.user_id
    WHERE m.team_id=ws.team_id AND m.user_id<>OLD.id
    ORDER BY CASE m.role WHEN 'owner' THEN 0 WHEN 'mentor' THEN 1 WHEN 'member' THEN 2 ELSE 3 END,m.joined_at,m.user_id
    LIMIT 1 FOR UPDATE OF m;
  END IF;
  IF successor IS NOT NULL THEN
   PERFORM 1 FROM auth.users WHERE id=successor FOR KEY SHARE;
   IF NOT FOUND OR successor=OLD.id THEN RAISE serialization_failure; END IF;
   INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws.team_id,successor,'owner')
    ON CONFLICT(team_id,user_id) DO UPDATE SET role='owner';
   -- Existing workspace trigger transfers its inventories without changing IDs.
   UPDATE public.teams SET owner_user_id=successor WHERE team_id=ws.team_id;
   INSERT INTO public.app_access_audit(actor_id,organization_id,team_id,action,target_id,changes)
    VALUES(OLD.id,ws.organization_id,ws.team_id,'account_delete_workspace_transfer',successor,
     jsonb_build_object('previous_owner',OLD.id,'new_owner',successor));
  ELSE
   -- A private workspace has nobody else to preserve it for. Existing trigger
   -- detaches inventories; Auth then cascades those still owned by this account.
   DELETE FROM public.teams WHERE team_id=ws.team_id;
  END IF;
 END LOOP;
 -- Repair legacy inventory ownership within surviving workspaces as well.
 UPDATE public.app_inventories i SET owner_user_id=t.owner_user_id FROM public.teams t
  WHERE i.team_id=t.team_id AND i.owner_user_id=OLD.id AND t.owner_user_id<>OLD.id;
 -- These two creator columns have Auth CASCADE FKs; use the surviving inventory
 -- owner as custodian so the FK cannot erase the Space and its items/bins.
 UPDATE public.spaces s SET user_id=i.owner_user_id FROM public.app_inventories i
  WHERE s.inventory_id=i.inventory_id AND s.user_id=OLD.id AND i.owner_user_id<>OLD.id;
 UPDATE public.bins b SET user_id=i.owner_user_id FROM public.app_inventories i
  WHERE b.inventory_id=i.inventory_id AND b.user_id=OLD.id AND i.owner_user_id<>OLD.id;
 UPDATE public.team_shares s SET owner_user_id=i.owner_user_id FROM public.app_inventories i
  WHERE s.inventory_id=i.inventory_id AND s.owner_user_id=OLD.id AND i.owner_user_id<>OLD.id;
 -- Historical creator UUIDs on items, files, tasks/events remain attribution,
 -- not a login or permission grant. The profile and memberships are removed.
 DELETE FROM public.team_memberships WHERE user_id=OLD.id;
 DELETE FROM public.team_members WHERE member_user_id=OLD.id;
 UPDATE public.api_keys SET revoked_at=coalesce(revoked_at,now()) WHERE created_by=OLD.id OR org_id=OLD.id;
 PERFORM set_config('request.headers',coalesce(prior_headers,''),true);
 PERFORM set_config('request.jwt.claims',coalesce(prior_claims,''),true);
 RETURN OLD;
END $$;
REVOKE ALL ON FUNCTION public.findez_preserve_shared_account_content() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS findez_account_preserve_shared ON auth.users;
CREATE TRIGGER findez_account_preserve_shared BEFORE DELETE ON auth.users
 FOR EACH ROW EXECUTE FUNCTION public.findez_preserve_shared_account_content();

CREATE OR REPLACE FUNCTION public.findez_finish_account_deletion(p_actor uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE t text; col text; shared_filter text;
BEGIN
 PERFORM 1 FROM public.app_account_deletions WHERE actor_id=p_actor FOR UPDATE;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor) THEN RETURN false; END IF;
 -- Shared records keep their original uploader/creator UUID and storage paths.
 -- Private documents/reviews in a shared inventory still belong to the account.
 FOREACH t IN ARRAY ARRAY['items','spaces','bins','item_events','documents','capture_reviews','activity_log','team_shares'] LOOP
  IF to_regclass('public.'||t) IS NULL THEN CONTINUE; END IF;
  col:=CASE WHEN t='team_shares' THEN 'owner_user_id' ELSE 'user_id' END;
  shared_filter:=CASE WHEN t IN ('documents','capture_reviews') THEN ' AND coalesce(r.inventory_visibility=''inventory'',false)' ELSE '' END;
  EXECUTE format('DELETE FROM public.%I r WHERE r.%I=$1 AND NOT (EXISTS(SELECT 1 FROM public.app_inventories i WHERE i.inventory_id=r.inventory_id AND i.owner_user_id<>$1)%s)',t,col,shared_filter) USING p_actor;
 END LOOP;
 FOREACH t IN ARRAY ARRAY['team_notification_reads','push_devices','email_deliveries','team_notification_recipients',
   'team_members','team_memberships','usage_counters','query_logs','conversation_history',
   'inventory_conversation_sessions','conversation_sessions','conversations','inventory_user_memory',
   'user_memory','user_plan','usage_limits','profiles'] LOOP
  col:=CASE WHEN t='team_members' THEN 'member_user_id' WHEN t='profiles' THEN 'id' ELSE 'user_id' END;
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name=t AND column_name=col) THEN
   EXECUTE format('DELETE FROM public.%I WHERE %I=$1',t,col) USING p_actor;
  END IF;
 END LOOP;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.findez_prepare_account_deletion(uuid,jsonb),public.findez_finish_account_deletion(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_prepare_account_deletion(uuid,jsonb),public.findez_finish_account_deletion(uuid) TO service_role;

-- Attribution remains immutable while its user exists; Auth may null it after deletion.
CREATE OR REPLACE FUNCTION public.findez_task_assignment_actor() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE actor uuid:=public.findez_request_actor();
BEGIN
 IF TG_OP='INSERT' THEN
  NEW.assigned_by:=CASE WHEN NEW.assigned_to IS NOT NULL THEN coalesce(actor,NEW.created_by) END;
 ELSIF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
  NEW.assigned_by:=CASE WHEN NEW.assigned_to IS NOT NULL THEN actor END;
 ELSIF NEW.assigned_by IS NULL AND OLD.assigned_by IS NOT NULL AND NOT EXISTS(SELECT 1 FROM auth.users WHERE id=OLD.assigned_by) THEN
  NEW.assigned_by:=NULL; -- Honor Auth ON DELETE SET NULL; do not resurrect it.
 ELSE NEW.assigned_by:=OLD.assigned_by;
 END IF;
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION public.findez_invite_link_actor() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF TG_OP='INSERT' THEN NEW.join_code_created_by:=coalesce(public.findez_request_actor(),NEW.owner_user_id);
 ELSIF NEW.join_code IS DISTINCT FROM OLD.join_code THEN
  NEW.join_code_created_by:=coalesce(public.findez_request_actor(),NEW.join_code_created_by);
 ELSIF NEW.join_code_created_by IS NULL AND OLD.join_code_created_by IS NOT NULL AND NOT EXISTS(SELECT 1 FROM auth.users WHERE id=OLD.join_code_created_by) THEN
  NEW.join_code_created_by:=NULL; -- The issuer has deleted their account.
 ELSE NEW.join_code_created_by:=OLD.join_code_created_by;
 END IF;
 RETURN NEW;
END $$;

NOTIFY pgrst,'reload schema';
COMMIT;

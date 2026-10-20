-- Explicit self-service departure; shared content and historical attribution stay.
BEGIN;
CREATE OR REPLACE FUNCTION public.findez_leave_organization(p_actor uuid,p_organization uuid,p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE org public.app_organizations; membership text; ws record; prior_headers text;
BEGIN
 IF NOT public.findez_actor_active(p_actor) THEN RAISE insufficient_privilege; END IF;
 SELECT * INTO org FROM public.app_organizations WHERE organization_id=p_organization FOR UPDATE;
 IF NOT FOUND THEN RAISE no_data_found; END IF;
 SELECT role INTO membership FROM public.app_organization_members WHERE organization_id=p_organization AND user_id=p_actor FOR UPDATE;
 IF membership IS NULL THEN
  -- A lost response can be retried, but an outsider cannot manufacture departure.
  IF EXISTS(SELECT 1 FROM public.app_access_audit WHERE organization_id=p_organization AND actor_id=p_actor AND action='organization_leave') THEN
   RETURN jsonb_build_object('left',true,'organization_id',p_organization);
  END IF;
  RAISE insufficient_privilege;
 END IF;
 IF org.name IS DISTINCT FROM btrim(p_name) THEN RAISE serialization_failure; END IF;
 IF org.owner_user_id=p_actor OR (membership='owner' AND NOT EXISTS(
  SELECT 1 FROM public.app_organization_members WHERE organization_id=p_organization AND role='owner' AND user_id<>p_actor)) THEN
  RAISE check_violation USING MESSAGE='Transfer organization ownership before leaving.';
 END IF;
 -- Same parent-first lock order as inventory writes and ownership transfers.
 FOR ws IN SELECT team_id,owner_user_id FROM public.teams WHERE organization_id=p_organization ORDER BY team_id FOR UPDATE LOOP
  IF ws.owner_user_id=p_actor OR EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws.team_id AND user_id=p_actor AND role='owner') THEN
   RAISE foreign_key_violation USING MESSAGE='Transfer workspace ownership before leaving.';
  END IF;
 END LOOP;
 prior_headers:=current_setting('request.headers',true);
 PERFORM set_config('request.headers',(coalesce(nullif(prior_headers,'')::jsonb,'{}')||jsonb_build_object('x-findez-actor',p_actor))::text,true);
 DELETE FROM public.app_inventory_members m USING public.app_inventories i,public.teams t
  WHERE m.user_id=p_actor AND m.inventory_id=i.inventory_id AND i.team_id=t.team_id AND t.organization_id=p_organization;
 DELETE FROM public.team_members m USING public.team_shares s,public.app_inventories i,public.teams t
  WHERE m.member_user_id=p_actor AND m.share_id=s.share_id AND s.inventory_id=i.inventory_id AND i.team_id=t.team_id AND t.organization_id=p_organization;
 DELETE FROM public.team_memberships m USING public.teams t
  WHERE m.user_id=p_actor AND m.team_id=t.team_id AND t.organization_id=p_organization;
 UPDATE public.app_access_invitations SET status='cancelled',decided_at=now()
  WHERE organization_id=p_organization AND status='pending'
   AND (invited_by=p_actor OR lower(recipient_email)=(SELECT lower(email) FROM auth.users WHERE id=p_actor));
 DELETE FROM public.app_organization_members WHERE organization_id=p_organization AND user_id=p_actor;
 INSERT INTO public.app_access_audit(actor_id,organization_id,action,target_id,changes)
  VALUES(p_actor,p_organization,'organization_leave',p_actor,jsonb_build_object('previous_role',membership));
 PERFORM set_config('request.headers',coalesce(prior_headers,''),true);
 RETURN jsonb_build_object('left',true,'organization_id',p_organization);
END $$;
REVOKE ALL ON FUNCTION public.findez_leave_organization(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_leave_organization(uuid,uuid,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

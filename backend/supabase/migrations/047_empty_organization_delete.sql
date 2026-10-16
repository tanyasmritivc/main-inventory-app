-- Delete only empty organizations, with current owner consent and a durable audit.
BEGIN;
CREATE FUNCTION public.findez_delete_empty_organization(p_actor uuid, p_organization uuid, p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE org public.app_organizations; member_count integer; invitation_count integer;
BEGIN
 SELECT * INTO org FROM public.app_organizations WHERE organization_id=p_organization FOR UPDATE;
 IF NOT FOUND THEN RAISE no_data_found; END IF;
 IF p_actor IS NULL OR org.owner_user_id<>p_actor OR NOT EXISTS(
  SELECT 1 FROM public.app_organization_members WHERE organization_id=p_organization AND user_id=p_actor AND role='owner'
 ) THEN RAISE insufficient_privilege; END IF;
 IF p_name IS NULL OR p_name<>org.name THEN
  RAISE serialization_failure USING message='The organization name changed. Reopen the confirmation.';
 END IF;
 -- Check every workspace, including ones the owner is not assigned to.
 IF EXISTS(SELECT 1 FROM public.teams WHERE organization_id=p_organization) THEN
  RAISE foreign_key_violation USING message='Only organizations with no workspaces can be deleted.';
 END IF;
 SELECT count(*) INTO member_count FROM public.app_organization_members WHERE organization_id=p_organization;
 SELECT count(*) INTO invitation_count FROM public.app_access_invitations WHERE organization_id=p_organization;
 INSERT INTO public.app_access_audit(actor_id,organization_id,action,target_id,changes)
 VALUES(p_actor,p_organization,'organization_delete',p_organization,
  jsonb_build_object('before',to_jsonb(org),'members_removed',member_count,'invitations_removed',invitation_count));
 -- Existing foreign keys also prevent a concurrent workspace attachment from
 -- leaving a dangling resource. Membership/invitation removal is transactional.
 DELETE FROM public.app_organizations WHERE organization_id=p_organization;
 RETURN jsonb_build_object('deleted',true,'organization_id',p_organization);
END $$;
REVOKE ALL ON FUNCTION public.findez_delete_empty_organization(uuid,uuid,text) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_delete_empty_organization(uuid,uuid,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

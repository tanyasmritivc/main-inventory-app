-- Private delivery lookup. Invitations never grant access through a push alert.
BEGIN;
CREATE FUNCTION public.findez_invitation_push_target(p_invitation uuid) RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT u.id FROM public.app_access_invitations i JOIN auth.users u ON lower(u.email)=i.recipient_email
 WHERE i.invitation_id=p_invitation AND i.status='pending' AND i.expires_at>now()
  AND u.email_confirmed_at IS NOT NULL AND u.id<>i.invited_by
  AND public.findez_can_invite_access(i.invited_by,i.scope,i.resource_id,i.role)
 LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.findez_invitation_push_target(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_invitation_push_target(uuid) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

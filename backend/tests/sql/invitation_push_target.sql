-- Recipient lookup is private, verified and never itself grants membership.
BEGIN;
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_invitation_push_target(uuid)','EXECUTE'),'invitation recipient lookup is service-only');
DO $$
DECLARE actor uuid:='b0000000-0000-0000-0000-000000000001'; recipient uuid:='b0000000-0000-0000-0000-000000000038'; org uuid; invitation uuid;
BEGIN
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Push fixture"}')->>'organization_id')::uuid;
 invitation:=(public.findez_access_invitation(actor,'create',jsonb_build_object('scope','organization','resource_id',org,'role','member','email','fixture38@example.invalid','code_hash',md5('notification-push-fixture-20261016')||md5('unique-push-fixture')))->>'invitation_id')::uuid;
 PERFORM pg_temp.check(public.findez_invitation_push_target(invitation)=recipient,'verified invited account receives push without membership');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=recipient),'push lookup grants no membership');
 UPDATE auth.users SET email_confirmed_at=NULL WHERE id=recipient;
 PERFORM pg_temp.check(public.findez_invitation_push_target(invitation) IS NULL,'unverified email receives no push');
 UPDATE auth.users SET email_confirmed_at=now() WHERE id=recipient;
 UPDATE public.app_access_invitations SET status='cancelled' WHERE invitation_id=invitation;
 PERFORM pg_temp.check(public.findez_invitation_push_target(invitation) IS NULL,'canceled invitation receives no push');
 UPDATE public.app_access_invitations SET status='pending',expires_at=now()-interval '1 minute' WHERE invitation_id=invitation;
 PERFORM pg_temp.check(public.findez_invitation_push_target(invitation) IS NULL,'expired invitation receives no push');
 UPDATE public.app_access_invitations SET expires_at=now()+interval '1 day' WHERE invitation_id=invitation;
 DELETE FROM public.app_organization_members WHERE organization_id=org AND user_id=actor;
 PERFORM pg_temp.check(public.findez_invitation_push_target(invitation) IS NULL,'revoked sender cannot dispatch invitation');
END $$;
ROLLBACK;

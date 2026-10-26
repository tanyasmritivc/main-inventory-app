-- Disposable database only, after organization_access.sql.
CREATE TEMP TABLE invitation_members_before AS
 SELECT 'organization'::text kind,to_jsonb(m.*) value FROM public.app_organization_members m
 UNION ALL SELECT 'workspace',to_jsonb(m.*) FROM public.team_memberships m
 UNION ALL SELECT 'inventory',to_jsonb(m.*) FROM public.app_inventory_members m;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS email_confirmed_at timestamptz;
CREATE TABLE IF NOT EXISTS public.profiles(id uuid PRIMARY KEY,display_name text,first_name text,last_name text);
UPDATE auth.users SET email_confirmed_at=now() WHERE email LIKE 'fixture%@example.invalid';
\ir ../../supabase/migrations/045_member_invitation_consent.sql
SELECT pg_temp.check(NOT EXISTS(
 SELECT kind,value FROM invitation_members_before EXCEPT (
 SELECT 'organization',to_jsonb(m.*) FROM public.app_organization_members m
 UNION ALL SELECT 'workspace',to_jsonb(m.*) FROM public.team_memberships m
 UNION ALL SELECT 'inventory',to_jsonb(m.*) FROM public.app_inventory_members m)), 'consent migration preserves every existing membership');
SELECT pg_temp.check(NOT has_function_privilege('service_role','public.findez_manage_collaboration_legacy(uuid,text,jsonb)','EXECUTE'),'old immediate-grant RPC is private');
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_access_invitation(uuid,text,jsonb)','EXECUTE'),'clients cannot forge invitation actors through database RPC');
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT ('c0000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'recipient'||n||'@example.invalid',CASE WHEN n<>44 THEN now() END FROM generate_series(40,45) n;
CREATE FUNCTION pg_temp.invite(actor uuid,kind text,resource uuid,mail text,requested text,nonce text)
RETURNS jsonb LANGUAGE sql AS $$ SELECT public.findez_access_invitation(actor,'create',jsonb_build_object('scope',kind,'resource_id',resource,'email',mail,'role',requested,'code_hash',md5(nonce)||md5(nonce))); $$;
DO $$
DECLARE owner_id uuid:=(SELECT id FROM access_demo WHERE key='owner');
 org uuid:=(SELECT id FROM access_demo WHERE key='acme');
 recipient uuid:='c0000000-0000-0000-0000-000000000040';
 wrong uuid:='c0000000-0000-0000-0000-000000000041';
 admin_id uuid:='c0000000-0000-0000-0000-000000000042';
 ws uuid; inv uuid:=gen_random_uuid(); r jsonb; first_id uuid; second_id uuid; result jsonb;
BEGIN
 r:=pg_temp.invite(owner_id,'organization',org,' Recipient40@EXAMPLE.invalid ','member','org-first');
 first_id:=(r->>'invitation_id')::uuid;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=recipient),'sending invite grants no organization membership');
 result:=public.findez_access_invitation(recipient,'preview',jsonb_build_object('code_hash',md5('org-first')||md5('org-first')));
 PERFORM pg_temp.check(result->>'status'='pending' AND NOT result ? 'code_hash' AND NOT result ? 'recipient_email','preview reveals only recipient-authorized invitation');
 PERFORM pg_temp.check(jsonb_array_length(public.findez_access_invitation(recipient,'inbox','{}'))=1,'recipient receives pending notification');
 PERFORM public.findez_access_invitation(recipient,'read','{}');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=recipient),'reading notification does not accept');
 BEGIN PERFORM public.findez_access_invitation(wrong,'preview',jsonb_build_object('invitation_id',first_id)); RAISE EXCEPTION 'forwarded invite preview leaked'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_access_invitation(wrong,'accept',jsonb_build_object('invitation_id',first_id)); RAISE EXCEPTION 'wrong recipient accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_manage_collaboration(owner_id,'organization_member',jsonb_build_object('organization_id',org,'user_id',recipient,'role','member')); RAISE EXCEPTION 'old client bypassed consent'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',first_id));
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=recipient AND role='member'),'explicit acceptance grants only requested organization role');
 PERFORM public.findez_manage_collaboration(owner_id,'organization_member',jsonb_build_object('organization_id',org,'user_id',recipient,'role','none'));
 PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',first_id));
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=recipient),'accepted replay cannot restore revoked access');
 r:=pg_temp.invite(owner_id,'organization',org,'recipient40@example.invalid','member','org-second');
 PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',r->>'invitation_id'));
 r:=pg_temp.invite(owner_id,'organization',org,'recipient41@example.invalid','member','decline');
 PERFORM public.findez_access_invitation(wrong,'decline',jsonb_build_object('invitation_id',r->>'invitation_id'));
 BEGIN PERFORM public.findez_access_invitation(wrong,'accept',jsonb_build_object('invitation_id',r->>'invitation_id')); RAISE EXCEPTION 'declined invitation accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=wrong),'decline grants no access');
 r:=pg_temp.invite(owner_id,'organization',org,'recipient41@example.invalid','member','cancel');
 PERFORM public.findez_access_invitation(owner_id,'cancel',jsonb_build_object('invitation_id',r->>'invitation_id'));
 BEGIN PERFORM public.findez_access_invitation(wrong,'accept',jsonb_build_object('invitation_id',r->>'invitation_id')); RAISE EXCEPTION 'cancelled invitation accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 r:=pg_temp.invite(owner_id,'organization',org,'recipient41@example.invalid','member','expire');
 UPDATE public.app_access_invitations SET expires_at=now()-interval '1 minute' WHERE invitation_id=(r->>'invitation_id')::uuid;
 BEGIN PERFORM public.findez_access_invitation(wrong,'accept',jsonb_build_object('invitation_id',r->>'invitation_id')); RAISE EXCEPTION 'expired invitation accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 r:=pg_temp.invite(owner_id,'organization',org,'recipient44@example.invalid','member','unverified');
 BEGIN PERFORM public.findez_access_invitation('c0000000-0000-0000-0000-000000000044','accept',jsonb_build_object('invitation_id',r->>'invitation_id')); RAISE EXCEPTION 'unverified email accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 r:=pg_temp.invite(owner_id,'organization',org,'recipient42@example.invalid','member','admin-org');
 PERFORM public.findez_access_invitation(admin_id,'accept',jsonb_build_object('invitation_id',r->>'invitation_id'));
 ws:=(public.findez_manage_collaboration(owner_id,'workspace_create',jsonb_build_object('organization_id',org,'name','Consent project'))->>'team_id')::uuid;
 r:=public.findez_access_invitation(owner_id,'change',jsonb_build_object('scope','workspace','resource_id',ws,'user_id',admin_id,'role','admin','code_hash',repeat('a',64)));
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=admin_id),'workspace assignment is pending until accepted');
 PERFORM public.findez_access_invitation(admin_id,'accept',jsonb_build_object('invitation_id',r->>'invitation_id'));
 r:=pg_temp.invite(admin_id,'workspace',ws,'recipient40@example.invalid','viewer','revoked-sender');
 PERFORM public.findez_manage_collaboration(owner_id,'workspace_member',jsonb_build_object('team_id',ws,'user_id',admin_id,'role','editor'));
 BEGIN PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',r->>'invitation_id')); RAISE EXCEPTION 'revoked sender still granted membership'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM public.findez_access_invitation(owner_id,'cancel',jsonb_build_object('invitation_id',r->>'invitation_id'));
 r:=pg_temp.invite(owner_id,'workspace',ws,'recipient40@example.invalid','viewer','removed-parent');
 PERFORM public.findez_manage_collaboration(owner_id,'organization_member',jsonb_build_object('organization_id',org,'user_id',recipient,'role','none'));
 BEGIN PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',r->>'invitation_id')); RAISE EXCEPTION 'removed organization member joined'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM public.findez_access_invitation(owner_id,'cancel',jsonb_build_object('invitation_id',r->>'invitation_id'));
 r:=pg_temp.invite(owner_id,'organization',org,'recipient40@example.invalid','member','restore-parent');
 PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',r->>'invitation_id'));
 r:=pg_temp.invite(owner_id,'workspace',ws,'recipient40@example.invalid','viewer','workspace-ok');
 PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',r->>'invitation_id'));
 INSERT INTO public.app_inventories(inventory_id,owner_user_id,team_id,name,access_mode) VALUES(inv,owner_id,ws,'Private equipment','restricted');
 r:=public.findez_access_invitation(owner_id,'change',jsonb_build_object('scope','inventory','resource_id',inv,'user_id',recipient,'role','editor','code_hash',repeat('b',64)));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,recipient) IS NULL,'pending inventory invitation grants no records');
 PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',r->>'invitation_id'));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,recipient)='editor','accepted inventory invitation grants requested role');
 PERFORM public.findez_access_invitation(owner_id,'change',jsonb_build_object('scope','inventory','resource_id',inv,'user_id',recipient,'role','viewer'));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,recipient)='viewer','existing role changes remain authorized and immediate');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_access_audit WHERE actor_id=recipient AND action='invitation_accept' AND inventory_id=inv),'recipient decision has an audit trail');
 -- Invitations can precede signup, but email confirmation still precedes consent.
 r:=pg_temp.invite(owner_id,'organization',org,'future-member@example.invalid','member','future-signup');
 INSERT INTO auth.users(id,email,email_confirmed_at) VALUES('c0000000-0000-0000-0000-000000000046','future-member@example.invalid',now());
 PERFORM public.findez_access_invitation('c0000000-0000-0000-0000-000000000046','accept',jsonb_build_object('invitation_id',r->>'invitation_id'));
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id='c0000000-0000-0000-0000-000000000046'),'new verified account can accept a pre-signup invitation');
 r:=pg_temp.invite(owner_id,'organization',org,'recipient45@example.invalid','member','email-changed');
 UPDATE auth.users SET email='changed@example.invalid' WHERE id='c0000000-0000-0000-0000-000000000045';
 BEGIN PERFORM public.findez_access_invitation('c0000000-0000-0000-0000-000000000045','accept',jsonb_build_object('invitation_id',r->>'invitation_id')); RAISE EXCEPTION 'changed email accepted old invitation'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE auth.users SET email='recipient45@example.invalid' WHERE id='c0000000-0000-0000-0000-000000000045';
 PERFORM public.findez_access_invitation(owner_id,'cancel',jsonb_build_object('invitation_id',r->>'invitation_id'));
 PERFORM public.findez_manage_collaboration(owner_id,'workspace_member',jsonb_build_object('team_id',ws,'user_id',recipient,'role','none'));
 r:=pg_temp.invite(owner_id,'workspace',ws,'recipient40@example.invalid','viewer','parent-changed');
 UPDATE public.teams SET organization_id=NULL WHERE team_id=ws;
 BEGIN PERFORM public.findez_access_invitation(recipient,'accept',jsonb_build_object('invitation_id',r->>'invitation_id')); RAISE EXCEPTION 'changed parent accepted stale invitation'; EXCEPTION WHEN check_violation THEN NULL; END;
 UPDATE public.teams SET organization_id=org WHERE team_id=ws;
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=recipient),'changed parent invitation grants no workspace access');
END $$;

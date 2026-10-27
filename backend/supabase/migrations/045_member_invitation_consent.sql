-- Recipient consent is required before a new collaboration membership exists.
BEGIN;
CREATE TABLE public.app_access_invitations (
 invitation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 scope text NOT NULL CHECK(scope IN ('organization','workspace','inventory')),
 resource_id uuid NOT NULL,
 resource_name text NOT NULL,
 organization_id uuid REFERENCES public.app_organizations ON DELETE CASCADE,
 team_id uuid REFERENCES public.teams ON DELETE CASCADE,
 inventory_id uuid REFERENCES public.app_inventories ON DELETE CASCADE,
 recipient_email text NOT NULL CHECK(length(recipient_email) BETWEEN 3 AND 254),
 invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 invited_by_name text NOT NULL,
 role text NOT NULL CHECK(role IN ('member','admin','editor','viewer','inherit')),
 code_hash text NOT NULL UNIQUE CHECK(length(code_hash)=64),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','declined','cancelled','expired')),
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT now()+interval '7 days',
 decided_at timestamptz, accepted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 seen_at timestamptz,
 CHECK ((scope='organization' AND resource_id=organization_id AND team_id IS NULL AND inventory_id IS NULL)
     OR (scope='workspace' AND resource_id=team_id AND inventory_id IS NULL)
     OR (scope='inventory' AND resource_id=inventory_id AND team_id IS NOT NULL))
);
CREATE UNIQUE INDEX access_invitation_pending ON public.app_access_invitations(scope,resource_id,recipient_email) WHERE status='pending';
CREATE INDEX access_invitation_recipient ON public.app_access_invitations(recipient_email,created_at DESC);
ALTER TABLE public.app_access_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_access_invitations FROM public,anon,authenticated;
GRANT ALL ON public.app_access_invitations TO service_role;

-- Private helpers are callable only by the definer-owned RPCs, not PostgREST.
CREATE FUNCTION public.findez_can_invite_access(actor uuid,kind text,resource uuid,requested text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE caller text;
BEGIN
 IF kind='organization' THEN
  SELECT role INTO caller FROM public.app_organization_members WHERE organization_id=resource AND user_id=actor;
  RETURN coalesce(caller IN ('owner','admin') AND requested IN ('member','admin') AND (requested<>'admin' OR caller='owner'),false);
 ELSIF kind='workspace' THEN
  SELECT role INTO caller FROM public.team_memberships WHERE team_id=resource AND user_id=actor;
  RETURN coalesce(caller IN ('owner','mentor') AND requested IN ('admin','editor','viewer') AND (requested<>'admin' OR caller='owner'),false);
 ELSIF kind='inventory' THEN
  caller:=public.findez_inventory_role(resource,actor);
  RETURN coalesce(caller IN ('owner','admin') AND requested IN ('admin','editor','viewer','inherit'),false);
 END IF;
 RETURN false;
END $$;
REVOKE ALL ON FUNCTION public.findez_can_invite_access(uuid,text,uuid,text) FROM public,anon,authenticated,service_role;

ALTER FUNCTION public.findez_manage_collaboration(uuid,text,jsonb) RENAME TO findez_manage_collaboration_legacy;
REVOKE ALL ON FUNCTION public.findez_manage_collaboration_legacy(uuid,text,jsonb) FROM public,anon,authenticated,service_role;
CREATE FUNCTION public.findez_manage_collaboration(p_actor uuid,p_action text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE target uuid:=(p_data->>'user_id')::uuid; resource uuid; mode text;
BEGIN
 -- Existing-role edits and revocation remain immediate. New membership cannot
 -- bypass consent through the original admin endpoint or a stale client.
 IF p_action='organization_member' AND p_data->>'role'<>'none' THEN
  resource:=(p_data->>'organization_id')::uuid;
  PERFORM 1 FROM public.app_organizations WHERE organization_id=resource FOR UPDATE;
  IF target IS NULL THEN SELECT id INTO target FROM auth.users WHERE lower(email)=lower(btrim(p_data->>'email')); END IF;
  IF target IS NULL OR NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=resource AND user_id=target) THEN
   RAISE check_violation USING message='Invite this person and wait for acceptance.';
  END IF;
 ELSIF p_action='workspace_member' AND p_data->>'role'<>'none' THEN
  resource:=(p_data->>'team_id')::uuid;
  PERFORM 1 FROM public.teams WHERE team_id=resource FOR UPDATE;
  IF NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=resource AND user_id=target) THEN
   RAISE check_violation USING message='Invite this person and wait for acceptance.';
  END IF;
 ELSIF p_action='inventory_member' AND p_data->>'role'<>'none' THEN
  resource:=(p_data->>'inventory_id')::uuid;
  PERFORM 1 FROM public.app_inventories WHERE inventory_id=resource FOR UPDATE;
  SELECT access_mode INTO mode FROM public.app_inventories WHERE inventory_id=resource;
  IF public.findez_inventory_role(resource,target) IS NULL AND (p_data->>'role'<>'inherit' OR mode<>'restricted') THEN
   RAISE check_violation USING message='Invite this person and wait for acceptance.';
  END IF;
 END IF;
 RETURN public.findez_manage_collaboration_legacy(p_actor,p_action,p_data);
END $$;
REVOKE ALL ON FUNCTION public.findez_manage_collaboration(uuid,text,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_manage_collaboration(uuid,text,jsonb) TO service_role;

CREATE FUNCTION public.findez_access_invitation(p_actor uuid,p_action text,p_data jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r public.app_access_invitations; mail text; target uuid; resource uuid:=(p_data->>'resource_id')::uuid;
 kind text:=p_data->>'scope'; requested text:=p_data->>'role'; org uuid; ws uuid; inv uuid;
 title text; result jsonb; prior text; already boolean:=false;
BEGIN
 SELECT lower(email) INTO mail FROM auth.users WHERE id=p_actor AND email_confirmed_at IS NOT NULL;
 IF mail IS NULL THEN
  IF p_action='inbox' THEN RETURN '[]'::jsonb; END IF;
  IF p_action='read' THEN RETURN jsonb_build_object('saved',true); END IF;
  RAISE insufficient_privilege USING message='Confirm your email before using invitations.';
 END IF;
 IF p_action IN ('inbox','read') THEN
  IF p_action='read' THEN
   UPDATE public.app_access_invitations SET seen_at=now() WHERE recipient_email=mail AND status='pending' AND expires_at>now() AND seen_at IS NULL;
   RETURN jsonb_build_object('saved',true);
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(i)-'code_hash'-'recipient_email' ORDER BY i.created_at DESC),'[]') INTO result
   FROM public.app_access_invitations i WHERE recipient_email=mail AND status='pending' AND expires_at>now();
  RETURN result;
 ELSIF p_action='sent' THEN
  IF NOT public.findez_can_invite_access(p_actor,kind,resource,CASE kind WHEN 'organization' THEN 'member' ELSE 'viewer' END) THEN RAISE insufficient_privilege; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(i)-'code_hash' ORDER BY i.created_at DESC),'[]') INTO result
   FROM public.app_access_invitations i WHERE scope=kind AND resource_id=resource AND status='pending' AND expires_at>now();
  RETURN result;
 ELSIF p_action IN ('create','change') THEN
  IF p_action='change' AND kind NOT IN ('workspace','inventory') THEN RAISE invalid_parameter_value; END IF;
  IF p_action='change' AND (requested='none' OR (requested='inherit' AND kind='inventory' AND
    (public.findez_inventory_role(resource,(p_data->>'user_id')::uuid) IS NOT NULL OR
     EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=resource AND access_mode='restricted')))) THEN
   RETURN public.findez_manage_collaboration(p_actor,CASE kind WHEN 'workspace' THEN 'workspace_member' ELSE 'inventory_member' END,
    jsonb_build_object(CASE kind WHEN 'workspace' THEN 'team_id' ELSE 'inventory_id' END,resource,'user_id',p_data->>'user_id','role',requested));
  END IF;
  IF NOT public.findez_can_invite_access(p_actor,kind,resource,requested) THEN RAISE insufficient_privilege; END IF;
  IF kind='organization' THEN
   SELECT organization_id,name INTO org,title FROM public.app_organizations WHERE organization_id=resource FOR UPDATE;
  ELSIF kind='workspace' THEN
   SELECT team_id,organization_id,name INTO ws,org,title FROM public.teams WHERE team_id=resource FOR UPDATE;
  ELSE
   SELECT inventory_id,team_id,name INTO inv,ws,title FROM public.app_inventories WHERE inventory_id=resource FOR UPDATE;
   SELECT organization_id INTO org FROM public.teams WHERE team_id=ws;
   IF ws IS NULL THEN RAISE check_violation; END IF;
  END IF;
  IF title IS NULL THEN RAISE no_data_found; END IF;
  IF p_action='change' THEN
   SELECT lower(email) INTO mail FROM auth.users WHERE id=(p_data->>'user_id')::uuid;
  ELSE mail:=lower(btrim(p_data->>'email')); END IF;
  IF mail IS NULL OR length(mail)>254 OR mail!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN RAISE check_violation; END IF;
  SELECT id INTO target FROM auth.users WHERE lower(email)=mail;
  IF target=p_actor THEN RAISE check_violation; END IF;
  IF kind='organization' THEN
   already:=EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=target);
  ELSIF kind='workspace' THEN
   IF org IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=target) THEN RAISE check_violation USING message='They must accept organization membership first.'; END IF;
   already:=EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=target);
  ELSE
   IF NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=target) THEN RAISE check_violation USING message='They must accept workspace membership first.'; END IF;
   already:=public.findez_inventory_role(inv,target) IS NOT NULL;
  END IF;
  IF already THEN
   IF p_action='change' THEN
    RETURN public.findez_manage_collaboration(p_actor,CASE kind WHEN 'workspace' THEN 'workspace_member' ELSE 'inventory_member' END,
     jsonb_build_object(CASE kind WHEN 'workspace' THEN 'team_id' ELSE 'inventory_id' END,resource,'user_id',target,'role',requested));
   END IF;
   RAISE unique_violation USING message='This person is already a member.';
  END IF;
  IF (SELECT count(*) FROM public.app_access_invitations WHERE invited_by=p_actor AND created_at>now()-interval '1 hour')>=30 THEN RAISE check_violation USING message='Too many invitations. Try again later.'; END IF;
  UPDATE public.app_access_invitations SET status='expired',decided_at=now() WHERE scope=kind AND resource_id=resource AND recipient_email=mail AND status='pending' AND expires_at<=now();
  INSERT INTO public.app_access_invitations(scope,resource_id,resource_name,organization_id,team_id,inventory_id,recipient_email,invited_by,invited_by_name,role,code_hash)
   VALUES(kind,resource,title,org,ws,inv,mail,p_actor,coalesce((SELECT coalesce(nullif(display_name,''),nullif(btrim(coalesce(first_name,'')||' '||coalesce(last_name,'')),'')) FROM public.profiles WHERE id=p_actor),'FindEZ member'),requested,p_data->>'code_hash') RETURNING * INTO r;
 ELSE
  IF p_data->>'code_hash' IS NOT NULL THEN
   SELECT * INTO r FROM public.app_access_invitations WHERE code_hash=p_data->>'code_hash';
  ELSE
   SELECT * INTO r FROM public.app_access_invitations WHERE invitation_id=(p_data->>'invitation_id')::uuid;
  END IF;
  IF r.invitation_id IS NULL THEN RAISE no_data_found; END IF;
  IF p_action='cancel' THEN
   IF NOT public.findez_can_invite_access(p_actor,r.scope,r.resource_id,r.role) THEN RAISE insufficient_privilege; END IF;
  ELSIF mail<>r.recipient_email THEN RAISE insufficient_privilege; END IF;
  IF p_action='preview' THEN
   RETURN to_jsonb(r)-'code_hash'-'recipient_email';
  END IF;
  IF p_action NOT IN ('accept','decline','cancel') THEN RAISE invalid_parameter_value; END IF;
  -- Resource-first lock order matches creation and role changes. Parent/member
  -- locks keep authorization stable until the acceptance transaction commits.
  IF r.organization_id IS NOT NULL THEN PERFORM 1 FROM public.app_organizations WHERE organization_id=r.organization_id FOR UPDATE; END IF;
  IF r.team_id IS NOT NULL THEN PERFORM 1 FROM public.teams WHERE team_id=r.team_id FOR UPDATE; END IF;
  IF r.inventory_id IS NOT NULL THEN PERFORM 1 FROM public.app_inventories WHERE inventory_id=r.inventory_id FOR UPDATE; END IF;
  PERFORM 1 FROM public.app_organization_members WHERE organization_id=r.organization_id AND user_id IN (p_actor,r.invited_by) FOR SHARE;
  PERFORM 1 FROM public.team_memberships WHERE team_id=r.team_id AND user_id IN (p_actor,r.invited_by) FOR SHARE;
  PERFORM 1 FROM public.app_inventory_members WHERE inventory_id=r.inventory_id AND user_id IN (p_actor,r.invited_by) FOR SHARE;
  SELECT * INTO r FROM public.app_access_invitations WHERE invitation_id=r.invitation_id FOR UPDATE;
  IF r.status<>'pending' THEN
   -- Replay never recreates access after later revocation.
   IF (p_action='accept' AND r.status='accepted' AND r.accepted_by=p_actor) OR (p_action='decline' AND r.status='declined') OR (p_action='cancel' AND r.status='cancelled') THEN RETURN to_jsonb(r)-'code_hash'-'recipient_email'; END IF;
   RAISE check_violation USING message='This invitation is no longer pending.';
  END IF;
  IF r.expires_at<=now() THEN RAISE check_violation USING message='This invitation has expired.'; END IF;
  IF p_action='accept' THEN
   -- Lock the resource before rechecking current authority/parent scope.
   IF r.scope='organization' THEN
    PERFORM 1 FROM public.app_organizations WHERE organization_id=r.resource_id FOR UPDATE;
   ELSIF r.scope='workspace' THEN
    SELECT organization_id INTO org FROM public.teams WHERE team_id=r.resource_id FOR UPDATE;
    IF org IS DISTINCT FROM r.organization_id THEN RAISE check_violation; END IF;
    IF org IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=p_actor) THEN RAISE check_violation USING message='Accept the organization invitation first.'; END IF;
   ELSE
    SELECT team_id INTO ws FROM public.app_inventories WHERE inventory_id=r.resource_id FOR UPDATE;
    IF ws IS DISTINCT FROM r.team_id OR NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=p_actor) THEN RAISE check_violation; END IF;
    IF (SELECT organization_id FROM public.teams WHERE team_id=ws) IS DISTINCT FROM r.organization_id THEN RAISE check_violation; END IF;
   END IF;
   IF NOT public.findez_can_invite_access(r.invited_by,r.scope,r.resource_id,r.role) THEN RAISE insufficient_privilege USING message='The sender can no longer grant this access.'; END IF;
   -- Existing access gained separately must not be overwritten by a stale invite.
   IF r.scope='organization' THEN
    IF NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=r.resource_id AND user_id=p_actor) THEN
     PERFORM public.findez_manage_collaboration_legacy(r.invited_by,'organization_member',jsonb_build_object('organization_id',r.resource_id,'user_id',p_actor,'role',r.role));
    END IF;
   ELSIF r.scope='workspace' THEN
    IF NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=r.resource_id AND user_id=p_actor) THEN
     IF r.organization_id IS NOT NULL THEN
      PERFORM public.findez_manage_collaboration_legacy(r.invited_by,'workspace_member',jsonb_build_object('team_id',r.resource_id,'user_id',p_actor,'role',r.role));
     ELSE
      INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(r.resource_id,p_actor,CASE r.role WHEN 'admin' THEN 'mentor' WHEN 'editor' THEN 'member' ELSE 'viewer' END);
     END IF;
    END IF;
   ELSIF public.findez_inventory_role(r.resource_id,p_actor) IS NULL THEN
    PERFORM public.findez_manage_collaboration_legacy(r.invited_by,'inventory_member',jsonb_build_object('inventory_id',r.resource_id,'user_id',p_actor,'role',r.role));
   END IF;
  END IF;
  UPDATE public.app_access_invitations SET status=CASE p_action WHEN 'accept' THEN 'accepted' WHEN 'decline' THEN 'declined' ELSE 'cancelled' END,
   decided_at=now(),seen_at=now(),accepted_by=CASE WHEN p_action='accept' THEN p_actor ELSE NULL END WHERE invitation_id=r.invitation_id RETURNING * INTO r;
 END IF;
 INSERT INTO public.app_access_audit(actor_id,organization_id,team_id,inventory_id,action,target_id,changes)
 VALUES(p_actor,r.organization_id,r.team_id,r.inventory_id,'invitation_'||CASE WHEN p_action='change' THEN 'create' ELSE p_action END,r.invitation_id,jsonb_build_object('scope',r.scope,'role',r.role,'status',r.status));
 RETURN to_jsonb(r)-'code_hash';
END $$;
REVOKE ALL ON FUNCTION public.findez_access_invitation(uuid,text,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_access_invitation(uuid,text,jsonb) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

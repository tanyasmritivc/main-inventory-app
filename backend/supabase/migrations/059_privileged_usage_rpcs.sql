-- Usage accounting is a backend operation. SECURITY DEFINER functions otherwise
-- bypass table RLS for callers supplying another user's/team's UUID.
BEGIN;
REVOKE ALL ON FUNCTION public.increment_chat_usage(uuid,text),
 public.increment_scan_usage(uuid,text),
 public.increment_usage_count(uuid,text,text),
 public.increment_team_chat_usage(uuid,text),
 public.increment_team_scan_usage(uuid,text),
 public.increment_team_import_usage(uuid,text),
 public.consume_api_key_rate_limit(uuid,text,integer)
 FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_chat_usage(uuid,text),
 public.increment_scan_usage(uuid,text),
 public.increment_usage_count(uuid,text,text),
 public.increment_team_chat_usage(uuid,text),
 public.increment_team_scan_usage(uuid,text),
 public.increment_team_import_usage(uuid,text),
 public.consume_api_key_rate_limit(uuid,text,integer)
 TO service_role;

-- Roster SELECT policies need this helper for auth.uid(), but clients must not
-- probe arbitrary users' membership. Backend callers keep service access.
CREATE OR REPLACE FUNCTION public.findez_is_team_member(p_team_id uuid,p_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
 SELECT (p_user_id = auth.uid() OR auth.role() = 'service_role')
 AND EXISTS (SELECT 1 FROM public.team_memberships tm
             WHERE tm.team_id = p_team_id AND tm.user_id = p_user_id);
$$;
REVOKE ALL ON FUNCTION public.findez_is_team_member(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.findez_is_team_member(uuid,uuid) TO authenticated,service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;

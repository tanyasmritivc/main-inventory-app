-- Directory discovery uses the same effective role as workspace/content APIs.
-- Organization administrators need no duplicate team_memberships row.
BEGIN;
DO $$
DECLARE body text; old_guard text := 'NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=p_actor)';
 new_guard text := 'public.findez_workspace_role(ws,p_actor) IS NULL';
BEGIN
 SELECT pg_get_functiondef('public.findez_workspace_directory(uuid,text,jsonb)'::regprocedure) INTO body;
 IF strpos(body,old_guard)>0 THEN
  body:=replace(body,old_guard,new_guard);
  EXECUTE body;
 ELSIF strpos(body,new_guard)=0 THEN
  RAISE EXCEPTION 'Workspace directory definition changed; review before applying 072';
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.findez_workspace_directory(uuid,text,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_workspace_directory(uuid,text,jsonb) TO service_role;
COMMIT;

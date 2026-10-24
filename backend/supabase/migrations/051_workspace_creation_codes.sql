-- Match the existing workspace code alphabet and retry only code collisions.
-- Function changes only. Installing this migration creates/deletes no records.
BEGIN;
CREATE FUNCTION public.findez_workspace_join_code() RETURNS text
LANGUAGE plpgsql VOLATILE SET search_path=public AS $code$
DECLARE entropy bytea:=uuid_send(gen_random_uuid()); result text:=''; i integer;
BEGIN
 FOR i IN 0..5 LOOP
  result:=result||substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',(get_byte(entropy,i)&31)+1,1);
 END LOOP;
 RETURN result;
END $code$;
REVOKE ALL ON FUNCTION public.findez_workspace_join_code() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_workspace_join_code() TO service_role;
DO $patch$
DECLARE target regprocedure; definition text;
 old_sql text:=$old$INSERT INTO public.teams(name,owner_user_id,program,custom_category,join_code,organization_id)
   VALUES(btrim(p_data->>'name'),p_actor,'custom','Project',upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),org)
   RETURNING team_id,to_jsonb(teams.*)-'join_code' INTO ws,saved;$old$;
 new_sql text:=$new$DECLARE attempt integer; failed_constraint text;
  BEGIN
   FOR attempt IN 1..5 LOOP
    BEGIN
     INSERT INTO public.teams(name,owner_user_id,program,custom_category,join_code,organization_id)
      VALUES(btrim(p_data->>'name'),p_actor,'custom','Project',public.findez_workspace_join_code(),org)
      RETURNING team_id,to_jsonb(teams.*)-'join_code' INTO ws,saved;
     EXIT;
    EXCEPTION WHEN unique_violation THEN
     GET STACKED DIAGNOSTICS failed_constraint = CONSTRAINT_NAME;
     IF failed_constraint <> 'teams_join_code_key' OR attempt = 5 THEN RAISE; END IF;
    END;
   END LOOP;
  END;$new$;
BEGIN
 target:=coalesce(to_regprocedure('public.findez_manage_collaboration_legacy(uuid,text,jsonb)'),
                  to_regprocedure('public.findez_manage_collaboration(uuid,text,jsonb)'));
 IF target IS NULL THEN RAISE EXCEPTION 'Workspace administration function is missing'; END IF;
 SELECT pg_get_functiondef(target) INTO definition;
 IF position(old_sql IN definition)=0 THEN RAISE EXCEPTION 'Workspace creation source differs; review before applying'; END IF;
 EXECUTE replace(definition,old_sql,new_sql);
END $patch$;
NOTIFY pgrst,'reload schema';
COMMIT;

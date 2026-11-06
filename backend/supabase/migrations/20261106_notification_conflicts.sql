-- A stale user revision is a permanent HTTP conflict, not a transient database
-- serialization failure. PostgREST 14 retries SQLSTATE 40001 indefinitely.
BEGIN;
DO $$ DECLARE definition text;
BEGIN
 definition:=pg_get_functiondef('public.findez_notification_preferences(uuid,jsonb,bigint,text)'::regprocedure);
 IF strpos(definition,'RAISE serialization_failure;')>0 THEN
  definition:=replace(definition,'RAISE serialization_failure;',
   'RAISE SQLSTATE ''PT409'' USING MESSAGE = ''Notification preferences changed. Refresh and try again.'';');
  EXECUTE definition;
 ELSIF strpos(definition,'PT409')=0 THEN
  RAISE EXCEPTION 'Unexpected notification revision guard; review before migrating';
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

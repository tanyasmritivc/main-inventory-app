-- Profile presentation is editable; billing, entitlement and storage references
-- are server-owned. Preserve the exact native/web signup upsert columns.
BEGIN;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.profiles FROM PUBLIC,anon,authenticated;
-- Also retire any explicit historical column grants, not just table grants.
DO $$ DECLARE cols text; BEGIN
 SELECT string_agg(quote_ident(attname),',') INTO cols FROM pg_attribute
 WHERE attrelid='public.profiles'::regclass AND attnum>0 AND NOT attisdropped;
 EXECUTE format('REVOKE INSERT(%s),UPDATE(%s),REFERENCES(%s) ON public.profiles FROM PUBLIC,anon,authenticated',cols,cols,cols);
END $$;
GRANT INSERT(id,display_name,first_name,last_name,profile_role,organization,contact_email,avatar_color)
 ON public.profiles TO authenticated;
GRANT UPDATE(id,display_name,first_name,last_name,profile_role,organization,contact_email,avatar_color)
 ON public.profiles TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.profiles TO service_role;
COMMIT;

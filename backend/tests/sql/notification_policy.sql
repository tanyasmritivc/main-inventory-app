-- Empty disposable database only. Contains synthetic identities; never production.
\set ON_ERROR_STOP on
DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF; IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF; IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role BYPASSRLS; END IF; END $$;
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA auth TO authenticated,service_role;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid $$;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE public.user_memory(user_id uuid REFERENCES auth.users ON DELETE CASCADE,key text,memory_kind text,payload jsonb,PRIMARY KEY(user_id,key));
CREATE TABLE public.app_inventories(inventory_id uuid PRIMARY KEY);
CREATE TABLE public.test_grants(user_id uuid,inventory_id uuid,role text);
CREATE FUNCTION public.findez_inventory_role(i uuid,u uuid) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS $$ SELECT role FROM public.test_grants WHERE user_id=u AND inventory_id=i $$;
CREATE FUNCTION public.findez_request_actor() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT auth.uid() $$;
CREATE TABLE public.items(item_id uuid PRIMARY KEY,inventory_id uuid REFERENCES public.app_inventories,user_id uuid REFERENCES auth.users ON DELETE CASCADE,name text,quantity int,location text,space_id uuid,updated_at timestamptz,reorder_enabled boolean DEFAULT false,reorder_threshold int);
CREATE TABLE public.capture_reviews(review_id uuid PRIMARY KEY,inventory_id uuid REFERENCES public.app_inventories,user_id uuid REFERENCES auth.users ON DELETE CASCADE,status text);
CREATE TABLE public.push_devices(device_token text PRIMARY KEY,user_id uuid REFERENCES auth.users ON DELETE CASCADE,environment text,enabled bool,updated_at timestamptz);
INSERT INTO auth.users VALUES('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
INSERT INTO public.app_inventories VALUES('20000000-0000-0000-0000-000000000001'),('20000000-0000-0000-0000-000000000002');
INSERT INTO public.test_grants SELECT id,'20000000-0000-0000-0000-000000000001','editor' FROM auth.users;
INSERT INTO public.user_memory SELECT id,'__settings_v1','settings','{"enabled":true,"generation":0}' FROM auth.users;
\ir ../../supabase/migrations/081_personalization_engine.sql
\ir ../../supabase/migrations/20261106_notification_policy.sql
\ir ../../supabase/migrations/20261106_notification_conflicts.sql
\ir ../../supabase/migrations/20261106_notification_conflicts.sql

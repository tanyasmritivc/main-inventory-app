-- Only included in the empty disposable API permissions database.
-- Match existing production columns omitted from the older minimal fixture.
ALTER TABLE public.team_shares ADD COLUMN IF NOT EXISTS permission text DEFAULT 'view';
ALTER TABLE public.team_shares ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;
ALTER TABLE public.team_shares ADD COLUMN IF NOT EXISTS expires_at timestamptz;
ALTER TABLE public.items ADD COLUMN IF NOT EXISTS purchase_source text;
ALTER TABLE public.items ADD COLUMN IF NOT EXISTS notes text;
\ir ../../supabase/migrations/007_atomic_usage_increment.sql
\ir ../../supabase/migrations/079_connector_import_sessions.sql
\ir ../../supabase/migrations/079_connector_import_sessions.sql
\ir connector_import_sessions.sql

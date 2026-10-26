-- Runs after the existing complete inventory/organization SQL fixture.
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
CREATE TABLE IF NOT EXISTS public.user_memory (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
 key text NOT NULL,value text NOT NULL,updated_at timestamptz DEFAULT now(),UNIQUE(user_id,key)
);
ALTER TABLE public.user_memory ENABLE ROW LEVEL SECURITY;
\ir ../../supabase/migrations/048_account_memory.sql
SET ROLE service_role;
DO $$ BEGIN BEGIN INSERT INTO public.user_memory(user_id,key,value) VALUES('20000000-0000-0000-0000-000000000001','old-client','Not confirmed'); RAISE EXCEPTION 'legacy extraction accepted'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: legacy auto-extraction is disabled by the database'; END; END $$;
SELECT public.findez_change_memory('20000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000001',repeat('a',64),0,'settings',NULL,'{"enabled":true}');
SELECT public.findez_change_memory('20000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000002',repeat('b',64),1,'set','answer_format','{"value":"bullets"}');
RESET ROLE;
INSERT INTO public.spaces(id,user_id,name,inventory_id)
VALUES('48000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','Memory fixture Shelf',public.findez_default_inventory('20000000-0000-0000-0000-000000000001'));
SET ROLE service_role;
SELECT public.findez_change_memory('20000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000004',repeat('c',64),2,'set','alias:'||repeat('a',64),'{"alias":"bench","space_id":"48000000-0000-0000-0000-000000000003"}',public.findez_default_inventory('20000000-0000-0000-0000-000000000001'));
SELECT pg_temp.check((SELECT count(*)=1 FROM public.inventory_user_memory WHERE user_id='20000000-0000-0000-0000-000000000001' AND memory_kind='alias'),'private alias works with actual inventory triggers');
SELECT public.findez_change_memory('20000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000005',repeat('d',64),3,'clear');
SELECT pg_temp.check((SELECT count(*)=1 FROM public.user_memory WHERE user_id='20000000-0000-0000-0000-000000000001'),'forget keeps only disabled control with actual schema');
RESET ROLE;

-- Voluntary setup answers. No inventory writes, public analytics or Team access.
BEGIN;
CREATE TABLE public.onboarding_responses (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  schema_version smallint NOT NULL DEFAULT 1 CHECK (schema_version = 1),
  use_case text NOT NULL CHECK (use_case IN ('household','business','laboratory','education','robotics','manufacturing','warehouse','other')),
  use_case_other text,
  inventory_types text[] NOT NULL CHECK (cardinality(inventory_types) BETWEEN 1 AND 7
    AND array_position(inventory_types, NULL) IS NULL
    AND inventory_types <@ ARRAY['tools','equipment','parts','supplies','products','household_items','other']::text[]),
  inventory_other text,
  primary_goal text NOT NULL CHECK (primary_goal IN ('find_items','identify_items','track_stock','organize_spaces','share_inventory')),
  collaboration text NOT NULL CHECK (collaboration IN ('solo','others')),
  source text NOT NULL DEFAULT 'ios' CHECK (source = 'ios'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT onboarding_use_case_other CHECK (
    (use_case = 'other' AND use_case_other IS NOT NULL AND use_case_other = btrim(use_case_other)
      AND char_length(use_case_other) BETWEEN 1 AND 80 AND use_case_other !~ '[[:cntrl:]]')
    OR (use_case <> 'other' AND use_case_other IS NULL)),
  CONSTRAINT onboarding_inventory_other CHECK (
    ('other' = ANY(inventory_types) AND inventory_other IS NOT NULL AND inventory_other = btrim(inventory_other)
      AND char_length(inventory_other) BETWEEN 1 AND 80 AND inventory_other !~ '[[:cntrl:]]')
    OR (NOT ('other' = ANY(inventory_types)) AND inventory_other IS NULL))
);
ALTER TABLE public.onboarding_responses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.onboarding_responses FROM anon, authenticated;
GRANT SELECT ON public.onboarding_responses TO authenticated;
GRANT ALL ON public.onboarding_responses TO service_role;
CREATE POLICY onboarding_owner_read ON public.onboarding_responses FOR SELECT TO authenticated
  USING (auth.uid() = user_id AND coalesce(nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'api_key_id','') = '');
COMMENT ON TABLE public.onboarding_responses IS 'Latest voluntary four-question setup answers per signed-in account; operator access only, not shared with Teams.';
NOTIFY pgrst, 'reload schema';
COMMIT;

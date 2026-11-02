-- Broader group categories; existing IDs, plans, ownership and memberships stay intact.
BEGIN;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS custom_category text;
ALTER TABLE public.teams DROP CONSTRAINT IF EXISTS teams_program_check;
ALTER TABLE public.teams ADD CONSTRAINT teams_program_check CHECK (program IN (
  'agriculture', 'art_design', 'automotive', 'business', 'club',
  'construction', 'custom', 'education', 'electronics', 'engineering',
  'hospitality', 'manufacturing', 'fll', 'frc', 'ftc',
  'healthcare', 'household', 'laboratory', 'logistics', 'makerspace',
  'nonprofit', 'office', 'other', 'research', 'retail',
  'robotics', 'sports', 'studio', 'vex'
));
ALTER TABLE public.teams DROP CONSTRAINT IF EXISTS teams_custom_category_check;
ALTER TABLE public.teams ADD CONSTRAINT teams_custom_category_check CHECK (
  (program = 'custom' AND custom_category IS NOT NULL
    AND custom_category = btrim(custom_category)
    AND char_length(custom_category) BETWEEN 1 AND 60
    AND custom_category !~ '[[:cntrl:]]')
  OR (program <> 'custom' AND custom_category IS NULL)
);
NOTIFY pgrst, 'reload schema';
COMMIT;

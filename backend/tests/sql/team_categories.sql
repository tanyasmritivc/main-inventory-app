-- Complete the deliberately minimal API fixture with the category/plan columns.
ALTER TABLE public.teams ADD COLUMN program text NOT NULL DEFAULT 'business';
ALTER TABLE public.teams ADD COLUMN plan text CHECK (plan IN ('free_rookie','ftc_season','frc_season','district'));
ALTER TABLE public.teams ADD CONSTRAINT teams_program_check CHECK (program IN (
  'robotics','ftc','frc','fll','vex','education','makerspace','club','business','other'
));
UPDATE public.teams SET program = 'ftc', plan = 'ftc_season'
WHERE team_id = '10000000-0000-0000-0000-000000000001';
\ir ../../supabase/migrations/040_inventory_team_categories.sql

BEGIN;
SELECT pg_temp.check((SELECT program = 'ftc' AND plan = 'ftc_season' AND custom_category IS NULL
  FROM public.teams WHERE team_id = '10000000-0000-0000-0000-000000000001'), 'legacy category and plan preserved');
UPDATE public.teams SET program = 'custom', custom_category = 'Costume department'
WHERE team_id = '10000000-0000-0000-0000-000000000002';
SELECT pg_temp.check((SELECT custom_category = 'Costume department' FROM public.teams
  WHERE team_id = '10000000-0000-0000-0000-000000000002'), 'custom label persists');
DO $$ BEGIN
  BEGIN UPDATE public.teams SET custom_category = '   ' WHERE program = 'custom';
    RAISE EXCEPTION 'blank category accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE public.teams SET custom_category = repeat('x',61) WHERE program = 'custom';
    RAISE EXCEPTION 'long category accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE public.teams SET custom_category = E'one\ntwo' WHERE program = 'custom';
    RAISE EXCEPTION 'multiline category accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE public.teams SET program = 'custom', custom_category = NULL;
    RAISE EXCEPTION 'missing category accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE public.teams SET program = 'laboratory' WHERE program = 'custom';
    RAISE EXCEPTION 'custom label on preset accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE public.teams SET program = 'invented';
    RAISE EXCEPTION 'unknown category accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE public.teams SET plan = 'invented';
    RAISE EXCEPTION 'plan constraint lost'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
UPDATE public.teams SET program = 'manufacturing', custom_category = NULL;
SELECT pg_temp.check((SELECT count(*) = 3 FROM public.teams WHERE program = 'manufacturing'), 'manufacturing supported');
UPDATE public.teams SET program = 'laboratory';
UPDATE public.teams SET program = 'household';
ROLLBACK;

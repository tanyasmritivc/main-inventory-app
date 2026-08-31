alter table public.teams drop constraint if exists teams_program_check;
alter table public.teams add constraint teams_program_check check (program in (
  'robotics', 'ftc', 'frc', 'fll', 'vex',
  'education', 'makerspace', 'club', 'business', 'other'
));

notify pgrst, 'reload schema';

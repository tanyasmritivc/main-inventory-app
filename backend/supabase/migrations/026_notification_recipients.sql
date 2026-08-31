create table if not exists public.team_notification_recipients (
  activity_id uuid not null references public.team_activity(activity_id) on delete cascade,
  user_id uuid not null,
  reason text not null default 'team_activity',
  created_at timestamptz not null default now(),
  primary key (activity_id, user_id)
);

create index if not exists team_notification_recipients_user_idx
  on public.team_notification_recipients (user_id, created_at desc);

alter table public.team_notification_recipients enable row level security;
revoke all on public.team_notification_recipients from anon, authenticated;

notify pgrst, 'reload schema';

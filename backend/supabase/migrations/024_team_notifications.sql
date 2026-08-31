alter table public.team_activity drop constraint if exists team_activity_action_check;
alter table public.team_activity add constraint team_activity_action_check check (action in (
    'space_created', 'space_added', 'space_removed',
    'item_added', 'item_updated', 'item_deleted',
    'task_created', 'task_updated', 'task_completed', 'task_deleted',
    'member_joined', 'member_role_changed', 'member_removed'
));

create table if not exists public.team_notification_reads (
    user_id     uuid not null,
    activity_id uuid not null references public.team_activity(activity_id) on delete cascade,
    read_at     timestamptz not null default now(),
    primary key (user_id, activity_id)
);

create index if not exists team_notification_reads_user_idx
    on public.team_notification_reads(user_id, read_at desc);

alter table public.team_notification_reads enable row level security;
revoke all on public.team_notification_reads from anon, authenticated;

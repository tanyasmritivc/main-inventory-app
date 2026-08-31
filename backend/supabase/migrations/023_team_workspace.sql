-- Team workspaces associate existing user-owned spaces with one organization.
-- Removing an association never deletes the underlying space or its items.

create table if not exists public.team_spaces (
    team_space_id uuid primary key default gen_random_uuid(),
    team_id       uuid not null references public.teams(team_id) on delete cascade,
    space_id      uuid not null references public.spaces(id) on delete cascade,
    linked_by     uuid not null,
    created_at    timestamptz not null default now(),
    unique (team_id, space_id),
    unique (space_id)
);

create index if not exists team_spaces_team_id_idx on public.team_spaces(team_id);

create table if not exists public.team_activity (
    activity_id uuid primary key default gen_random_uuid(),
    team_id     uuid not null references public.teams(team_id) on delete cascade,
    actor_id    uuid not null,
    action      text not null check (action in (
        'space_created', 'space_added', 'space_removed',
        'item_added', 'item_updated', 'item_deleted'
    )),
    summary     text not null check (char_length(summary) between 1 and 300),
    metadata    jsonb not null default '{}'::jsonb,
    created_at  timestamptz not null default now()
);

create index if not exists team_activity_team_created_idx
    on public.team_activity(team_id, created_at desc);

alter table public.team_spaces enable row level security;
alter table public.team_activity enable row level security;
revoke all on public.team_spaces from anon, authenticated;
revoke all on public.team_activity from anon, authenticated;

-- Access is service-role-only. FastAPI verifies team membership and role.

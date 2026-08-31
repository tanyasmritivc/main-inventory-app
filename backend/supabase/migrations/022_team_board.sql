create table if not exists public.team_board_tasks (
    task_id          uuid primary key default gen_random_uuid(),
    team_id          uuid not null references public.teams(team_id) on delete cascade,
    created_by       uuid not null,
    assigned_to      uuid,
    task_type        text not null default 'task'
                     check (task_type in ('task', 'part_request', 'checklist')),
    title            text not null check (char_length(title) between 1 and 160),
    description      text not null default '' check (char_length(description) <= 2000),
    status           text not null default 'todo'
                     check (status in ('todo', 'doing', 'done')),
    priority         text not null default 'normal'
                     check (priority in ('normal', 'high', 'urgent')),
    inventory_item_id uuid,
    project_kit_id   uuid references public.project_kits(id) on delete set null,
    due_at           timestamptz,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now()
);

create index if not exists team_board_tasks_team_status_idx
    on public.team_board_tasks(team_id, status, updated_at desc);
create index if not exists team_board_tasks_assigned_idx
    on public.team_board_tasks(assigned_to, status);

alter table public.team_board_tasks enable row level security;
revoke all on public.team_board_tasks from anon, authenticated;

-- Application access is intentionally service-role-only. FastAPI checks the
-- caller's team_memberships row and role for every operation.

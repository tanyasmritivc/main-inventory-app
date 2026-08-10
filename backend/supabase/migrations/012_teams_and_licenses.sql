-- 012_teams_and_licenses.sql
--
-- Team-level plan model. Completely separate from the old team_shares / team_members
-- sharing system — those tables are NOT touched here (deprecated in code only).
--
-- Table naming:
--   teams             — new; no existing table with this name
--   team_memberships  — new; avoids collision with existing team_members (sharing system)
--   licenses          — new
--   team_usage_counters — new; tracks team-level AI soft-cap usage

-- ── teams ──────────────────────────────────────────────────────────────────────
create table if not exists public.teams (
    team_id         uuid        primary key default gen_random_uuid(),
    name            text        not null,
    owner_user_id   uuid        not null,
    -- nullable: no plan until a license is redeemed
    plan            text        check (plan in ('free_rookie','ftc_season','frc_season','district')),
    plan_expires_at timestamptz,
    -- 6-char invite code: A-Z minus I/O, digits 2-9 (no 0/1)
    join_code       char(6)     not null unique
                                check (join_code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$'),
    program         text        not null check (program in ('ftc','frc','vex','fll')),
    created_at      timestamptz not null default now()
);

create index if not exists teams_owner_user_id_idx  on public.teams (owner_user_id);
create index if not exists teams_join_code_idx       on public.teams (join_code);

-- ── team_memberships ───────────────────────────────────────────────────────────
-- Named team_memberships (NOT team_members) to avoid collision with the existing
-- team_shares–linked team_members table used by the old sharing system.
create table if not exists public.team_memberships (
    member_id   uuid        primary key default gen_random_uuid(),
    team_id     uuid        not null references public.teams(team_id) on delete cascade,
    user_id     uuid        not null,
    role        text        not null default 'member'
                            check (role in ('owner','mentor','member','viewer')),
    joined_at   timestamptz not null default now(),
    unique (team_id, user_id)
);

-- Exactly-one-owner invariant is enforced in application code, not here.

create index if not exists team_memberships_user_id_idx  on public.team_memberships (user_id);
create index if not exists team_memberships_team_id_idx  on public.team_memberships (team_id);

-- ── licenses ───────────────────────────────────────────────────────────────────
create table if not exists public.licenses (
    code            text        primary key,
    plan            text        not null
                                check (plan in ('free_rookie','ftc_season','frc_season','district')),
    seats           integer     not null default 30,
    expires_at      timestamptz not null,
    redeemed_by     uuid,       -- team_id that redeemed (nullable until redeemed)
    redeemed_at     timestamptz
);

-- ── team_usage_counters ────────────────────────────────────────────────────────
-- Per-team, per-period soft-cap counters for AI features.
-- Period is YYYY-MM (same convention as usage_counters).
create table if not exists public.team_usage_counters (
    team_id         uuid        not null references public.teams(team_id) on delete cascade,
    period          text        not null,
    chats_used      integer     not null default 0,
    scans_used      integer     not null default 0,
    imports_used    integer     not null default 0,
    updated_at      timestamptz not null default now(),
    primary key (team_id, period)
);

-- ── RLS ────────────────────────────────────────────────────────────────────────
-- Backend always uses the service role and bypasses RLS. Policies are
-- defence-in-depth, consistent with existing tables.

alter table public.teams              enable row level security;
alter table public.team_memberships   enable row level security;
alter table public.licenses           enable row level security;
alter table public.team_usage_counters enable row level security;

-- teams: any member may read their team row
create policy "team_member_can_read_team" on public.teams
    for select using (
        exists (
            select 1 from public.team_memberships tm
            where tm.team_id = teams.team_id
              and tm.user_id = auth.uid()
        )
    );

-- team_memberships: members may read the roster for teams they belong to
create policy "team_member_can_read_roster" on public.team_memberships
    for select using (
        exists (
            select 1 from public.team_memberships tm
            where tm.team_id = team_memberships.team_id
              and tm.user_id = auth.uid()
        )
    );

-- licenses: no direct user access; service role only
create policy "licenses_deny_user_access" on public.licenses
    for all using (false);

-- team_usage_counters: no direct user access; service role only
create policy "team_usage_deny_user_access" on public.team_usage_counters
    for all using (false);

-- ── Atomic team usage RPCs ─────────────────────────────────────────────────────

create or replace function public.increment_team_chat_usage(
    p_team_id uuid,
    p_period  text
)
returns table(chats_used integer)
language sql
security definer
set search_path = public
as $$
    insert into public.team_usage_counters (team_id, period, chats_used, scans_used, imports_used)
    values (p_team_id, p_period, 1, 0, 0)
    on conflict (team_id, period)
    do update set
        chats_used = public.team_usage_counters.chats_used + 1,
        updated_at = now()
    returning public.team_usage_counters.chats_used;
$$;

create or replace function public.increment_team_scan_usage(
    p_team_id uuid,
    p_period  text
)
returns table(scans_used integer)
language sql
security definer
set search_path = public
as $$
    insert into public.team_usage_counters (team_id, period, chats_used, scans_used, imports_used)
    values (p_team_id, p_period, 0, 1, 0)
    on conflict (team_id, period)
    do update set
        scans_used = public.team_usage_counters.scans_used + 1,
        updated_at = now()
    returning public.team_usage_counters.scans_used;
$$;

create or replace function public.increment_team_import_usage(
    p_team_id uuid,
    p_period  text
)
returns table(imports_used integer)
language sql
security definer
set search_path = public
as $$
    insert into public.team_usage_counters (team_id, period, chats_used, scans_used, imports_used)
    values (p_team_id, p_period, 0, 0, 1)
    on conflict (team_id, period)
    do update set
        imports_used = public.team_usage_counters.imports_used + 1,
        updated_at = now()
    returning public.team_usage_counters.imports_used;
$$;

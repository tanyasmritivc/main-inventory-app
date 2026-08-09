-- 010_tier_and_usage_counters.sql
--
-- 1. Add profiles.tier ('free' | 'pro' | 'team_member'), backfill from is_pro.
--    is_pro is kept for backward compat; Stripe still writes it.
-- 2. Create usage_counters table: atomic monthly chat + scan + daily scan tracking.
-- 3. Atomic RPCs for chat and scan increments.

-- ── profiles.tier ──────────────────────────────────────────────────────────────

alter table public.profiles
    add column if not exists tier text not null default 'free'
        check (tier in ('free', 'pro', 'team_member'));

-- Backfill from is_pro (idempotent: only touches rows still at 'free')
update public.profiles
set tier = 'pro'
where is_pro = true and tier = 'free';

-- ── usage_counters ─────────────────────────────────────────────────────────────

create table if not exists public.usage_counters (
    user_id     uuid        not null,
    period      text        not null,   -- YYYY-MM
    chats_used  integer     not null default 0,
    scans_used  integer     not null default 0,
    scans_today integer     not null default 0,
    today       date        not null default current_date,
    updated_at  timestamptz not null default now(),
    primary key (user_id, period)
);

-- ── Atomic increment RPCs ──────────────────────────────────────────────────────

create or replace function public.increment_chat_usage(
    p_user_id uuid,
    p_period  text
)
returns table(chats_used integer)
language sql
security definer
set search_path = public
as $$
    insert into public.usage_counters (user_id, period, chats_used, scans_used, scans_today, today)
    values (p_user_id, p_period, 1, 0, 0, current_date)
    on conflict (user_id, period)
    do update set
        chats_used = public.usage_counters.chats_used + 1,
        updated_at = now()
    returning public.usage_counters.chats_used;
$$;

create or replace function public.increment_scan_usage(
    p_user_id uuid,
    p_period  text
)
returns table(scans_used integer, scans_today integer)
language sql
security definer
set search_path = public
as $$
    insert into public.usage_counters (user_id, period, chats_used, scans_used, scans_today, today)
    values (p_user_id, p_period, 0, 1, 1, current_date)
    on conflict (user_id, period)
    do update set
        scans_used  = public.usage_counters.scans_used + 1,
        scans_today = case
            when public.usage_counters.today = current_date
            then public.usage_counters.scans_today + 1
            else 1
        end,
        today       = current_date,
        updated_at  = now()
    returning public.usage_counters.scans_used, public.usage_counters.scans_today;
$$;

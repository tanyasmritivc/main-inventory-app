-- Ensure usage_limits table exists with the correct schema
create table if not exists public.usage_limits (
    id         uuid         primary key default gen_random_uuid(),
    user_id    uuid         not null,
    feature    text         not null,
    count      integer      not null default 0,
    period     text         not null,
    updated_at timestamptz  not null default now()
);

-- Unique constraint required for the ON CONFLICT clause in increment_usage_count.
-- Wrapped in a DO block so it's idempotent on re-run.
do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'usage_limits_user_feature_period_key'
          and conrelid = 'public.usage_limits'::regclass
    ) then
        alter table public.usage_limits
            add constraint usage_limits_user_feature_period_key
            unique (user_id, feature, period);
    end if;
end;
$$;

-- Atomic upsert-increment: replaces the non-atomic read-modify-write in Python.
-- Inserts a new row (count=1) or increments an existing row in one SQL statement,
-- eliminating the race condition where two concurrent requests both read count=N
-- and both write count=N+1 instead of N+2.
create or replace function public.increment_usage_count(
    p_user_id uuid,
    p_feature text,
    p_period  text
)
returns integer
language sql
security definer
set search_path = public
as $$
    insert into public.usage_limits (user_id, feature, count, period, updated_at)
    values (p_user_id, p_feature, 1, p_period, now())
    on conflict (user_id, feature, period)
    do update set
        count      = public.usage_limits.count + 1,
        updated_at = now()
    returning count;
$$;

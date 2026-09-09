-- FindEZ public integration API.
-- API "spaces" are distinct items.location strings. This migration does not
-- create or depend on a spaces table for the public API contract.

create extension if not exists pgcrypto;

alter table public.items
    add column if not exists workspace_id uuid references public.teams(team_id) on delete set null,
    add column if not exists source_system text,
    add column if not exists external_id text;

-- Preserve existing team-linked inventory in the new API workspace boundary.
update public.items i
set workspace_id = ts.team_id
from public.team_spaces ts
where i.workspace_id is null
  and i.space_id = ts.space_id;

create unique index if not exists items_workspace_source_external_uidx
    on public.items (workspace_id, source_system, external_id);
create index if not exists items_workspace_created_idx
    on public.items (workspace_id, created_at desc);

create table if not exists public.api_keys (
    id           uuid primary key default gen_random_uuid(),
    workspace_id uuid,
    org_id       uuid not null,
    name         text not null check (length(btrim(name)) between 1 and 100),
    key_prefix   text not null,
    key_hash     text not null,
    scopes       text[] not null check (cardinality(scopes) > 0),
    created_by   uuid not null,
    created_at   timestamptz not null default now(),
    last_used_at timestamptz,
    expires_at   timestamptz,
    revoked_at   timestamptz,
    check (expires_at is null or expires_at > created_at)
);

create index if not exists api_keys_key_prefix_idx on public.api_keys (key_prefix);
create index if not exists api_keys_org_created_idx on public.api_keys (org_id, created_at desc);

alter table public.api_keys enable row level security;
revoke all on public.api_keys from anon, authenticated;

create table if not exists public.api_key_rate_windows (
    key_id        uuid not null references public.api_keys(id) on delete cascade,
    bucket        text not null,
    window_start  timestamptz not null,
    request_count integer not null default 0,
    primary key (key_id, bucket, window_start)
);

alter table public.api_key_rate_windows enable row level security;
revoke all on public.api_key_rate_windows from anon, authenticated;

create or replace function public.consume_api_key_rate_limit(
    p_key_id uuid,
    p_bucket text,
    p_limit integer
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count integer;
    v_window timestamptz := date_trunc('minute', now());
begin
    if p_limit < 1 then
        return false;
    end if;

    insert into public.api_key_rate_windows (key_id, bucket, window_start, request_count)
    values (p_key_id, p_bucket, v_window, 1)
    on conflict (key_id, bucket, window_start)
    do update set request_count = public.api_key_rate_windows.request_count + 1
    returning request_count into v_count;

    return v_count <= p_limit;
end;
$$;

revoke all on function public.consume_api_key_rate_limit(uuid, text, integer) from public;
grant execute on function public.consume_api_key_rate_limit(uuid, text, integer) to service_role;

create or replace function public.findez_api_claim(p_name text)
returns text
language sql
stable
as $$
    select nullif(
        coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) ->> p_name,
        ''
    );
$$;

create or replace function public.findez_api_has_scope(p_scope text)
returns boolean
language sql
stable
as $$
    select coalesce(
        (coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) -> 'api_scopes') ? p_scope,
        false
    );
$$;

create or replace function public.findez_api_can_access_workspace(p_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select
        public.findez_api_claim('api_key_id') is not null
        and (
            public.findez_api_claim('api_workspace_id') = p_workspace_id::text
            or (
                public.findez_api_claim('api_workspace_id') is null
                and exists (
                    select 1
                    from public.teams t
                    where t.team_id = p_workspace_id
                      and t.owner_user_id::text = public.findez_api_claim('api_org_id')
                )
            )
        );
$$;

revoke all on function public.findez_api_claim(text) from public;
revoke all on function public.findez_api_has_scope(text) from public;
revoke all on function public.findez_api_can_access_workspace(uuid) from public;
grant execute on function public.findez_api_claim(text) to authenticated;
grant execute on function public.findez_api_has_scope(text) to authenticated;
grant execute on function public.findez_api_can_access_workspace(uuid) to authenticated;

create policy items_api_key_select on public.items
for select to authenticated
using (
    workspace_id is not null
    and public.findez_api_can_access_workspace(workspace_id)
    and (
        public.findez_api_has_scope('items:read')
        or public.findez_api_has_scope('workspace:read')
        or public.findez_api_has_scope('org:read')
    )
);

create policy items_api_key_insert on public.items
for insert to authenticated
with check (
    workspace_id is not null
    and public.findez_api_can_access_workspace(workspace_id)
    and (
        public.findez_api_has_scope('items:write')
        or public.findez_api_has_scope('import:write')
        or public.findez_api_has_scope('org:write')
    )
);

create policy items_api_key_update on public.items
for update to authenticated
using (
    workspace_id is not null
    and public.findez_api_can_access_workspace(workspace_id)
    and (
        public.findez_api_has_scope('items:write')
        or public.findez_api_has_scope('import:write')
        or public.findez_api_has_scope('org:write')
    )
)
with check (
    workspace_id is not null
    and public.findez_api_can_access_workspace(workspace_id)
    and (
        public.findez_api_has_scope('items:write')
        or public.findez_api_has_scope('import:write')
        or public.findez_api_has_scope('org:write')
    )
);

create policy teams_api_key_select on public.teams
for select to authenticated
using (public.findez_api_can_access_workspace(team_id));

-- API requests use a non-user UUID as auth.uid(). Resolve the actual inventory
-- owner inside PostgreSQL so application code never supplies a tenant owner id.
create or replace function public.assign_api_item_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.findez_api_claim('api_key_id') is not null then
        select t.owner_user_id into new.user_id
        from public.teams t
        where t.team_id = new.workspace_id
          and public.findez_api_can_access_workspace(t.team_id);

        if new.user_id is null then
            raise insufficient_privilege using message = 'workspace access denied';
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists items_assign_api_owner on public.items;
create trigger items_assign_api_owner
before insert or update of workspace_id on public.items
for each row execute function public.assign_api_item_owner();

create or replace function public.api_distinct_locations(p_workspace_id uuid default null)
returns table(workspace_id uuid, location text, item_count bigint)
language sql
stable
security invoker
set search_path = public
as $$
    select i.workspace_id, i.location, count(*)
    from public.items i
    where i.workspace_id is not null
      and (p_workspace_id is null or i.workspace_id = p_workspace_id)
    group by i.workspace_id, i.location
    order by i.location;
$$;

create or replace function public.api_workspace_summary()
returns table(workspace_id uuid, name text, item_count bigint, space_count bigint)
language sql
stable
security invoker
set search_path = public
as $$
    select t.team_id, t.name, count(i.item_id), count(distinct i.location)
    from public.teams t
    left join public.items i on i.workspace_id = t.team_id
    group by t.team_id, t.name
    order by t.name;
$$;

grant select, insert, update on public.items to authenticated;
grant select on public.teams to authenticated;
grant execute on function public.api_distinct_locations(uuid) to authenticated;
grant execute on function public.api_workspace_summary() to authenticated;

comment on column public.items.workspace_id is
    'API workspace/team boundary. Physical spaces remain values in items.location.';
comment on table public.api_keys is
    'Hashed integration credentials. Raw keys are returned once and never stored.';

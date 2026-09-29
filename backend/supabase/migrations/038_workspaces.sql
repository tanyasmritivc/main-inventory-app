begin;

create table public.workspaces (
    workspace_id uuid primary key default gen_random_uuid(),
    name text not null check (length(btrim(name)) between 1 and 200),
    kind text not null check (kind in ('personal', 'shared')),
    owner_user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

create unique index workspaces_one_personal_per_owner
    on public.workspaces(owner_user_id) where kind = 'personal';

create table public.workspace_members (
    workspace_id uuid not null references public.workspaces(workspace_id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    role text not null check (role in ('owner', 'admin', 'editor', 'viewer')),
    joined_at timestamptz not null default now(),
    primary key (workspace_id, user_id)
);

create index workspace_members_user_idx on public.workspace_members(user_id);

create function public.findez_add_workspace_owner()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
    insert into public.workspace_members(workspace_id, user_id, role)
    values (new.workspace_id, new.owner_user_id, 'owner');
    return new;
end;
$$;

create trigger workspaces_add_owner after insert on public.workspaces
for each row execute function public.findez_add_workspace_owner();

alter table public.items drop constraint if exists items_workspace_id_fkey;
alter table public.items add constraint items_workspace_id_fkey
    foreign key (workspace_id) references public.workspaces(workspace_id) on delete cascade not valid;

alter table public.spaces add column workspace_id uuid references public.workspaces(workspace_id) on delete cascade;
alter table public.bins add column workspace_id uuid references public.workspaces(workspace_id) on delete cascade;
alter table public.documents add column workspace_id uuid references public.workspaces(workspace_id) on delete cascade;
alter table public.activity_log add column workspace_id uuid references public.workspaces(workspace_id) on delete cascade;
alter table public.project_kits add column workspace_id uuid references public.workspaces(workspace_id) on delete cascade;
alter table public.conversations add column workspace_id uuid references public.workspaces(workspace_id) on delete cascade;
alter table public.item_events add column workspace_id uuid references public.workspaces(workspace_id) on delete cascade;
alter table public.checkouts add column workspace_id uuid references public.workspaces(workspace_id) on delete cascade;
alter table public.item_relationships drop constraint if exists item_relationships_workspace_id_fkey;
alter table public.item_relationships add constraint item_relationships_workspace_id_fkey
    foreign key (workspace_id) references public.workspaces(workspace_id) on delete cascade not valid;

create index items_workspace_idx on public.items(workspace_id, created_at desc);
create index items_workspace_identity_idx on public.items(workspace_id, created_at desc)
    where identity_confirmed = false;
create index spaces_workspace_idx on public.spaces(workspace_id, name);
create index documents_workspace_idx on public.documents(workspace_id, created_at desc);
create index project_kits_workspace_idx on public.project_kits(workspace_id, created_at desc);
create index conversations_workspace_idx on public.conversations(workspace_id, updated_at desc);
create index checkouts_workspace_idx on public.checkouts(workspace_id, is_active, checked_out_at desc);

create table public.workspace_notification_reads (
    workspace_id uuid not null references public.workspaces(workspace_id) on delete cascade,
    activity_id uuid not null references public.activity_log(activity_id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    read_at timestamptz not null default now(),
    primary key (activity_id, user_id)
);
create index workspace_notification_reads_user_idx
    on public.workspace_notification_reads(user_id, workspace_id);
alter table public.workspace_notification_reads enable row level security;
revoke all on public.workspace_notification_reads from anon, authenticated;

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;

create function public.findez_is_workspace_member(p_workspace_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
    select exists (
        select 1 from public.workspace_members
        where workspace_id = p_workspace_id and user_id = p_user_id
    );
$$;

create function public.findez_can_write_workspace(p_workspace_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
    select exists (
        select 1 from public.workspace_members
        where workspace_id = p_workspace_id and user_id = p_user_id
          and role in ('owner', 'admin', 'editor')
    );
$$;

revoke all on function public.findez_is_workspace_member(uuid, uuid) from public;
revoke all on function public.findez_can_write_workspace(uuid, uuid) from public;
grant execute on function public.findez_is_workspace_member(uuid, uuid) to authenticated;
grant execute on function public.findez_can_write_workspace(uuid, uuid) to authenticated;

grant select on public.workspaces, public.workspace_members to authenticated;

create policy workspaces_member_read on public.workspaces for select
    using (public.findez_is_workspace_member(workspace_id, auth.uid()));
create policy workspace_members_member_read on public.workspace_members for select
    using (public.findez_is_workspace_member(workspace_id, auth.uid()));

-- Replace user-owned policies with one boundary for every workspace-owned row.
-- The API key policies on items use separate signed claims and remain in place.
do $$
declare
    old_policy record;
    target_table text;
    actor_column text;
begin
    for old_policy in
        select schemaname, tablename, policyname
        from pg_policies
        where schemaname = 'public'
          and tablename = any(array[
              'items', 'spaces', 'bins', 'documents', 'activity_log',
              'project_kits', 'conversations', 'item_events', 'checkouts'
          ])
          and not (tablename = 'items' and policyname like 'items_api_key_%')
    loop
        execute format('drop policy %I on %I.%I',
            old_policy.policyname, old_policy.schemaname, old_policy.tablename);
    end loop;

    foreach target_table in array array[
        'items', 'spaces', 'bins', 'documents', 'activity_log',
        'project_kits', 'conversations', 'item_events', 'checkouts'
    ]
    loop
        actor_column := case when target_table = 'project_kits'
            then 'created_by_user_id' else 'user_id' end;
        execute format('alter table public.%I enable row level security', target_table);
        execute format('grant select, insert, update, delete on public.%I to authenticated', target_table);
        execute format(
            'create policy %I on public.%I for select to authenticated '
            || 'using (public.findez_is_workspace_member(workspace_id, auth.uid()))',
            target_table || '_workspace_select', target_table);
        execute format(
            'create policy %I on public.%I for insert to authenticated '
            || 'with check (public.findez_can_write_workspace(workspace_id, auth.uid()) '
            || 'and %I = auth.uid())',
            target_table || '_workspace_insert', target_table, actor_column);
        execute format(
            'create policy %I on public.%I for update to authenticated '
            || 'using (public.findez_can_write_workspace(workspace_id, auth.uid())) '
            || 'with check (public.findez_can_write_workspace(workspace_id, auth.uid()))',
            target_table || '_workspace_update', target_table);
        execute format(
            'create policy %I on public.%I for delete to authenticated '
            || 'using (public.findez_can_write_workspace(workspace_id, auth.uid()))',
            target_table || '_workspace_delete', target_table);
    end loop;
end;
$$;

drop policy if exists item_relationships_read on public.item_relationships;
drop policy if exists item_relationships_insert on public.item_relationships;
drop policy if exists item_relationships_delete on public.item_relationships;

create policy item_relationships_workspace_read on public.item_relationships for select
    using (public.findez_is_workspace_member(workspace_id, auth.uid()));
create policy item_relationships_workspace_insert on public.item_relationships for insert
    with check (
        created_by = auth.uid()
        and public.findez_can_write_workspace(workspace_id, auth.uid())
        and exists (
            select 1 from public.items source
            where source.item_id = from_item
              and source.workspace_id = item_relationships.workspace_id
        )
        and (to_item is null or exists (
            select 1 from public.items target
            where target.item_id = to_item
              and target.workspace_id = item_relationships.workspace_id
        ))
        and (project_kit_id is null or exists (
            select 1 from public.project_kits kit
            where kit.id = project_kit_id
              and kit.workspace_id = item_relationships.workspace_id
        ))
    );
create policy item_relationships_workspace_delete on public.item_relationships for delete
    using (public.findez_can_write_workspace(workspace_id, auth.uid()));

grant select, insert, delete on public.item_relationships to authenticated;

create or replace function public.assign_api_item_owner()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
    v_space public.spaces%rowtype;
    v_matches integer;
begin
    if public.findez_api_claim('api_key_id') is not null then
        if not public.findez_api_can_access_workspace(new.workspace_id) then
            raise insufficient_privilege using message = 'workspace access denied';
        end if;
        select count(*) into v_matches
        from public.spaces s join public.team_spaces ts on ts.space_id = s.id
        where ts.team_id = new.workspace_id and s.name = new.location;
        if v_matches <> 1 then
            raise invalid_parameter_value using message = 'use an unambiguous linked space location';
        end if;
        select s.* into v_space
        from public.spaces s join public.team_spaces ts on ts.space_id = s.id
        where ts.team_id = new.workspace_id and s.name = new.location;
        new.user_id := v_space.user_id;
        new.space_id := v_space.id;
    elsif new.space_id is not null then
        select workspace_id into new.workspace_id from public.spaces where id = new.space_id;
    end if;
    return new;
end;
$$;

create or replace function public.sync_api_team_space()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
    if tg_op in ('DELETE', 'UPDATE') then
        update public.items i set workspace_id = (
            select s.workspace_id from public.spaces s where s.id = i.space_id
        ) where i.space_id = old.space_id;
    end if;
    if tg_op in ('INSERT', 'UPDATE') then
        update public.spaces set workspace_id = new.team_id where id = new.space_id;
        update public.items set workspace_id = new.team_id where space_id = new.space_id;
    end if;
    return null;
end;
$$;

commit;

begin;

alter table public.items
    add column container text,
    add column reorder_point integer check (reorder_point >= 0);

alter table public.item_events
    add column quantity_before integer,
    add column quantity_after integer,
    add column cause text;

create table public.item_relationships (
    id uuid primary key default gen_random_uuid(),
    workspace_id uuid references public.teams(team_id) on delete cascade,
    from_item uuid not null references public.items(item_id) on delete cascade,
    to_item uuid references public.items(item_id) on delete cascade,
    project_kit_id uuid references public.project_kits(id) on delete cascade,
    kind text not null check (kind in ('used_with', 'fits', 'needed_by', 'replaces')),
    created_by uuid not null references auth.users(id),
    created_at timestamptz not null default now(),
    check (from_item <> to_item),
    check ((kind = 'needed_by' and project_kit_id is not null and to_item is null)
        or (kind <> 'needed_by' and project_kit_id is null and to_item is not null))
);

create unique index item_relationships_items_unique
    on public.item_relationships (from_item, to_item, kind)
    where to_item is not null;
create unique index item_relationships_kit_unique
    on public.item_relationships (from_item, project_kit_id)
    where project_kit_id is not null;
create index item_relationships_to_item_idx on public.item_relationships (to_item);
create index item_relationships_workspace_idx on public.item_relationships (workspace_id);

alter table public.item_relationships enable row level security;

create function public.findez_can_edit_team(p_team_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
    select exists (select 1 from public.team_memberships m
        where m.team_id = p_team_id and m.user_id = p_user_id
          and m.role <> 'viewer');
$$;
revoke all on function public.findez_can_edit_team(uuid, uuid) from public;
grant execute on function public.findez_can_edit_team(uuid, uuid) to authenticated;

create policy item_relationships_read on public.item_relationships for select
using (
    exists (select 1 from public.items i
        where i.item_id = from_item and i.user_id = auth.uid())
    or public.findez_is_team_member(workspace_id, auth.uid())
);
create policy item_relationships_insert on public.item_relationships for insert
with check (
    created_by = auth.uid()
    and exists (select 1 from public.items source
        where source.item_id = from_item
          and source.workspace_id is not distinct from item_relationships.workspace_id
          and (to_item is null or exists (select 1 from public.items target
              where target.item_id = to_item
                and target.workspace_id is not distinct from source.workspace_id
                and (source.workspace_id is not null
                     or target.user_id = source.user_id))))
    and (exists (select 1 from public.items i
            where i.item_id = from_item and i.user_id = auth.uid())
        or public.findez_can_edit_team(workspace_id, auth.uid()))
);
create policy item_relationships_delete on public.item_relationships for delete
using (
    exists (select 1 from public.items i
        where i.item_id = from_item and i.user_id = auth.uid())
    or public.findez_can_edit_team(workspace_id, auth.uid())
);

commit;

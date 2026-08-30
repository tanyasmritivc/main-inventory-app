create table if not exists public.project_kit_reservations (
  id uuid primary key default gen_random_uuid(),
  kit_id uuid not null references public.project_kits(id) on delete cascade,
  kit_item_id uuid not null references public.project_kit_items(id) on delete cascade,
  inventory_item_id uuid not null references public.items(item_id) on delete cascade,
  quantity integer not null check (quantity > 0),
  created_by_user_id uuid not null,
  created_at timestamptz not null default now(),
  unique (kit_item_id, inventory_item_id)
);

create index if not exists project_kit_reservations_kit_idx
  on public.project_kit_reservations(kit_id);
create index if not exists project_kit_reservations_inventory_idx
  on public.project_kit_reservations(inventory_item_id);

alter table public.project_kit_reservations enable row level security;
revoke all on public.project_kit_reservations from anon, authenticated;

create or replace function public.replace_project_kit_reservations(
  p_kit_id uuid,
  p_actor_user_id uuid,
  p_allocations jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  allocation jsonb;
  inventory_id uuid;
  requested integer;
  stock integer;
  already_reserved integer;
begin
  if not exists (select 1 from project_kits where id = p_kit_id) then
    raise exception 'PROJECT_KIT_NOT_FOUND';
  end if;

  perform 1 from items
  where item_id in (
    select (entry->>'inventory_item_id')::uuid
    from jsonb_array_elements(p_allocations) entry
  )
  for update;

  for inventory_id in
    select distinct (entry->>'inventory_item_id')::uuid
    from jsonb_array_elements(p_allocations) entry
  loop
    select quantity into stock from items where item_id = inventory_id;
    if stock is null then raise exception 'INVENTORY_ITEM_NOT_FOUND'; end if;

    select coalesce(sum((entry->>'quantity')::integer), 0) into requested
    from jsonb_array_elements(p_allocations) entry
    where (entry->>'inventory_item_id')::uuid = inventory_id;

    select coalesce(sum(quantity), 0) into already_reserved
    from project_kit_reservations
    where inventory_item_id = inventory_id and kit_id <> p_kit_id;

    if requested < 0 or requested + already_reserved > stock then
      raise exception 'INSUFFICIENT_UNRESERVED_STOCK';
    end if;
  end loop;

  delete from project_kit_reservations where kit_id = p_kit_id;
  for allocation in select * from jsonb_array_elements(p_allocations)
  loop
    requested := (allocation->>'quantity')::integer;
    if requested > 0 then
      if not exists (
        select 1 from project_kit_items
        where id = (allocation->>'kit_item_id')::uuid and kit_id = p_kit_id
      ) then raise exception 'KIT_ITEM_MISMATCH'; end if;

      insert into project_kit_reservations(
        kit_id, kit_item_id, inventory_item_id, quantity, created_by_user_id
      ) values (
        p_kit_id,
        (allocation->>'kit_item_id')::uuid,
        (allocation->>'inventory_item_id')::uuid,
        requested,
        p_actor_user_id
      );
    end if;
  end loop;
end;
$$;

revoke all on function public.replace_project_kit_reservations(uuid, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.replace_project_kit_reservations(uuid, uuid, jsonb)
  to service_role;

notify pgrst, 'reload schema';

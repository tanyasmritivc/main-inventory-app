-- Durable review queue for uncertain photo captures.
-- Review records are deliberately separate from inventory: an uncertain guess
-- does not become an item until its owner confirms the required fields.
begin;

create table if not exists public.capture_reviews (
  review_id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  source_key text not null,
  source_kind text not null default 'photo_scan'
    check (source_kind in ('photo_scan', 'barcode', 'spreadsheet', 'manual')),
  status text not null default 'pending'
    check (status in ('pending', 'resolved', 'dismissed')),
  name text not null,
  category text not null,
  subcategory text,
  quantity integer not null default 1 check (quantity between 0 and 100000),
  brand text,
  part_number text,
  barcode text,
  tags text[],
  confidence double precision check (confidence is null or confidence between 0 and 1),
  image_url text,
  source_frame_url text,
  notes text,
  location text,
  catalog_match jsonb,
  scan_evidence jsonb not null default '{}'::jsonb,
  resolved_item_id uuid references public.items(item_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  dismissed_at timestamptz,
  unique (user_id, source_key)
);

create index if not exists idx_capture_reviews_user_status_created
  on public.capture_reviews (user_id, status, created_at desc);

alter table public.capture_reviews enable row level security;

drop policy if exists capture_reviews_select_own on public.capture_reviews;
create policy capture_reviews_select_own on public.capture_reviews
  for select to authenticated
  using (auth.uid() = user_id);

-- Clients may only read their own queue. All mutations go through the
-- authenticated API, which validates fields and uses the service role.
revoke all on table public.capture_reviews from public, anon, authenticated;
grant select on table public.capture_reviews to authenticated;
grant all on table public.capture_reviews to service_role;

create or replace function public.resolve_capture_review(
  p_review_id uuid,
  p_user_id uuid,
  p_item jsonb,
  p_space_id uuid default null,
  p_catalog_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_review public.capture_reviews%rowtype;
  v_item public.items%rowtype;
begin
  select * into v_review
  from public.capture_reviews
  where review_id = p_review_id and user_id = p_user_id
  for update;

  if not found then
    raise no_data_found using message = 'review item not found';
  end if;

  if v_review.status = 'resolved' and v_review.resolved_item_id is not null then
    select * into v_item from public.items
    where item_id = v_review.resolved_item_id and user_id = p_user_id;
    if found then
      return to_jsonb(v_item);
    end if;
  end if;

  if v_review.status <> 'pending' then
    raise check_violation using message = 'review item is no longer pending';
  end if;

  if nullif(btrim(p_item->>'name'), '') is null
     or length(p_item->>'name') > 200
     or nullif(btrim(p_item->>'category'), '') is null
     or length(p_item->>'category') > 100
     or nullif(btrim(p_item->>'location'), '') is null
     or length(p_item->>'location') > 200
     or coalesce(p_item->>'quantity', '') !~ '^[0-9]{1,6}$'
     or (p_item->>'quantity')::integer > 100000 then
    raise invalid_parameter_value using message = 'invalid reviewed item';
  end if;

  insert into public.items (
    user_id, name, category, subcategory, quantity, location, space_id,
    image_url, barcode, notes, brand, part_number, tags, confidence, catalog_id
  ) values (
    p_user_id,
    btrim(p_item->>'name'),
    btrim(p_item->>'category'),
    nullif(btrim(p_item->>'subcategory'), ''),
    (p_item->>'quantity')::integer,
    btrim(p_item->>'location'),
    p_space_id,
    nullif(btrim(p_item->>'image_url'), ''),
    nullif(btrim(p_item->>'barcode'), ''),
    nullif(btrim(p_item->>'notes'), ''),
    nullif(btrim(p_item->>'brand'), ''),
    nullif(btrim(p_item->>'part_number'), ''),
    case when jsonb_typeof(p_item->'tags') = 'array'
      then array(select jsonb_array_elements_text(p_item->'tags'))
      else null end,
    case when nullif(p_item->>'confidence', '') is null then null
      else greatest(0, least(1, (p_item->>'confidence')::double precision)) end,
    p_catalog_id
  ) returning * into v_item;

  update public.capture_reviews
  set status = 'resolved', resolved_item_id = v_item.item_id,
      resolved_at = now(), updated_at = now()
  where review_id = p_review_id and user_id = p_user_id;

  return to_jsonb(v_item);
end;
$$;

revoke all on function public.resolve_capture_review(uuid, uuid, jsonb, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.resolve_capture_review(uuid, uuid, jsonb, uuid, uuid)
  to service_role;

notify pgrst, 'reload schema';
commit;

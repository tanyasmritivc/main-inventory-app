create extension if not exists "pgcrypto";

create table if not exists public.items (
  item_id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  category text not null,
  quantity integer not null,
  location text not null,
  image_url text,
  barcode text,
  purchase_source text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.items enable row level security;

create policy "items_select_own" on public.items
  for select
  using (auth.uid() = user_id);

create policy "items_insert_own" on public.items
  for insert
  with check (auth.uid() = user_id);

create policy "items_delete_own" on public.items
  for delete
  using (auth.uid() = user_id);

create index if not exists idx_items_user_created_at on public.items (user_id, created_at desc);
create index if not exists idx_items_user_name on public.items (user_id, name);

create table if not exists public.project_kits (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  created_by_user_id uuid not null,
  share_id uuid,
  name text not null check (char_length(name) between 1 and 120),
  location text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.project_kit_items (
  id uuid primary key default gen_random_uuid(),
  kit_id uuid not null references public.project_kits(id) on delete cascade,
  name text not null,
  part_number text,
  brand text,
  required_quantity integer not null check (required_quantity > 0),
  created_at timestamptz not null default now()
);

create index if not exists project_kits_owner_location_idx
  on public.project_kits(owner_user_id, location);
create index if not exists project_kits_share_idx on public.project_kits(share_id);
create index if not exists project_kit_items_kit_idx on public.project_kit_items(kit_id);

alter table public.project_kits enable row level security;
alter table public.project_kit_items enable row level security;

-- Application access is exclusively through FastAPI's service-role client.
revoke all on public.project_kits from anon, authenticated;
revoke all on public.project_kit_items from anon, authenticated;

notify pgrst, 'reload schema';

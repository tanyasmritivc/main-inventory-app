create table if not exists public.push_devices (
  device_token text primary key,
  user_id uuid not null,
  platform text not null default 'ios' check (platform = 'ios'),
  environment text not null check (environment in ('sandbox', 'production')),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_devices_user_id_idx
  on public.push_devices (user_id) where enabled;

alter table public.push_devices enable row level security;
revoke all on public.push_devices from anon, authenticated;

notify pgrst, 'reload schema';

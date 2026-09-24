create table if not exists public.email_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  idempotency_key text not null,
  template text not null,
  recipient text not null,
  status text not null check (status in ('pending', 'sent', 'failed')),
  message_id text,
  error_code text,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (user_id, idempotency_key)
);
create index if not exists email_deliveries_user_created_idx
  on public.email_deliveries (user_id, created_at desc);
alter table public.email_deliveries enable row level security;

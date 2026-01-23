create table if not exists public.documents (
  document_id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  filename text not null,
  mime_type text,
  storage_path text not null,
  url text,
  created_at timestamptz not null default now()
);

alter table public.documents enable row level security;

create policy "documents_select_own" on public.documents
  for select
  using (auth.uid() = user_id);

create policy "documents_insert_own" on public.documents
  for insert
  with check (auth.uid() = user_id);

create index if not exists idx_documents_user_created_at on public.documents (user_id, created_at desc);

create table if not exists public.activity_log (
  activity_id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.activity_log enable row level security;

create policy "activity_select_own" on public.activity_log
  for select
  using (auth.uid() = user_id);

create policy "activity_insert_own" on public.activity_log
  for insert
  with check (auth.uid() = user_id);

create index if not exists idx_activity_user_created_at on public.activity_log (user_id, created_at desc);

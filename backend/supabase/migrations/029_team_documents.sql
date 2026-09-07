create table if not exists public.team_documents (
  team_document_id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(team_id) on delete cascade,
  uploaded_by uuid not null,
  filename text not null,
  mime_type text,
  size_bytes bigint not null default 0,
  storage_path text not null unique,
  created_at timestamptz not null default now()
);

create index if not exists idx_team_documents_team_created_at
  on public.team_documents (team_id, created_at desc);

alter table public.team_documents enable row level security;

drop policy if exists "team_documents_select_member" on public.team_documents;
create policy "team_documents_select_member" on public.team_documents
  for select using (
    exists (
      select 1
      from public.team_memberships membership
      where membership.team_id = team_documents.team_id
        and membership.user_id = auth.uid()
    )
  );

drop policy if exists "team_documents_insert_editor" on public.team_documents;
create policy "team_documents_insert_editor" on public.team_documents
  for insert with check (
    uploaded_by = auth.uid()
    and exists (
      select 1
      from public.team_memberships membership
      where membership.team_id = team_documents.team_id
        and membership.user_id = auth.uid()
        and membership.role <> 'viewer'
    )
  );

drop policy if exists "team_documents_delete_allowed" on public.team_documents;
create policy "team_documents_delete_allowed" on public.team_documents
  for delete using (
    uploaded_by = auth.uid()
    or exists (
      select 1
      from public.team_memberships membership
      where membership.team_id = team_documents.team_id
        and membership.user_id = auth.uid()
        and membership.role in ('owner', 'mentor')
    )
  );

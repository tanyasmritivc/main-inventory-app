alter table if exists public.documents
  add column if not exists display_name text;

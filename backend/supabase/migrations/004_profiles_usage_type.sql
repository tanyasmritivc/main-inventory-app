alter table if exists public.profiles
add column if not exists usage_type text;

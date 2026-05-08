-- Add actor_name column to activity_log table
alter table if not exists public.activity_log
  add column if not exists actor_name text;

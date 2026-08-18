-- 013_bin_locations.sql
-- Adds precise, shareable physical locations within a space. Existing item
-- location text and space_id remain unchanged, so this is safe to roll out
-- before clients begin assigning bins.

create table public.bins (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    space_id    uuid not null references public.spaces(id) on delete cascade,
    name        text not null check (length(btrim(name)) > 0),
    created_at  timestamptz not null default now()
);

create unique index bins_user_space_name_ci_idx
    on public.bins (user_id, space_id, lower(btrim(name)));
create index bins_user_space_idx on public.bins (user_id, space_id);

alter table public.items
    add column bin_id uuid references public.bins(id) on delete set null;
create index items_bin_id_idx on public.items (bin_id);

alter table public.bins enable row level security;

create policy bins_select_own on public.bins
    for select using (auth.uid() = user_id);
create policy bins_insert_own on public.bins
    for insert with check (auth.uid() = user_id);
create policy bins_update_own on public.bins
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy bins_delete_own on public.bins
    for delete using (auth.uid() = user_id);

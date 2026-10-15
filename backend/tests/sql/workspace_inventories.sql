-- Complete the minimal disposable API fixture; never run against production.
select set_config('request.jwt.claims', '{}', false);
insert into auth.users(id) select distinct user_id from public.spaces on conflict do nothing;
alter table public.team_memberships add column if not exists role text not null default 'member';
create table if not exists public.documents (
  document_id uuid primary key default gen_random_uuid(), user_id uuid not null,
  item_id uuid references public.items(item_id), filename text, storage_path text
);
create table if not exists public.bins (
  id uuid primary key default gen_random_uuid(), user_id uuid not null,
  space_id uuid not null references public.spaces(id), name text
);
create table if not exists public.project_kits (
  id uuid primary key default gen_random_uuid(), owner_user_id uuid not null,
  created_by_user_id uuid not null, name text, location text, share_id uuid,
  created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists public.project_kit_items (
  id uuid primary key default gen_random_uuid(), kit_id uuid references public.project_kits(id), name text
);
create table if not exists public.project_kit_reservations (
  id uuid primary key default gen_random_uuid(), kit_id uuid references public.project_kits(id),
  kit_item_id uuid references public.project_kit_items(id), inventory_item_id uuid references public.items(item_id)
);

create temporary table inventory_before as select item_id,user_id,name,quantity,space_id from public.items;
\ir ../../supabase/migrations/043_workspace_inventories.sql
select pg_temp.check(not exists (
  select * from inventory_before except select item_id,user_id,name,quantity,space_id from public.items
), 'inventory grouping retains every original item and owner');
select pg_temp.check((select count(*) = 0 from public.items where inventory_id is null), 'legacy items receive a default inventory');
select pg_temp.check((select count(*) = 0 from public.items i join public.spaces s on s.id=i.space_id where i.inventory_id<>s.inventory_id), 'linked Team Spaces and items receive the same boundary');

begin;
insert into public.app_inventories(inventory_id,owner_user_id,created_by_user_id,name) values
('a1000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Inventory A'),
('a1000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Inventory B');
insert into public.spaces(id,user_id,name,inventory_id) values
('a2000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Drawer','a1000000-0000-0000-0000-000000000001'),
('a2000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','Drawer','a1000000-0000-0000-0000-000000000002');
select pg_temp.check((select count(*) = 2 from public.spaces where name='Drawer'), 'inventories can use the same physical location label');
do $$ begin
  begin
    insert into public.items(user_id,name,category,quantity,location,space_id,inventory_id)
    values('20000000-0000-0000-0000-000000000001','Wrong boundary','Tools',1,'Drawer',
      'a2000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001');
    raise exception 'cross-inventory location accepted';
  exception when check_violation then raise notice 'PASS: cross-inventory parents rejected'; end;
end $$;
insert into public.items(user_id,name,category,quantity,location,space_id,inventory_id)
select '20000000-0000-0000-0000-000000000001', 'Part ' || n, 'Hardware', 1, 'Drawer',
  'a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001'
from generate_series(1,1105) n;
select pg_temp.check((select item_count=1105 from public.app_inventory_summaries
  where inventory_id='a1000000-0000-0000-0000-000000000001'), 'inventory counts exceed the REST row limit correctly');
insert into public.capture_reviews(review_id,user_id,source_key,name,category,quantity,location,inventory_id) values
('a3000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','inventory-test','Loose part','Hardware',1,'Unsorted','a1000000-0000-0000-0000-000000000002');
select public.resolve_capture_review('a3000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',
  '{"name":"Loose part","category":"Hardware","quantity":1,"location":"Unsorted"}',null,null);
select pg_temp.check((select inventory_id='a1000000-0000-0000-0000-000000000002' from public.items where name='Loose part'), 'Unsorted review resolution retains its inventory');
set local role authenticated;
do $$ begin
  begin perform * from public.app_inventory_summaries;
    raise exception 'directory bypassed server authorization';
  exception when insufficient_privilege then raise notice 'PASS: inventory directory is server-only'; end;
end $$;
reset role;
rollback;

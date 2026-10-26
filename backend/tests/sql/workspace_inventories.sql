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
  kit_item_id uuid references public.project_kit_items(id), inventory_item_id uuid references public.items(item_id),quantity integer,created_by_user_id uuid
);

-- Historical owner IDs can outlive an account in the deployed schema.
insert into public.teams(team_id,name,owner_user_id) values
('a9000000-0000-0000-0000-000000000001','Legacy workspace','a9000000-0000-0000-0000-000000000002');
insert into public.items(user_id,name,category,quantity,location) values
('a9000000-0000-0000-0000-000000000002','Retained legacy part','Hardware',1,'Unsorted');
create temporary table inventory_before as select item_id,user_id,name,quantity,space_id from public.items;
create table if not exists public.team_shares (
  share_id uuid primary key default gen_random_uuid(),owner_user_id uuid not null,share_name text
);
\ir ../../supabase/migrations/043_workspace_inventories.sql
select pg_temp.check(not exists (
  select * from inventory_before except select item_id,user_id,name,quantity,space_id from public.items
), 'inventory grouping retains every original item and owner');
select pg_temp.check((select count(*) = 0 from public.items where inventory_id is null), 'legacy items receive a default inventory');
select pg_temp.check((select inv.owner_user_id=i.user_id and inv.created_by_user_id is null from public.items i join public.app_inventories inv using(inventory_id) where i.name='Retained legacy part'), 'removed-account records retain their original owner without impersonation');
do $$ begin
  begin
    insert into public.app_inventories(owner_user_id,name) values('a9000000-0000-0000-0000-000000000003','Invalid new owner');
    raise exception 'new unknown owner accepted';
  exception when foreign_key_violation then raise notice 'PASS: new inventory owners must have real accounts'; end;
end $$;
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
select set_config('request.jwt.claims','{}',false);

-- Compatibility: a legacy API key still writes into its actual Team Space.
update public.teams set owner_user_id='20000000-0000-0000-0000-000000000001' where team_id='10000000-0000-0000-0000-000000000001';
select pg_temp.check((select owner_user_id='20000000-0000-0000-0000-000000000001' from public.app_inventories where team_id='10000000-0000-0000-0000-000000000001'),'Team ownership updates the inventory authority');
set local role authenticated;
select pg_temp.use_key('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','["items:write","import:write"]');
insert into public.items(user_id,workspace_id,name,category,quantity,location,space_id)
values('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Post-migration API part','Hardware',3,'Member Shelf','30000000-0000-0000-0000-000000000003');
reset role;
select set_config('request.jwt.claims','{}',false);
select pg_temp.check((select i.inventory_id=s.inventory_id from public.items i join public.spaces s on s.id=i.space_id where i.name='Post-migration API part'),'legacy integration writes inherit the physical inventory');

insert into public.app_inventories(inventory_id,owner_user_id,created_by_user_id,team_id,name) values
('a1000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','Team project');
insert into public.spaces(id,user_id,name,inventory_id) values
('a2000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','Project shelf','a1000000-0000-0000-0000-000000000003');
select pg_temp.check((select inventory_id='a1000000-0000-0000-0000-000000000003' from public.spaces where id='a2000000-0000-0000-0000-000000000003'),'new Team location keeps the selected project instead of defaulting');
select pg_temp.check((select count(*)=1 from public.team_spaces where space_id='a2000000-0000-0000-0000-000000000003'),'new Team locations remain visible to the legacy Team API');
insert into public.items(item_id,user_id,name,category,quantity,location,space_id,inventory_id,image_url) values
('a4000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Kept record','Tools',6,'Project shelf','a2000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000003','https://images.test/kept.jpg');
insert into public.documents(user_id,item_id,filename,storage_path,inventory_id) values
('20000000-0000-0000-0000-000000000003','a4000000-0000-0000-0000-000000000001','Private manual','member/docs/kept.pdf','a1000000-0000-0000-0000-000000000003');
insert into public.project_kits(id,owner_user_id,created_by_user_id,name,location,inventory_id) values
('a6000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Project kit','Project shelf','a1000000-0000-0000-0000-000000000003');
insert into public.project_kit_items(id,kit_id,name,inventory_id) values
('a7000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001','Kept record','a1000000-0000-0000-0000-000000000003');
select public.replace_project_kit_reservations('a6000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000003',
 '[{"kit_item_id":"a7000000-0000-0000-0000-000000000001","inventory_item_id":"a4000000-0000-0000-0000-000000000001","quantity":2}]');
select pg_temp.check((select quantity=2 from public.project_kit_reservations where kit_id='a6000000-0000-0000-0000-000000000001'),'project reservations remain functional after adding inventory boundaries');
select public.findez_move_inventory_space('a2000000-0000-0000-0000-000000000003',public.findez_default_inventory('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'));
select pg_temp.check((select i.inventory_id=s.inventory_id and i.quantity=6 and i.image_url='https://images.test/kept.jpg' and i.user_id='20000000-0000-0000-0000-000000000001' from public.items i join public.spaces s on s.id=i.space_id where i.item_id='a4000000-0000-0000-0000-000000000001'),'moving a Space retains its item ID, owner, quantity and image');
select pg_temp.check((select r.inventory_id=k.inventory_id and k.inventory_id=i.inventory_id from public.project_kit_reservations r join public.project_kits k on k.id=r.kit_id join public.items i on i.item_id=r.inventory_item_id where r.kit_id='a6000000-0000-0000-0000-000000000001'),'moving a location retains its project kit allocations');
select pg_temp.check((select d.inventory_id=i.inventory_id and d.inventory_visibility='personal' from public.documents d join public.items i on i.item_id=d.item_id where d.storage_path='member/docs/kept.pdf'),'moving linked documents retains privacy and source path');
delete from public.team_spaces where space_id='a2000000-0000-0000-0000-000000000003';
select pg_temp.check((select s.inventory_id=public.findez_default_inventory(s.user_id) from public.spaces s where s.id='a2000000-0000-0000-0000-000000000003'),'removing a Team Space returns its records to the physical owner');

insert into public.conversations(id,user_id,title,inventory_id) values
('a5000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000003','Private project question',public.findez_default_inventory('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'));
insert into public.messages(conversation_id,role,content) values('a5000000-0000-0000-0000-000000000001','assistant','Retained private answer');
select public.findez_delete_inventory_team('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
select pg_temp.check((select inv.owner_user_id=c.user_id and inv.team_id is null from public.conversations c join public.app_inventories inv using(inventory_id) where c.id='a5000000-0000-0000-0000-000000000001'),'deleting collaboration retains each member private history');
select pg_temp.check((select m.inventory_id=c.inventory_id from public.messages m join public.conversations c on c.id=m.conversation_id where c.id='a5000000-0000-0000-0000-000000000001'),'retained conversation messages keep the same boundary');
select pg_temp.check((select count(*)=1 from public.items where item_id='a4000000-0000-0000-0000-000000000001'),'deleting a Team does not delete physical inventory');

-- Source invitations are stable IDs, even when inventories reuse a label.
insert into public.team_shares(owner_user_id,share_name,space_id,inventory_id) values
('20000000-0000-0000-0000-000000000001','Drawer','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001');
select pg_temp.check((select inventory_id='a1000000-0000-0000-0000-000000000001' from public.team_shares where space_id='a2000000-0000-0000-0000-000000000001'),'a shared location stays bound to one inventory');
do $$ begin
  begin
    insert into public.team_shares(owner_user_id,share_name) values('20000000-0000-0000-0000-000000000001','Drawer');
    raise exception 'ambiguous invitation accepted';
  exception when check_violation then raise notice 'PASS: ambiguous legacy invitation rejected'; end;
end $$;
rollback;

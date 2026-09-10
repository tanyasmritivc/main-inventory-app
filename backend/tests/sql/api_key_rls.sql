-- Run ONLY in an empty, disposable database: psql -v ON_ERROR_STOP=1 -f this-file.
\set ON_ERROR_STOP on
create role anon;
create role authenticated;
create role service_role bypassrls;
create schema auth;
grant usage on schema auth to authenticated;
create function auth.uid() returns uuid language sql stable as $$
    select (nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'sub')::uuid;
$$;
create table public.teams (team_id uuid primary key, name text, owner_user_id uuid);
create table public.spaces (id uuid primary key, user_id uuid not null, name text not null, created_at timestamptz default now());
create table public.team_memberships (team_id uuid, user_id uuid);
create table public.team_spaces (
    team_space_id uuid primary key default gen_random_uuid(), team_id uuid references public.teams on delete cascade,
    space_id uuid unique references public.spaces on delete cascade, linked_by uuid
);
\ir ../../supabase/migrations/001_init.sql
alter table public.items add column brand text, add column part_number text,
    add column space_id uuid references public.spaces on delete cascade;
create policy items_update_own on public.items for update using(auth.uid()=user_id) with check(auth.uid()=user_id);
alter table public.teams enable row level security;
alter table public.team_memberships enable row level security;
\ir ../../supabase/migrations/032_api_key_authentication.sql
\ir ../../supabase/migrations/033_fix_team_membership_rls_recursion.sql
\ir ../../supabase/migrations/034_api_inventory_queries.sql

insert into public.teams values
('10000000-0000-0000-0000-000000000001','Team A','20000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000002','Team B','20000000-0000-0000-0000-000000000002'),
('10000000-0000-0000-0000-000000000003','Second A','20000000-0000-0000-0000-000000000001');
insert into public.spaces(id,user_id,name) values
('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Shelf A'),
('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Shelf B'),
('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','Member Shelf');
insert into public.team_spaces(team_id,space_id) values
('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002'),
('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000003');
insert into public.items(item_id,user_id,space_id,name,category,quantity,location,part_number) values
('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Motor','Hardware',4,'Shelf A','5202'),
('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','Private motor','Hardware',100,'Shelf B','5202');
insert into public.api_keys(id,workspace_id,org_id,name,key_prefix,key_hash,scopes,created_by) values
('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Read','test','hash',array['items:read'],'20000000-0000-0000-0000-000000000001'),
('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Write','test','hash',array['items:write','import:write'],'20000000-0000-0000-0000-000000000001'),
('50000000-0000-0000-0000-000000000003',null,'20000000-0000-0000-0000-000000000001','Org','test','hash',array['org:read'],'20000000-0000-0000-0000-000000000001');

create function pg_temp.use_key(p_id text,p_workspace text,p_scopes jsonb) returns void language sql as $$
select set_config('request.jwt.claims',jsonb_build_object('sub',p_id,'api_key_id',p_id,'api_workspace_id',p_workspace,
    'api_org_id','20000000-0000-0000-0000-000000000001','api_scopes',p_scopes)::text,false);
$$;
create function pg_temp.check(p_condition boolean,p_name text) returns void language plpgsql as $$
begin if p_condition is distinct from true then raise exception 'FAIL: %',p_name; end if; raise notice 'PASS: %',p_name; end;
$$;

set role authenticated;
select pg_temp.use_key('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','["items:read"]');
select pg_temp.check((select count(*)=1 from public.items),'cross-tenant isolation and new app item visibility');
select pg_temp.check((public.api_query_items(null,'[{"field":"part_number","op":"eq","value":"5202"}]','sum_quantity')->>'value')::int=4,'aggregate excludes other tenant');
select pg_temp.check((public.api_query_items(null,'[]','count')->>'value')::int=1,'count aggregation');
select pg_temp.check(jsonb_array_length(public.api_query_items(null,'[]',null,2,1)->'items')=0,'pagination');
select pg_temp.check((public.api_query_items(null,jsonb_build_array(jsonb_build_object('field','name','op','eq','value',$attack$'; DROP TABLE items; --$attack$)),'count')->>'value')::int=0,'injection is a bound literal');
do $$ begin
    begin perform public.api_query_items(null,'[{"field":"user_id","op":"eq","value":"x"}]','count'); raise exception 'unsafe field accepted';
    exception when invalid_parameter_value then raise notice 'PASS: rejects private field'; end;
    begin insert into public.items(user_id,workspace_id,name,category,quantity,location) values
    ('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Forbidden','Hardware',1,'Shelf A');
    raise exception 'read key wrote inventory'; exception when insufficient_privilege then raise notice 'PASS: read-only rejects writes'; end;
end $$;

select pg_temp.use_key('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','["items:write","import:write"]');
update public.items set quantity=6 where item_id='40000000-0000-0000-0000-000000000001';
select pg_temp.check((select quantity=6 from public.items where item_id='40000000-0000-0000-0000-000000000001'),'write-only update works');
insert into public.items(user_id,workspace_id,name,category,quantity,location,source_system,external_id) values
('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Imported','Hardware',2,'Member Shelf','erp','1');
insert into public.items(user_id,workspace_id,name,category,quantity,location,source_system,external_id) values
('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Imported','Hardware',9,'Member Shelf','erp','1')
on conflict(workspace_id,source_system,external_id) do update set quantity=excluded.quantity, location=excluded.location;
select pg_temp.check((select count(*)=1 and max(quantity)=9 from public.items where external_id='1'),'idempotent bulk upsert');
select pg_temp.check((select user_id='20000000-0000-0000-0000-000000000003' and space_id='30000000-0000-0000-0000-000000000003' from public.items where external_id='1'),'API creates in the actual Space owner inventory');
do $$ begin
    begin perform public.api_query_items(null,'[]','count'); raise exception 'write key queried items';
    exception when insufficient_privilege then raise notice 'PASS: write-only cannot use query RPC'; end;
    begin insert into public.items(user_id,workspace_id,name,category,quantity,location) values
    ('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Forbidden','Hardware',1,'Shelf B');
    raise exception 'cross-tenant write accepted'; exception when insufficient_privilege then raise notice 'PASS: cross-tenant write denied'; end;
    begin insert into public.items(user_id,workspace_id,name,category,quantity,location) values
    ('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Forbidden','Hardware',1,'Nonexistent');
    raise exception 'orphan write accepted'; exception when invalid_parameter_value then raise notice 'PASS: unknown location rejected'; end;
end $$;

-- Detach and reattach an existing Space through normal service-side writes.
reset role;
select set_config('request.jwt.claims','{}',false);
delete from public.team_spaces where space_id='30000000-0000-0000-0000-000000000001';
select pg_temp.check((select workspace_id is null and quantity=6 from public.items where item_id='40000000-0000-0000-0000-000000000001'),'detach preserves items and clears API access');
insert into public.team_spaces(team_id,space_id) values('10000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000001');
set role authenticated;
select pg_temp.use_key('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','["items:read"]');
select pg_temp.check((select count(*)=0 from public.items where item_id='40000000-0000-0000-0000-000000000001'),'old workspace key cannot read moved Space');
select pg_temp.use_key('50000000-0000-0000-0000-000000000003',null,'["org:read"]');
select pg_temp.check((select count(*)=2 from public.items),'organization key reads both owned teams only');

reset role;
select set_config('request.jwt.claims','{}',false);
update public.api_keys set revoked_at=now() where id='50000000-0000-0000-0000-000000000003';
set role authenticated;
select pg_temp.use_key('50000000-0000-0000-0000-000000000003',null,'["org:read"]');
select pg_temp.check((select count(*)=0 from public.items),'revocation applies even to existing RLS tokens');
reset role;
select set_config('request.jwt.claims','{}',false);
update public.teams set owner_user_id='20000000-0000-0000-0000-000000000002' where team_id='10000000-0000-0000-0000-000000000001';
set role authenticated;
select pg_temp.use_key('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','["items:read"]');
select pg_temp.check((select count(*)=0 from public.items),'ownership change removes old owner key access');
reset role;
\echo API database integration checks passed.

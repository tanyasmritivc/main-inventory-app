-- Disposable fixture only. No production accounts or resources.
select set_config('request.jwt.claims','{}',false);
create temporary table access_before as select to_jsonb(i.*) AS value from public.items i;
\ir ../../supabase/migrations/044_organization_inventory_access.sql
select pg_temp.check(not exists(select value from access_before except select to_jsonb(i.*) from public.items i),'access migration preserves every item value');
-- Match the relevant production defaults/columns omitted by the minimal fixture.
alter table public.teams alter column team_id set default gen_random_uuid();
alter table public.teams add column join_code char(6) unique;
alter table public.team_memberships add constraint access_fixture_members_unique unique(team_id,user_id);
alter table public.spaces alter column id set default gen_random_uuid();
alter table auth.users add column if not exists email text;
insert into auth.users(id,email)
 select ('b0000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'fixture'||n||'@example.invalid' from generate_series(1,38) n;
create temporary table access_demo(key text primary key,id uuid);
do $$
declare owner_id uuid:='b0000000-0000-0000-0000-000000000001';
 student uuid:='b0000000-0000-0000-0000-000000000014';
 org uuid; ws uuid; tools uuid:=gen_random_uuid(); components uuid:=gen_random_uuid();
 acme uuid; project uuid; equipment uuid:=gen_random_uuid(); internal uuid:=gen_random_uuid();
 loc uuid; cabinet uuid; drawer uuid; space_a uuid; space_b uuid; i integer; person uuid;
begin
 acme:=(public.findez_manage_collaboration(owner_id,'organization_create','{"name":"Acme Company"}')->>'organization_id')::uuid;
 for i in 2..12 loop
  person:=('b0000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid;
  perform public.findez_manage_collaboration(owner_id,'organization_member',jsonb_build_object('organization_id',acme,'user_id',person,'role','member'));
 end loop;
 project:=(public.findez_manage_collaboration(owner_id,'workspace_create',jsonb_build_object('organization_id',acme,'name','2026 OCTOBER CLIENT'))->>'team_id')::uuid;
 for i in 2..6 loop
  person:=('b0000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid;
  perform public.findez_manage_collaboration(owner_id,'workspace_member',jsonb_build_object('team_id',project,'user_id',person,'role','viewer'));
 end loop;
 insert into public.app_inventories(inventory_id,owner_user_id,team_id,name,access_mode) values
 (equipment,owner_id,project,'Equipment DB','workspace'),(internal,owner_id,project,'Internal costs','restricted');
 perform pg_temp.check((select count(*)=12 from public.app_organization_members where organization_id=acme),'Acme has 12 organization members');
 perform pg_temp.check((select count(*)=6 from public.team_memberships where team_id=project),'only six employees assigned to client project');
 perform pg_temp.check(public.findez_inventory_role(equipment,'b0000000-0000-0000-0000-000000000007') is null,'organization membership does not grant project access');
 perform pg_temp.check(public.findez_inventory_role(equipment,'b0000000-0000-0000-0000-000000000006')='viewer','client reviewer can view equipment');
 perform pg_temp.check(public.findez_inventory_role(internal,'b0000000-0000-0000-0000-000000000006') is null,'client reviewer cannot see internal inventory');
 -- An organization admin with no assignment still cannot see project data.
 perform public.findez_manage_collaboration(owner_id,'organization_member',jsonb_build_object('organization_id',acme,'user_id','b0000000-0000-0000-0000-000000000007','role','admin'));
 perform pg_temp.check(public.findez_inventory_role(equipment,'b0000000-0000-0000-0000-000000000007') is null,'organization administration does not grant workspace records');
 begin
  perform public.findez_manage_collaboration('b0000000-0000-0000-0000-000000000006','inventory_policy',jsonb_build_object('inventory_id',internal,'access_mode','workspace','default_role','editor'));
  raise exception 'reviewer changed policy';
 exception when insufficient_privilege then raise notice 'PASS: viewer cannot change permissions'; end;
 org:=(public.findez_manage_collaboration(owner_id,'organization_create','{"name":"FTC Robotics"}')->>'organization_id')::uuid;
 for i in 14..37 loop
  person:=('b0000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid;
  perform public.findez_manage_collaboration(owner_id,'organization_member',jsonb_build_object('organization_id',org,'user_id',person,'role','member'));
 end loop;
 ws:=(public.findez_manage_collaboration(owner_id,'workspace_create',jsonb_build_object('organization_id',org,'name','FTC ROBOTICS 2026'))->>'team_id')::uuid;
 for i in 14..37 loop
  person:=('b0000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid;
  perform public.findez_manage_collaboration(owner_id,'workspace_member',jsonb_build_object('team_id',ws,'user_id',person,'role','editor'));
 end loop;
 insert into public.app_inventories(inventory_id,owner_user_id,team_id,name,access_mode) values
 (tools,owner_id,ws,'Tools & Machines','workspace'),(components,owner_id,ws,'Robot Components','restricted');
 perform public.findez_manage_collaboration(owner_id,'inventory_member',jsonb_build_object('inventory_id',components,'user_id',student,'role','editor'));
 perform pg_temp.check((select count(*)=25 from public.team_memberships where team_id=ws),'robotics has one workspace with 25 members');
 perform pg_temp.check(public.findez_inventory_role(tools,student)='viewer' and public.findez_inventory_role(components,student)='editor','same student edits Components and views Tools');
 perform pg_temp.check(public.findez_inventory_role(components,'b0000000-0000-0000-0000-000000000015') is null,'unassigned robotics member cannot access restricted Components');
 loc:=(public.findez_manage_collaboration(owner_id,'location_create',jsonb_build_object('team_id',ws,'name','FTC workshop'))->>'location_id')::uuid;
 cabinet:=(public.findez_manage_collaboration(owner_id,'location_create',jsonb_build_object('team_id',ws,'name','Fastener cabinet','parent_id',loc))->>'location_id')::uuid;
 drawer:=(public.findez_manage_collaboration(owner_id,'location_create',jsonb_build_object('team_id',ws,'name','Drawer 3','parent_id',cabinet))->>'location_id')::uuid;
 loc:=(public.findez_manage_collaboration(owner_id,'location_create',jsonb_build_object('team_id',ws,'name','Bin B12','parent_id',drawer))->>'location_id')::uuid;
 space_a:=(public.findez_manage_collaboration(owner_id,'location_attach',jsonb_build_object('inventory_id',tools,'location_id',loc))->>'id')::uuid;
 space_b:=(public.findez_manage_collaboration(owner_id,'location_attach',jsonb_build_object('inventory_id',components,'location_id',loc))->>'id')::uuid;
 perform pg_temp.check((select count(*)=2 from public.spaces where physical_location_id=loc),'two inventories explicitly share one physical location identity');
 perform pg_temp.check((select name='FTC workshop / Fastener cabinet / Drawer 3 / Bin B12' from public.spaces where id=space_a),'physical location path retains its full hierarchy');
 begin
  perform public.findez_manage_collaboration(owner_id,'location_attach',jsonb_build_object('inventory_id',equipment,'location_id',loc));
  raise exception 'cross-workspace location attached';
 exception when no_data_found then raise notice 'PASS: foreign location attachment denied'; end;
 -- Existing ownership does not override the new, narrower policy.
 insert into public.items(item_id,user_id,inventory_id,space_id,name,category,quantity,location)
 values('b1000000-0000-0000-0000-000000000001',student,tools,space_a,'Soldering station','Tools',1,'Bin B12'),
 ('b1000000-0000-0000-0000-000000000002',student,components,space_b,'Motor','Components',4,'Bin B12');
 insert into access_demo values('student',student),('owner',owner_id),('robotics',ws),('components',components),('tools',tools),('acme',acme);
end $$;
-- RLS: forge an owner header as an authenticated viewer. The header is ignored.
set role authenticated;
select set_config('request.jwt.claims','{"sub":"b0000000-0000-0000-0000-000000000014","role":"authenticated"}',false);
select set_config('request.headers','{"x-findez-actor":"b0000000-0000-0000-0000-000000000001"}',false);
select pg_temp.check((select count(*)=2 from public.items where item_id::text like 'b100%'),'student reads permitted saved items');
update public.items set quantity=999 where item_id='b1000000-0000-0000-0000-000000000001';
select pg_temp.check((select quantity=1 from public.items where item_id='b1000000-0000-0000-0000-000000000001'),'RLS blocks viewer write despite original item ownership and forged actor header');
update public.items set quantity=3,location='Electronics Bench' where item_id='b1000000-0000-0000-0000-000000000002';
reset role;
select pg_temp.check((select quantity=3 from public.items where item_id='b1000000-0000-0000-0000-000000000002'),'editor update persists');
select pg_temp.check(exists(select 1 from public.app_access_audit where target_id='b1000000-0000-0000-0000-000000000002' and actor_id='b0000000-0000-0000-0000-000000000014' and changes->>'location_evidence'='recorded' and changes->'after'->>'location'='Electronics Bench'),'movement audit retains actual actor and recorded evidence');
-- Service-role legacy route write is checked again by the database.
select set_config('request.jwt.claims','{"role":"service_role"}',false);
select set_config('request.headers','{"x-findez-actor":"b0000000-0000-0000-0000-000000000014"}',false);
do $$ begin
 begin update public.items set quantity=999 where item_id='b1000000-0000-0000-0000-000000000001';
 raise exception 'legacy service route bypassed viewer role';
 exception when insufficient_privilege then raise notice 'PASS: service-role viewer write rejected'; end;
end $$;
select set_config('request.jwt.claims','{}',false);
select set_config('request.headers','{}',false);
select public.findez_manage_collaboration((select id from access_demo where key='owner'),'workspace_member',jsonb_build_object('team_id',(select id from access_demo where key='robotics'),'user_id',(select id from access_demo where key='student'),'role','none'));
select pg_temp.check(public.findez_inventory_role((select id from access_demo where key='components'),(select id from access_demo where key='student')) is null,'workspace removal immediately revokes inventory grants');
select pg_temp.check(not exists(select 1 from public.app_inventory_members where user_id=(select id from access_demo where key='student')),'revocation removes stale grants');
set role authenticated;
select set_config('request.jwt.claims','{"sub":"b0000000-0000-0000-0000-000000000014","role":"authenticated"}',false);
select pg_temp.check((select count(*)=0 from public.items where item_id::text like 'b100%'),'revoked member cannot bypass through direct database ownership');
reset role;
select set_config('request.jwt.claims','{}',false);

-- Existing independent workspaces are attached deliberately, without moving data.
do $$ declare ws uuid:=gen_random_uuid(); owner_id uuid:=(select id from access_demo where key='owner');
begin
 insert into public.teams(team_id,owner_user_id,name,program,custom_category,join_code) values(ws,owner_id,'Existing project','custom','Project','EXIST1');
 insert into public.team_memberships(team_id,user_id,role) values(ws,owner_id,'owner'),(ws,'b0000000-0000-0000-0000-000000000038','member');
 begin
  perform public.findez_manage_collaboration(owner_id,'workspace_attach',jsonb_build_object('organization_id',(select id from access_demo where key='acme'),'team_id',ws));
  raise exception 'workspace attached with external members';
 exception when check_violation then raise notice 'PASS: attachment requires existing organization memberships'; end;
 perform public.findez_manage_collaboration(owner_id,'organization_member',jsonb_build_object('organization_id',(select id from access_demo where key='acme'),'user_id','b0000000-0000-0000-0000-000000000038','role','member'));
 perform public.findez_manage_collaboration(owner_id,'workspace_attach',jsonb_build_object('organization_id',(select id from access_demo where key='acme'),'team_id',ws));
 perform pg_temp.check((select organization_id=(select id from access_demo where key='acme') from public.teams where team_id=ws),'existing workspace keeps its identity when attached');
end $$;

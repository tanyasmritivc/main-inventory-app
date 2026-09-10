-- Run only in the same disposable database/session after api_key_rls.sql.
-- These checks cover subtleties described in the public integration guide.
begin;
reset role;
select set_config('request.jwt.claims','{}',false);
insert into public.teams values
('60000000-0000-0000-0000-000000000001','Docs team','60000000-0000-0000-0000-000000000002'),
('60000000-0000-0000-0000-000000000003','Docs empty team','60000000-0000-0000-0000-000000000002');
insert into public.spaces(id,user_id,name) values
('60000000-0000-0000-0000-000000000004','60000000-0000-0000-0000-000000000002','Docs shelf'),
('60000000-0000-0000-0000-000000000005','60000000-0000-0000-0000-000000000002','Docs empty shelf');
insert into public.team_spaces(team_id,space_id) values
('60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000004'),
('60000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000005');
insert into public.items(user_id,space_id,name,category,quantity,location,brand) values
('60000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000004','Zero stock','Other',0,'Docs shelf',null),
('60000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000004','Part','Other',4,'Docs shelf','Acme');
insert into public.api_keys(id,workspace_id,org_id,name,key_prefix,key_hash,scopes,created_by) values
('60000000-0000-0000-0000-000000000006',null,'60000000-0000-0000-0000-000000000002','Docs read','fixture','fixture',array['org:read'],'60000000-0000-0000-0000-000000000002');
set role authenticated;
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','60000000-0000-0000-0000-000000000006',
  'api_key_id','60000000-0000-0000-0000-000000000006',
  'api_org_id','60000000-0000-0000-0000-000000000002',
  'api_workspace_id',null,'api_scopes',jsonb_build_array('org:read'))::text,false);
select pg_temp.check((select count(*)=1 from public.api_distinct_locations()),'docs: empty Spaces omitted from location list');
select pg_temp.check((select item_count=2 from public.api_distinct_locations()),'docs: zero-quantity records count as items');
select pg_temp.check((select space_count=1 from public.api_workspace_summary() where name='Docs team'),'docs: space_count excludes empty Spaces');
select pg_temp.check((select item_count=0 and space_count=0 from public.api_workspace_summary() where name='Docs empty team'),'docs: empty teams remain in summary');
select pg_temp.check((public.api_query_items(null,'[{"field":"brand","op":"neq","value":"Other"}]','count')->>'value')::int=1,'docs: neq does not match null');
select pg_temp.check((public.api_query_items(null,'[{"field":"brand","op":"eq","value":"acme"}]','count')->>'value')::int=0,'docs: exact text comparisons are case sensitive');
select pg_temp.check((public.api_query_items(null,'[{"field":"brand","op":"eq","value":"%"}]','count')->>'value')::int=0,'docs: percent is literal, not a wildcard');
select pg_temp.check((public.api_query_items('10000000-0000-0000-0000-000000000001','[]','count')->>'value')::int=0,'docs: org read of unowned team has zero visible rows');
rollback;
\echo Public API documentation semantics passed.

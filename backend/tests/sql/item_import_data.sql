\ir ../../supabase/migrations/042_item_import_data.sql

select pg_temp.check((select count(*) > 0 from public.items where import_data is null), 'legacy items retain null source data');
begin;
update public.items set import_data = '{"filename":"parts.csv","sheet":"Sheet1","fields":[{"name":"Size","value":"M2"},{"name":"Size","value":12},{"name":"","value":false}]}'
where name = 'Bolt';
select pg_temp.check((select import_data->'fields'->1->>'name' = 'Size' and import_data->'fields'->2->'value' = 'false'::jsonb from public.items where name = 'Bolt'), 'ordered duplicate and unnamed source fields round trip');
do $$ begin
  begin
    update public.items set import_data = '{}' where name = 'Bolt';
    raise exception 'invalid source data accepted';
  exception when check_violation then raise notice 'PASS: source fields required'; end;
end $$;
rollback;

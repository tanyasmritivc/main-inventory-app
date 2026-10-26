-- Disposable fixture only. Verify review ownership, rename and Space deletion.
insert into public.spaces(id, user_id, name) values
('71000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','Robot Room'),
('71000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000002','Robot Room'),
('71000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','Lab');

insert into public.capture_reviews(review_id,user_id,source_key,name,category,location) values
('73000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','space-review:legacy','Unknown','Other',' robot room '),
('73000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000002','space-review:foreign','Other user','Other','Robot Room'),
('73000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','space-review:unsorted','Unsorted capture','Other','Unsorted'),
('73000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','space-review:no-location','Unassigned capture','Other',null);

\ir ../../supabase/migrations/039_space_review_lifecycle.sql
select pg_temp.check((select space_id='71000000-0000-0000-0000-000000000001' from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000001'),'legacy review binds only to owned matching Space');
select pg_temp.check((select space_id='71000000-0000-0000-0000-000000000002' from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000002'),'same-name foreign review keeps its own Space');

insert into public.capture_reviews(review_id,user_id,source_key,name,category,location) values
('73000000-0000-0000-0000-000000000005','72000000-0000-0000-0000-000000000001','space-review:new','New capture','Other','ROBOT ROOM');
select pg_temp.check((select space_id='71000000-0000-0000-0000-000000000001' and location='Robot Room' from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000005'),'new review uses stable Space identity and canonical name');

do $$ begin
  begin
    update public.capture_reviews set space_id='71000000-0000-0000-0000-000000000002'
    where review_id='73000000-0000-0000-0000-000000000005';
    raise exception 'Review accepted a foreign Space';
  exception when check_violation then raise notice 'PASS: review cannot bind to a foreign Space';
  end;
end $$;

update public.spaces set name='Project Room' where id='71000000-0000-0000-0000-000000000001';
select pg_temp.check((select location='Project Room' and space_id='71000000-0000-0000-0000-000000000001' from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000001'),'Space rename keeps legacy review attached');

update public.capture_reviews set location='Lab' where review_id='73000000-0000-0000-0000-000000000005';
select pg_temp.check((select space_id='71000000-0000-0000-0000-000000000003' from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000005'),'editing review location moves its Space association');

delete from public.spaces where id='71000000-0000-0000-0000-000000000001';
select pg_temp.check((select count(*)=0 from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000001'),'Space deletion removes attached pending identification');
select pg_temp.check((select count(*)=1 from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000002'),'Space deletion preserves another user same-name review');
select pg_temp.check((select count(*)=3 from public.capture_reviews where review_id in ('73000000-0000-0000-0000-000000000003','73000000-0000-0000-0000-000000000004','73000000-0000-0000-0000-000000000005')),'Space deletion preserves unassigned and moved captures');

-- A rolled-back deletion restores both the Space and its review.
begin;
delete from public.spaces where id='71000000-0000-0000-0000-000000000003';
select pg_temp.check((select count(*)=0 from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000005'),'Space and review delete together');
rollback;
select pg_temp.check((select count(*)=1 from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000005'),'failed deletion transaction preserves review');

set role authenticated;
select set_config('request.jwt.claims','{"sub":"72000000-0000-0000-0000-000000000001"}',false);
select pg_temp.check((select count(*)=0 from public.capture_reviews where review_id='73000000-0000-0000-0000-000000000002'),'new Space link preserves review RLS');
reset role;
\echo Space review lifecycle checks passed.

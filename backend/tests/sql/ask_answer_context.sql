-- Included only by the empty disposable database entry point.
create table auth.users (id uuid primary key);
insert into auth.users values
('20000000-0000-0000-0000-000000000001'),
('20000000-0000-0000-0000-000000000002');
\ir ../../supabase/migrations/009_conversation_history.sql
\ir ../../supabase/migrations/037_ask_answer_context.sql
grant select, insert, delete on public.conversations, public.messages to authenticated;
grant select on public.conversations, public.messages to anon;

insert into public.conversations(id,user_id,title) values
('70000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Ask A'),
('70000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Ask B');
insert into public.messages(conversation_id,role,content,answer_context) values
('70000000-0000-0000-0000-000000000001','assistant','Answer A','{"sources":[{"kind":"inventory","label":"Garage"}],"rows":[]}'),
('70000000-0000-0000-0000-000000000002','assistant','Private answer','{"sources":[{"kind":"project","label":"Private project"}],"rows":[]}');

set role authenticated;
select set_config('request.jwt.claims','{"sub":"20000000-0000-0000-0000-000000000001"}',false);
select pg_temp.check((select count(*)=1 from public.messages),'Ask evidence follows conversation ownership');
select pg_temp.check((select answer_context->'sources'->0->>'label'='Garage' from public.messages),'Ask evidence survives history reads');
do $$ begin
    begin insert into public.messages(conversation_id,role,content,answer_context) values
      ('70000000-0000-0000-0000-000000000002','assistant','Injected','{}');
      raise exception 'foreign conversation write accepted';
    exception when insufficient_privilege then raise notice 'PASS: foreign Ask history write denied'; end;
    begin insert into public.messages(conversation_id,role,content,answer_context) values
      ('70000000-0000-0000-0000-000000000001','user','Question','{}');
      raise exception 'question accepted assistant evidence';
    exception when check_violation then raise notice 'PASS: source snapshot is assistant-only'; end;
    begin insert into public.messages(conversation_id,role,content,answer_context) values
      ('70000000-0000-0000-0000-000000000001','assistant','Malformed','[]');
      raise exception 'non-object source snapshot accepted';
    exception when check_violation then raise notice 'PASS: source snapshot must be an object'; end;
end $$;
delete from public.conversations where id='70000000-0000-0000-0000-000000000001';
select pg_temp.check((select count(*)=0 from public.messages),'deleting owned chat removes its Ask evidence');
reset role;
select pg_temp.check((select count(*)=1 from public.messages),'deleting own chat preserves other user history');
set role anon;
select set_config('request.jwt.claims','{}',false);
select pg_temp.check((select count(*)=0 from public.messages),'anonymous user cannot read Ask evidence');
reset role;

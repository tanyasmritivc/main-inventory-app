-- Included only by the empty disposable database suite, never production.
reset role;
create schema storage;
create table storage.buckets (
    id text primary key, public boolean not null, file_size_limit bigint,
    allowed_mime_types text[]
);
create table storage.objects (id integer primary key, bucket_id text, name text);
alter table storage.objects enable row level security;
grant usage on schema storage to anon, authenticated, service_role;
grant select, insert, update, delete on storage.objects to anon, authenticated, service_role;
-- Simulate legacy broad policy: the new restrictive policy must override it.
create policy historical_permissive on storage.objects for all to public using(true) with check(true);
insert into storage.buckets values
    ('documents', true, 52428800, array['text/plain']),
    ('item-images', true, 10485760, array['image/jpeg']),
    ('profile-photos', false, 5242880, array['image/png']);
insert into storage.objects values
    (1, 'documents', 'owner/docs/note.txt'),
    (2, 'documents', 'teams/team/owner/file.pdf'),
    (3, 'item-images', 'owner/photo.jpg');

\ir ../../supabase/migrations/038_private_documents.sql
\ir ../../supabase/migrations/038_private_documents.sql
select pg_temp.check((select not public from storage.buckets where id='documents'),'documents private after idempotent migration');
select pg_temp.check((select public from storage.buckets where id='item-images'),'item images configuration unchanged');
select pg_temp.check((select not public from storage.buckets where id='profile-photos'),'profile privacy unchanged');
select pg_temp.check((select file_size_limit=52428800 and allowed_mime_types=array['text/plain'] from storage.buckets where id='documents'),'document metadata retained');
select pg_temp.check((select count(*)=3 from storage.objects),'all stored paths retained');

set role anon;
select pg_temp.check((select count(*)=0 from storage.objects where bucket_id='documents'),'anonymous document reads denied');
set role authenticated;
select pg_temp.check((select count(*)=0 from storage.objects where bucket_id='documents'),'direct JWT document reads denied');
do $$ begin
    begin insert into storage.objects values (4,'documents','owner/docs/new.txt');
        raise exception 'direct upload accepted';
    exception when insufficient_privilege then raise notice 'PASS: direct document writes denied'; end;
end $$;
delete from storage.objects where bucket_id='documents';
select pg_temp.check((select count(*)=1 from storage.objects where bucket_id='item-images'),'other bucket policies unaffected');
set role service_role;
select pg_temp.check((select count(*)=2 from storage.objects where bucket_id='documents'),'service-role document API retains access');
insert into storage.objects values (5,'documents','owner/docs/api-upload.txt');
delete from storage.objects where id=5;
reset role;
select pg_temp.check((select count(*)=2 from storage.objects where bucket_id='documents'),'JWT deletion cannot remove private files');

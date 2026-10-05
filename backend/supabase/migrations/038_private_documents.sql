-- Apply only after document clients use the authorized /documents/open APIs.
-- Stored paths and objects are retained. Signed URLs are bearer capabilities
-- until expiry; this change does not recall previously downloaded copies.
begin;

do $$ begin
    if not exists (select 1 from storage.buckets where id = 'documents') then
        raise exception 'The documents bucket must exist before migration 038';
    end if;
    if not (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass) then
        raise exception 'Storage objects must have row-level security enabled before migration 038';
    end if;
end $$;

update storage.buckets set public = false where id = 'documents';

-- Deny direct JWT/anonymous access even if a deployment has an older broad
-- permissive policy. Other buckets and service-role API access are unchanged.
drop policy if exists documents_backend_only on storage.objects;
create policy documents_backend_only on storage.objects
    as restrictive for all to anon, authenticated
    using (bucket_id <> 'documents')
    with check (bucket_id <> 'documents');

commit;

alter table public.items
    add column if not exists catalog_id uuid
        references public.parts_catalog(catalog_id) on delete set null;

create index if not exists items_catalog_id_idx on public.items (catalog_id)
    where catalog_id is not null;

notify pgrst, 'reload schema';

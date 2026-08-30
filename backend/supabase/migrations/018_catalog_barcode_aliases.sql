-- A manufacturer part can appear under multiple UPCs over its lifetime. Keep
-- those scan identities separate from the canonical verified product row.
alter table public.parts_catalog
    add column if not exists image_url text;

create table if not exists public.part_catalog_barcodes (
    barcode text primary key,
    catalog_id uuid not null references public.parts_catalog(catalog_id) on delete cascade,
    source text not null default 'manufacturer',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists part_catalog_barcodes_catalog_id_idx
    on public.part_catalog_barcodes (catalog_id);

insert into public.part_catalog_barcodes (barcode, catalog_id, source)
select barcode, catalog_id, source
from public.parts_catalog
where barcode is not null and btrim(barcode) <> ''
on conflict (barcode) do update
set catalog_id = excluded.catalog_id,
    source = excluded.source,
    updated_at = now();

-- Migration 017 originally used the goBILDA SKU as its scan barcode. The
-- official product page publishes this UPC; retain the SKU as a scan alias.
update public.parts_catalog
set barcode = '841298115072', updated_at = now()
where lower(brand) = 'gobilda'
  and lower(part_number) = '3802-0102-0300';

insert into public.part_catalog_barcodes (barcode, catalog_id, source)
select value, catalog_id, 'manufacturer'
from public.parts_catalog
cross join lateral (values ('841298115072'), ('3802-0102-0300')) as aliases(value)
where lower(brand) = 'gobilda'
  and lower(part_number) = '3802-0102-0300'
on conflict (barcode) do update
set catalog_id = excluded.catalog_id,
    source = excluded.source,
    updated_at = now();

notify pgrst, 'reload schema';

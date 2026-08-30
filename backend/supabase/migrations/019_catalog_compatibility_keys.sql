-- Searchable interface keys extracted only from manufacturer-sourced product
-- names, descriptions, and specifications. They indicate a shared published
-- interface, not an unsupported claim that every pair is interchangeable.
alter table public.parts_catalog
    add column if not exists compatibility_keys text[] not null default '{}';

create index if not exists parts_catalog_compatibility_keys_idx
    on public.parts_catalog using gin (compatibility_keys);

with source_text as (
    select catalog_id,
           lower(coalesce(canonical_name, '') || ' ' || coalesce(description, '') || ' ' || specifications::text) as text
    from public.parts_catalog
    where verification_status = 'verified'
)
update public.parts_catalog p
set compatibility_keys = array_remove(array[
    case when s.text ~ 'xt30' then 'connector:XT30' end,
    case when s.text ~ 'xt60' then 'connector:XT60' end,
    case when s.text ~ 'xt90' then 'connector:XT90' end,
    case when s.text ~ 'jst[ -]?ph' then 'connector:JST PH' end,
    case when s.text ~ 'jst[ -]?vh' then 'connector:JST VH' end,
    case when s.text ~ 'jst[ -]?xh' then 'connector:JST XH' end,
    case when s.text ~ 'anderson powerpole|powerpole' then 'connector:Anderson Powerpole' end,
    case when s.text ~ 'tamiya' then 'connector:Tamiya' end,
    case when s.text ~ '8 ?mm rex' then 'shaft:8mm REX' end,
    case when s.text ~ '5 ?mm hex' then 'shaft:5mm Hex' end,
    case when s.text ~ '1/2 ?(in|inch)? hex' then 'shaft:1/2in Hex' end,
    case when s.text ~ '6 ?mm d[- ]?bore' then 'shaft:6mm D-Bore' end,
    case when s.text ~ '16 ?mm pattern' then 'structure:16mm Pattern' end,
    case when s.text ~ '15 ?mm extrusion' then 'structure:15mm Extrusion' end,
    case when s.text ~ 'spark max' then 'control:SPARK MAX' end
], null)
from source_text s
where p.catalog_id = s.catalog_id;

notify pgrst, 'reload schema';

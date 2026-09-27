begin;

alter table public.items
    add column identity_confirmed boolean not null default false,
    add column named_by text check (
        named_by in ('barcode', 'ocr', 'catalog', 'memory', 'vlm',
                     'spreadsheet', 'manual_entry')
    );

create index items_need_identity_idx on public.items (user_id, created_at desc)
    where identity_confirmed = false;

commit;

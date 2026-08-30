insert into public.parts_catalog (
    barcode, canonical_name, aliases, brand, category, subcategory, part_number,
    description, source, verification_status, product_url, source_url,
    specifications, compatibility, confirmation_count, verified_at
) values (
    '3802-0102-0300',
    'XT30 Extension (FH-MC to MH-FC, 300mm Length)',
    array['Male XT30 to Female XT30 Extension 300mm', 'XT30 Extension 300mm'],
    'goBILDA',
    'Electronics',
    'Wiring',
    '3802-0102-0300',
    'Polarity-specific XT30 extension cable for adding distance between power components.',
    'manufacturer',
    'verified',
    'https://www.gobilda.com/xt30-extension-fh-mc-to-mh-fc-300mm-length/',
    'https://www.gobilda.com/xt30-extension-fh-mc-to-mh-fc-300mm-length/',
    '{"connector":"Male XT30 / Female XT30","wire_length":"300 mm","wire_gauge":"16 AWG","weight":"16 g","insulation":"ABS"}'::jsonb,
    '{"connector_system":["XT30"]}'::jsonb,
    1,
    now()
)
on conflict do nothing;

notify pgrst, 'reload schema';

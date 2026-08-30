-- Verified robotics catalog metadata. Existing crowd-confirmed barcode rows stay
-- community-sourced until an authoritative vendor source is attached.

alter table public.parts_catalog
    add column if not exists verification_status text not null default 'community'
        check (verification_status in ('community', 'verified')),
    add column if not exists product_url text,
    add column if not exists source_url text,
    add column if not exists specifications jsonb not null default '{}'::jsonb,
    add column if not exists compatibility jsonb not null default '{}'::jsonb,
    add column if not exists verified_at timestamptz;

create unique index if not exists parts_catalog_verified_brand_part_key
    on public.parts_catalog (lower(brand), lower(part_number))
    where verification_status = 'verified'
      and brand is not null
      and part_number is not null;

create index if not exists parts_catalog_part_number_lower_idx
    on public.parts_catalog (lower(part_number))
    where part_number is not null;

insert into public.parts_catalog (
    barcode, canonical_name, aliases, brand, category, subcategory, part_number,
    description, source, verification_status, product_url, source_url,
    specifications, compatibility, confirmation_count, verified_at
) values
    (
        null, 'NEO Brushless Motor V1.1', array['NEO Motor'],
        'REV Robotics', 'Robot Parts', 'Motors', 'REV-21-1650',
        '12 V FRC brushless motor with integrated hall sensors.',
        'manufacturer', 'verified',
        'https://www.revrobotics.com/rev-21-1650/',
        'https://www.revrobotics.com/rev-21-1650/',
        '{"nominal_voltage":"12 V","free_speed":"5676 RPM","shaft":"8 mm keyed"}'::jsonb,
        '{"motor_controllers":["REV SPARK MAX"]}'::jsonb,
        1, now()
    ),
    (
        null, 'NEO 550 Brushless Motor', array['NEO 550'],
        'REV Robotics', 'Robot Parts', 'Motors', 'REV-21-1651',
        'Compact 12 V brushless motor for FRC mechanisms.',
        'manufacturer', 'verified',
        'https://www.revrobotics.com/rev-21-1651/',
        'https://www.revrobotics.com/rev-21-1651/',
        '{"nominal_voltage":"12 V","free_speed":"11000 RPM","shaft":"0.125 in"}'::jsonb,
        '{"motor_controllers":["REV SPARK MAX"]}'::jsonb,
        1, now()
    ),
    (
        null, 'SPARK MAX Motor Controller', array['SPARK MAX'],
        'REV Robotics', 'Electronics', 'Motor Controllers', 'REV-11-2158',
        'Brushed and brushless DC motor controller with PWM, CAN, and USB.',
        'manufacturer', 'verified',
        'https://www.revrobotics.com/rev-11-2158/',
        'https://www.revrobotics.com/rev-11-2158/',
        '{"communication":["PWM","CAN","USB-C"]}'::jsonb,
        '{"motors":["REV NEO","REV NEO 550"]}'::jsonb,
        1, now()
    )
on conflict do nothing;

notify pgrst, 'reload schema';

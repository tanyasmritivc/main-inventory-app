alter table public.items
  add column if not exists subcategory text,
  add column if not exists brand text,
  add column if not exists part_number text,
  add column if not exists tags text[],
  add column if not exists confidence double precision;

create index if not exists idx_items_user_category on public.items (user_id, category);
create index if not exists idx_items_user_subcategory on public.items (user_id, subcategory);
create index if not exists idx_items_user_barcode on public.items (user_id, barcode);
create index if not exists idx_items_user_part_number on public.items (user_id, part_number);

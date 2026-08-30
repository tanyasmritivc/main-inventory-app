-- Backfill existing inventory rows using exact part-number matches and known
-- manufacturer aliases. This never matches on item name alone.

update public.items as i
set catalog_id = c.catalog_id
from public.parts_catalog as c
where i.catalog_id is null
  and c.verification_status = 'verified'
  and i.part_number is not null
  and i.brand is not null
  and lower(trim(i.part_number)) = lower(trim(c.part_number))
  and (
      regexp_replace(lower(i.brand), '[^a-z0-9]', '', 'g') =
          regexp_replace(lower(c.brand), '[^a-z0-9]', '', 'g')
      or (
          regexp_replace(lower(c.brand), '[^a-z0-9]', '', 'g') = 'revrobotics'
          and regexp_replace(lower(i.brand), '[^a-z0-9]', '', 'g') in ('rev', 'ion')
      )
  );

notify pgrst, 'reload schema';

-- Immutable source fields alongside live inventory fields. Existing items stay null.
BEGIN;
ALTER TABLE public.items ADD COLUMN import_data jsonb;
ALTER TABLE public.items ADD CONSTRAINT items_import_data_object
  CHECK (import_data IS NULL OR
    coalesce(jsonb_typeof(import_data) = 'object' AND jsonb_typeof(import_data->'fields') = 'array', false));
COMMENT ON COLUMN public.items.import_data IS
  'Original import filename, sheet and ordered fields with exact header names and JSON values. A source snapshot, not current stock or location.';
NOTIFY pgrst, 'reload schema';
COMMIT;

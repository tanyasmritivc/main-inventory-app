-- Deleting a space deletes the inventory it contains instead of silently
-- converting those item rows to Unsorted inventory.
ALTER TABLE public.items
    DROP CONSTRAINT IF EXISTS items_space_id_fkey;

ALTER TABLE public.items
    ADD CONSTRAINT items_space_id_fkey
    FOREIGN KEY (space_id)
    REFERENCES public.spaces(id)
    ON DELETE CASCADE;

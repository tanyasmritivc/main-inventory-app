-- Inventory is a data boundary inside a personal or existing Team workspace.
-- Preserve every existing owner and record; only add context associations.
BEGIN;

CREATE TABLE public.app_inventories (
  inventory_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  team_id uuid REFERENCES public.teams(team_id) ON DELETE CASCADE,
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 100),
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX app_inventory_personal_default ON public.app_inventories(owner_user_id)
  WHERE team_id IS NULL AND is_default;
CREATE UNIQUE INDEX app_inventory_team_default ON public.app_inventories(team_id)
  WHERE team_id IS NOT NULL AND is_default;
CREATE UNIQUE INDEX app_inventory_name ON public.app_inventories
  (owner_user_id, coalesce(team_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));
ALTER TABLE public.app_inventories ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_inventories FROM anon, authenticated;
GRANT ALL ON public.app_inventories TO service_role;

CREATE FUNCTION public.findez_default_inventory(p_user_id uuid, p_team_id uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_owner uuid := p_user_id;
BEGIN
  IF p_team_id IS NOT NULL THEN
    SELECT owner_user_id INTO STRICT v_owner FROM public.teams WHERE team_id = p_team_id;
  END IF;
  SELECT inventory_id INTO v_id FROM public.app_inventories
    WHERE owner_user_id = v_owner AND team_id IS NOT DISTINCT FROM p_team_id AND is_default;
  IF v_id IS NULL THEN
    INSERT INTO public.app_inventories(owner_user_id, team_id, created_by_user_id, name, is_default)
      VALUES(v_owner, p_team_id, v_owner, CASE WHEN p_team_id IS NULL THEN 'My inventory' ELSE 'Inventory' END, true)
      ON CONFLICT DO NOTHING RETURNING inventory_id INTO v_id;
    IF v_id IS NULL THEN
      SELECT inventory_id INTO STRICT v_id FROM public.app_inventories
        WHERE owner_user_id = v_owner AND team_id IS NOT DISTINCT FROM p_team_id AND is_default;
    END IF;
  END IF;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.findez_default_inventory(uuid,uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.findez_default_inventory(uuid,uuid) TO service_role;

SELECT public.findez_default_inventory(id) FROM auth.users;
SELECT public.findez_default_inventory(owner_user_id, team_id) FROM public.teams;

-- Optional historical tables vary across installations. Each present data table
-- gains the same indexed boundary; old clients inherit one through triggers.
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['spaces','items','bins','documents','activity_log','capture_reviews',
    'conversations','messages','checkouts','item_events','project_kits','project_kit_items',
    'project_kit_reservations','conversation_history','query_logs'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ADD COLUMN inventory_id uuid REFERENCES public.app_inventories(inventory_id)', t);
      EXECUTE format('CREATE INDEX %I ON public.%I(inventory_id)', t || '_inventory_id_idx', t);
    END IF;
  END LOOP;
END $$;

ALTER TABLE public.documents ADD COLUMN inventory_visibility text NOT NULL DEFAULT 'personal'
  CHECK (inventory_visibility IN ('personal','inventory'));
ALTER TABLE public.capture_reviews ADD COLUMN inventory_visibility text NOT NULL DEFAULT 'personal'
  CHECK (inventory_visibility IN ('personal','inventory'));

UPDATE public.spaces s SET inventory_id = public.findez_default_inventory(s.user_id,
  (SELECT ts.team_id FROM public.team_spaces ts WHERE ts.space_id = s.id));
UPDATE public.items i SET inventory_id = coalesce(
  (SELECT s.inventory_id FROM public.spaces s WHERE s.id = i.space_id), public.findez_default_inventory(i.user_id));

-- Backfill parents first, then children. Unlinked history remains personal.
DO $$ DECLARE t text; owner_column text; BEGIN
  FOREACH t IN ARRAY ARRAY['documents','activity_log','capture_reviews','conversations',
    'checkouts','item_events','project_kits','conversation_history','query_logs'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      owner_column := CASE WHEN t = 'project_kits' THEN 'owner_user_id' ELSE 'user_id' END;
      EXECUTE format('UPDATE public.%I SET inventory_id = public.findez_default_inventory(%I) WHERE %I IS NOT NULL', t, owner_column, owner_column);
    END IF;
  END LOOP;
  IF to_regclass('public.bins') IS NOT NULL THEN
    UPDATE public.bins b SET inventory_id = s.inventory_id FROM public.spaces s WHERE s.id = b.space_id;
  END IF;
  IF to_regclass('public.documents') IS NOT NULL THEN
    UPDATE public.documents d SET inventory_id = i.inventory_id FROM public.items i WHERE i.item_id = d.item_id;
  END IF;
  IF to_regclass('public.checkouts') IS NOT NULL THEN
    UPDATE public.checkouts c SET inventory_id = i.inventory_id FROM public.items i WHERE i.item_id = c.item_id;
  END IF;
  IF to_regclass('public.item_events') IS NOT NULL THEN
    UPDATE public.item_events e SET inventory_id = i.inventory_id FROM public.items i WHERE i.item_id = e.item_id;
  END IF;
  UPDATE public.capture_reviews r SET inventory_id = s.inventory_id FROM public.spaces s WHERE s.id = r.space_id;
  IF to_regclass('public.project_kits') IS NOT NULL THEN
    UPDATE public.project_kits k SET inventory_id = s.inventory_id FROM public.spaces s
      WHERE s.user_id = k.owner_user_id AND lower(s.name) = lower(k.location);
    UPDATE public.project_kit_items l SET inventory_id = k.inventory_id FROM public.project_kits k WHERE k.id = l.kit_id;
    UPDATE public.project_kit_reservations r SET inventory_id = k.inventory_id FROM public.project_kits k WHERE k.id = r.kit_id;
  END IF;
  IF to_regclass('public.messages') IS NOT NULL THEN
    UPDATE public.messages m SET inventory_id = c.inventory_id FROM public.conversations c WHERE c.id = m.conversation_id;
  END IF;
END $$;

-- Isolate private learned facts and resumable Assist state without breaking old
-- clients' user-only UPSERT constraints on the original tables.
CREATE TABLE public.inventory_user_memory (
  inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  id uuid NOT NULL DEFAULT gen_random_uuid(), key text NOT NULL, value text,
  updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(inventory_id,user_id,key)
);
CREATE TABLE public.inventory_conversation_sessions (
  inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  history jsonb NOT NULL DEFAULT '[]', last_item_name text, last_user_message text,
  updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(inventory_id,user_id)
);
ALTER TABLE public.inventory_user_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_conversation_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventory_user_memory, public.inventory_conversation_sessions FROM anon, authenticated;
GRANT ALL ON public.inventory_user_memory, public.inventory_conversation_sessions TO service_role;
DO $$ BEGIN
  IF to_regclass('public.user_memory') IS NOT NULL THEN
    INSERT INTO public.inventory_user_memory(inventory_id,user_id,key,value,updated_at)
      SELECT public.findez_default_inventory(user_id),user_id,key,value,updated_at FROM public.user_memory;
  END IF;
  IF to_regclass('public.conversation_sessions') IS NOT NULL THEN
    INSERT INTO public.inventory_conversation_sessions(inventory_id,user_id,history,last_item_name,last_user_message,updated_at)
      SELECT public.findez_default_inventory(user_id),user_id,coalesce(history,'[]'),last_item_name,last_user_message,updated_at
      FROM public.conversation_sessions;
  END IF;
END $$;

ALTER TABLE public.spaces DROP CONSTRAINT IF EXISTS spaces_user_id_name_key;
CREATE UNIQUE INDEX spaces_inventory_name ON public.spaces(inventory_id, user_id, name);
CREATE UNIQUE INDEX capture_reviews_inventory_source ON public.capture_reviews(inventory_id,user_id,source_key);

-- Validate related IDs even for service-role writes and legacy callers. An
-- inventory record cannot link a different inventory's location, item or chat.
CREATE FUNCTION public.findez_assign_inventory() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE data jsonb := to_jsonb(NEW); refs jsonb; ref record;
  parent_inventory uuid; selected_inventory uuid := NEW.inventory_id; owner_id uuid;
  parent_value uuid; workspace_team uuid;
BEGIN
  refs := CASE TG_TABLE_NAME
    WHEN 'items' THEN '{"space_id":["spaces","id"],"bin_id":["bins","id"]}'::jsonb
    WHEN 'bins' THEN '{"space_id":["spaces","id"]}'::jsonb
    WHEN 'documents' THEN '{"item_id":["items","item_id"]}'::jsonb
    WHEN 'item_events' THEN '{"item_id":["items","item_id"]}'::jsonb
    WHEN 'checkouts' THEN '{"item_id":["items","item_id"]}'::jsonb
    WHEN 'capture_reviews' THEN '{"space_id":["spaces","id"],"resolved_item_id":["items","item_id"]}'::jsonb
    WHEN 'messages' THEN '{"conversation_id":["conversations","id"]}'::jsonb
    WHEN 'project_kit_items' THEN '{"kit_id":["project_kits","id"]}'::jsonb
    WHEN 'project_kit_reservations' THEN '{"kit_id":["project_kits","id"],"kit_item_id":["project_kit_items","id"],"inventory_item_id":["items","item_id"]}'::jsonb
    ELSE '{}'::jsonb END;
  FOR ref IN SELECT * FROM jsonb_each(refs) LOOP
    parent_value := nullif(data->>ref.key, '')::uuid;
    IF parent_value IS NOT NULL THEN
      EXECUTE format('SELECT inventory_id FROM public.%I WHERE %I = $1', ref.value->>0, ref.value->>1)
        INTO parent_inventory USING parent_value;
      IF parent_inventory IS NULL THEN
        RAISE foreign_key_violation USING message = 'inventory parent not found';
      END IF;
      IF selected_inventory IS NOT NULL AND selected_inventory <> parent_inventory THEN
        RAISE check_violation USING message = 'related records belong to different inventories';
      END IF;
      selected_inventory := parent_inventory;
    END IF;
  END LOOP;
  IF selected_inventory IS NULL THEN
    owner_id := coalesce(nullif(data->>'user_id','')::uuid, nullif(data->>'owner_user_id','')::uuid);
    IF owner_id IS NULL THEN RAISE check_violation USING message = 'inventory owner required'; END IF;
    IF TG_TABLE_NAME = 'spaces' AND TG_OP = 'UPDATE' THEN
      SELECT team_id INTO workspace_team FROM public.team_spaces WHERE space_id = NEW.id;
    END IF;
    selected_inventory := public.findez_default_inventory(owner_id, workspace_team);
  END IF;
  NEW.inventory_id := selected_inventory;
  -- Direct authenticated clients retain ownership checks and must also belong
  -- to the inventory's workspace. HTTP app writes have an independent server check.
  IF auth.uid() IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.app_inventories inv WHERE inv.inventory_id = selected_inventory
      AND ((inv.team_id IS NULL AND inv.owner_user_id = auth.uid()) OR EXISTS (
        SELECT 1 FROM public.team_memberships m WHERE m.team_id = inv.team_id
          AND m.user_id = auth.uid() AND m.role IN ('owner','mentor','member')))
  ) THEN RAISE insufficient_privilege USING message = 'inventory write access denied'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_assign_inventory() FROM public, anon, authenticated;
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['spaces','items','bins','documents','activity_log','capture_reviews',
    'conversations','messages','checkouts','item_events','project_kits','project_kit_items',
    'project_kit_reservations','conversation_history','query_logs','inventory_user_memory','inventory_conversation_sessions'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('CREATE TRIGGER %I BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.findez_assign_inventory()', t || '_assign_inventory', t);
    END IF;
  END LOOP;
END $$;

CREATE VIEW public.app_inventory_summaries AS SELECT inv.*,
  (SELECT count(*) FROM public.items i WHERE i.inventory_id = inv.inventory_id) AS item_count
  FROM public.app_inventories inv;
REVOKE ALL ON public.app_inventory_summaries FROM anon, authenticated;
GRANT SELECT ON public.app_inventory_summaries TO service_role;

-- Review resolution retains its source inventory, including Unsorted captures.
create or replace function public.resolve_capture_review(
  p_review_id uuid,
  p_user_id uuid,
  p_item jsonb,
  p_space_id uuid default null,
  p_catalog_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_review public.capture_reviews%rowtype;
  v_item public.items%rowtype;
begin
  select * into v_review
  from public.capture_reviews
  where review_id = p_review_id and user_id = p_user_id
  for update;

  if not found then
    raise no_data_found using message = 'review item not found';
  end if;

  if v_review.status = 'resolved' and v_review.resolved_item_id is not null then
    select * into v_item from public.items
    where item_id = v_review.resolved_item_id and user_id = p_user_id;
    if found then
      return to_jsonb(v_item);
    end if;
  end if;

  if v_review.status <> 'pending' then
    raise check_violation using message = 'review item is no longer pending';
  end if;

  if nullif(btrim(p_item->>'name'), '') is null
     or length(p_item->>'name') > 200
     or nullif(btrim(p_item->>'category'), '') is null
     or length(p_item->>'category') > 100
     or nullif(btrim(p_item->>'location'), '') is null
     or length(p_item->>'location') > 200
     or coalesce(p_item->>'quantity', '') !~ '^[0-9]{1,6}$'
     or (p_item->>'quantity')::integer > 100000 then
    raise invalid_parameter_value using message = 'invalid reviewed item';
  end if;

  insert into public.items (
    user_id, name, category, subcategory, quantity, location, space_id,
    image_url, barcode, notes, brand, part_number, tags, confidence, catalog_id, inventory_id
  ) values (
    p_user_id,
    btrim(p_item->>'name'),
    btrim(p_item->>'category'),
    nullif(btrim(p_item->>'subcategory'), ''),
    (p_item->>'quantity')::integer,
    btrim(p_item->>'location'),
    p_space_id,
    nullif(btrim(p_item->>'image_url'), ''),
    nullif(btrim(p_item->>'barcode'), ''),
    nullif(btrim(p_item->>'notes'), ''),
    nullif(btrim(p_item->>'brand'), ''),
    nullif(btrim(p_item->>'part_number'), ''),
    case when jsonb_typeof(p_item->'tags') = 'array'
      then array(select jsonb_array_elements_text(p_item->'tags'))
      else null end,
    case when nullif(p_item->>'confidence', '') is null then null
      else greatest(0, least(1, (p_item->>'confidence')::double precision)) end,
    p_catalog_id,
    v_review.inventory_id
  ) returning * into v_item;

  update public.capture_reviews
  set status = 'resolved', resolved_item_id = v_item.item_id,
      resolved_at = now(), updated_at = now()
  where review_id = p_review_id and user_id = p_user_id;

  return to_jsonb(v_item);
end;
$$;

revoke all on function public.resolve_capture_review(uuid, uuid, jsonb, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.resolve_capture_review(uuid, uuid, jsonb, uuid, uuid)
  to service_role;


NOTIFY pgrst, 'reload schema';
COMMIT;


-- Additive item tracking and reviewed Chat changes. Never creates purchases.
BEGIN;
ALTER TABLE public.items
 ADD COLUMN IF NOT EXISTS unit_price numeric(18,4),
 ADD COLUMN IF NOT EXISTS currency text,
 ADD COLUMN IF NOT EXISTS expires_on date,
 ADD COLUMN IF NOT EXISTS reorder_enabled boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS reorder_threshold integer,
 ADD COLUMN IF NOT EXISTS reorder_quantity integer,
 ADD COLUMN IF NOT EXISTS reorder_armed boolean NOT NULL DEFAULT true;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.items'::regclass AND conname='items_commercial_tracking') THEN
 ALTER TABLE public.items ADD CONSTRAINT items_commercial_tracking CHECK (
  (unit_price IS NULL OR (unit_price>=0 AND unit_price<=1000000000 AND currency IS NOT NULL))
  AND (currency IS NULL OR currency ~ '^[A-Z]{3}$')
  AND (reorder_threshold IS NULL OR reorder_threshold BETWEEN 0 AND 1000000)
  AND (reorder_quantity IS NULL OR reorder_quantity BETWEEN 1 AND 1000000)
  AND (NOT reorder_enabled OR (reorder_threshold IS NOT NULL AND reorder_quantity IS NOT NULL)));
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.app_reorder_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 item_id uuid NOT NULL REFERENCES public.items(item_id) ON DELETE CASCADE,
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 item_name text NOT NULL,
 quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 1000000),
 threshold integer NOT NULL CHECK(threshold BETWEEN 0 AND 1000000),
 stock_at_request integer NOT NULL,
 unit_price numeric(18,4), currency text,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','dismissed','received')),
 created_at timestamptz NOT NULL DEFAULT now(),
 decided_at timestamptz, decided_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS reorder_one_open_per_item ON public.app_reorder_requests(item_id)
 WHERE status IN ('pending','approved');
CREATE INDEX IF NOT EXISTS reorder_inventory_status ON public.app_reorder_requests(inventory_id,status,created_at DESC);
ALTER TABLE public.app_reorder_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_reorder_requests FROM anon,authenticated;
GRANT ALL ON public.app_reorder_requests TO service_role;

CREATE OR REPLACE FUNCTION public.findez_reorder_after_stock() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 -- A request is created once per low-stock cycle. Approval does not purchase or
 -- change stock; dismissing cannot immediately generate another identical request.
 IF NOT NEW.reorder_enabled OR NEW.quantity>NEW.reorder_threshold THEN
  NEW.reorder_armed:=true;
 ELSIF NEW.quantity>=0 AND (OLD.reorder_enabled=false OR NEW.reorder_armed) THEN
  INSERT INTO public.app_reorder_requests(item_id,inventory_id,item_name,quantity,threshold,stock_at_request,unit_price,currency)
  VALUES(NEW.item_id,NEW.inventory_id,NEW.name,NEW.reorder_quantity,NEW.reorder_threshold,NEW.quantity,NEW.unit_price,NEW.currency)
  ON CONFLICT (item_id) WHERE status IN ('pending','approved') DO NOTHING;
  NEW.reorder_armed:=false;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.findez_reorder_after_stock() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS reorder_stock_change ON public.items;
CREATE TRIGGER reorder_stock_change BEFORE UPDATE OF quantity,reorder_enabled,reorder_threshold,reorder_quantity
 ON public.items FOR EACH ROW EXECUTE FUNCTION public.findez_reorder_after_stock();

CREATE OR REPLACE FUNCTION public.findez_world_item_snapshot(p_actor uuid,p_inventory uuid,p_item uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE target public.items;
BEGIN
 PERFORM public.findez_lock_inventory_authority(p_inventory,p_actor);
 IF NOT coalesce(public.findez_inventory_role(p_inventory,p_actor) IN ('owner','admin','editor'),false) THEN RAISE insufficient_privilege; END IF;
 SELECT * INTO STRICT target FROM public.items WHERE inventory_id=p_inventory AND item_id=p_item;
 RETURN jsonb_build_object('item',to_jsonb(target),'snapshot',public.findez_chat_item_fingerprint(to_jsonb(target)));
END $$;
REVOKE ALL ON FUNCTION public.findez_world_item_snapshot(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_world_item_snapshot(uuid,uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.findez_world_item_change(p_actor uuid,p_world text,p_inventory uuid,p_action uuid,p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE message_id uuid; conversation uuid; context jsonb; action jsonb; entry jsonb; changes jsonb;
 target public.items; updated public.items; destination public.spaces; request_row public.app_reorder_requests;
 destination_inventory uuid; inv public.app_inventories; receipt jsonb; headers jsonb; field text; affected integer;
BEGIN
 IF p_decision NOT IN ('read','confirm','cancel') THEN RAISE invalid_parameter_value; END IF;
 -- A single reviewed item per card keeps moves, stock receipts and edits atomic.
 SELECT m.id,m.conversation_id,m.answer_context,a.value INTO STRICT message_id,conversation,context,action
 FROM public.messages m JOIN public.conversations c ON c.id=m.conversation_id
 CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(m.answer_context->'pending_actions')='array'
  THEN m.answer_context->'pending_actions' ELSE '[]'::jsonb END) a(value)
 WHERE c.user_id=p_actor AND c.world_key=p_world AND m.role='assistant' AND a.value->>'id'=p_action::text
 FOR UPDATE OF m;
 IF action->>'world' IS DISTINCT FROM p_world OR action->>'inventory_id' IS DISTINCT FROM p_inventory::text
  OR action->'version' IS DISTINCT FROM '2'::jsonb OR NOT coalesce(action->>'operation' IN ('edit','move','reorder'),false)
  OR NOT coalesce(action->>'status' IN ('pending','confirmed','cancelled'),false) THEN RAISE check_violation; END IF;
 entry:=action->'items'->0;
 destination_inventory:=CASE WHEN action->>'operation'='move' THEN coalesce((entry->>'target_inventory_id')::uuid,(action->'receipt'->'items'->0->>'inventory_id')::uuid) ELSE p_inventory END;
 -- Deterministic authority lock order for opposing concurrent moves.
 PERFORM public.findez_lock_inventory_authority(least(p_inventory,destination_inventory),p_actor);
 IF destination_inventory<>p_inventory THEN
  PERFORM public.findez_lock_inventory_authority(greatest(p_inventory,destination_inventory),p_actor);
 END IF;
 IF NOT public.findez_world_inventory_matches(p_actor,p_world,p_inventory) THEN RAISE insufficient_privilege; END IF;
 IF p_decision='confirm' AND (NOT coalesce(public.findez_inventory_role(p_inventory,p_actor) IN ('owner','admin','editor'),false)
  OR NOT public.findez_world_inventory_matches(p_actor,p_world,destination_inventory)
  OR NOT coalesce(public.findez_inventory_role(destination_inventory,p_actor) IN ('owner','admin','editor'),false)) THEN RAISE insufficient_privilege; END IF;
 IF p_decision='read' OR action->>'status'<>'pending' THEN RETURN action||jsonb_build_object('conversation_id',conversation); END IF;
 IF p_decision='cancel' THEN action:=action||jsonb_build_object('status','cancelled');
 ELSE
  IF jsonb_typeof(action->'items') IS DISTINCT FROM 'array' OR jsonb_array_length(action->'items')<>1
   OR jsonb_typeof(action->'expires_at') IS DISTINCT FROM 'string' OR (action->>'expires_at')::timestamptz<now()
   OR octet_length(action::text)>32768 THEN RAISE check_violation; END IF;
  SELECT * INTO STRICT target FROM public.items WHERE item_id=(entry->>'item_id')::uuid AND inventory_id=p_inventory FOR UPDATE;
  IF entry->>'snapshot' IS DISTINCT FROM public.findez_chat_item_fingerprint(to_jsonb(target)) THEN RAISE check_violation; END IF;
  headers:=coalesce(nullif(current_setting('request.headers',true),'')::jsonb,'{}');
  PERFORM set_config('request.headers',(headers||jsonb_build_object('x-findez-actor',p_actor))::text,true);
  IF action->>'operation'='edit' THEN
   changes:=entry->'changes';
   IF jsonb_typeof(changes) IS DISTINCT FROM 'object' OR changes='{}'::jsonb THEN RAISE check_violation; END IF;
   FOR field IN SELECT jsonb_object_keys(changes) LOOP
    IF field NOT IN ('name','category','subcategory','brand','part_number','barcode','notes','purchase_source','quantity',
      'unit_price','currency','expires_on','reorder_enabled','reorder_threshold','reorder_quantity') THEN RAISE check_violation; END IF;
    IF field IN ('name','category') AND (jsonb_typeof(changes->field) IS DISTINCT FROM 'string' OR nullif(btrim(changes->>field),'') IS NULL OR length(changes->>field)>200) THEN RAISE check_violation; END IF;
    IF field IN ('quantity','reorder_threshold','reorder_quantity') AND changes->field<>'null'::jsonb AND
      (jsonb_typeof(changes->field) IS DISTINCT FROM 'number' OR (changes->>field)::numeric<>trunc((changes->>field)::numeric)) THEN RAISE check_violation; END IF;
   END LOOP;
   updated:=jsonb_populate_record(target,changes);
   IF updated.quantity IS NULL OR (changes ? 'quantity' AND updated.quantity NOT BETWEEN 0 AND 1000000) OR updated.reorder_enabled IS NULL
    OR length(coalesce(updated.notes,''))>2000 THEN RAISE check_violation; END IF;
   -- Do not reduce stock below quantities already allocated to project kits.
   IF changes ? 'quantity' AND updated.quantity<coalesce((SELECT sum(quantity) FROM public.project_kit_reservations WHERE inventory_item_id=target.item_id),0) THEN RAISE check_violation; END IF;
   UPDATE public.items SET name=updated.name,category=updated.category,subcategory=updated.subcategory,
    brand=updated.brand,part_number=updated.part_number,barcode=updated.barcode,notes=updated.notes,purchase_source=updated.purchase_source,
    quantity=updated.quantity,unit_price=updated.unit_price,currency=updated.currency,expires_on=updated.expires_on,
    reorder_enabled=updated.reorder_enabled,reorder_threshold=updated.reorder_threshold,reorder_quantity=updated.reorder_quantity
    WHERE item_id=target.item_id RETURNING * INTO updated;
  ELSIF action->>'operation'='move' THEN
   SELECT * INTO STRICT destination FROM public.spaces WHERE id=(entry->>'target_space_id')::uuid AND inventory_id=destination_inventory
    AND name=entry->>'target_location' FOR SHARE;
   -- Keep external project allocations intact; the user releases these before moving.
   IF EXISTS(SELECT 1 FROM public.project_kit_reservations WHERE inventory_item_id=target.item_id) THEN RAISE check_violation; END IF;
   IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.items'::regclass AND attname='bin_id' AND NOT attisdropped) THEN
    EXECUTE 'UPDATE public.items SET bin_id=NULL WHERE item_id=$1' USING target.item_id;
   END IF;
   UPDATE public.items SET inventory_id=destination_inventory,space_id=destination.id,location=destination.name
    WHERE item_id=target.item_id RETURNING * INTO updated;
   UPDATE public.documents SET inventory_id=destination_inventory WHERE item_id=target.item_id;
   UPDATE public.item_events SET inventory_id=destination_inventory WHERE item_id=target.item_id;
   UPDATE public.checkouts SET inventory_id=destination_inventory WHERE item_id=target.item_id;
   IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.checkouts'::regclass AND attname='space_name' AND NOT attisdropped) THEN
    EXECUTE 'UPDATE public.checkouts SET space_name=$1 WHERE item_id=$2' USING destination.name,target.item_id;
   END IF;
   UPDATE public.capture_reviews SET inventory_id=destination_inventory,space_id=destination.id WHERE resolved_item_id=target.item_id;
   UPDATE public.app_reorder_requests SET inventory_id=destination_inventory WHERE item_id=target.item_id;
  ELSE
   SELECT * INTO STRICT request_row FROM public.app_reorder_requests WHERE id=(entry->>'request_id')::uuid
    AND item_id=target.item_id AND inventory_id=p_inventory FOR UPDATE;
   IF request_row.status IS DISTINCT FROM entry->>'request_status' OR to_jsonb(request_row.quantity) IS DISTINCT FROM entry->'request_quantity'
    OR NOT coalesce((request_row.status='pending' AND entry->>'next_status' IN ('approved','dismissed'))
      OR (request_row.status='approved' AND entry->>'next_status' IN ('received','dismissed')),false) THEN RAISE check_violation; END IF;
   UPDATE public.app_reorder_requests SET status=entry->>'next_status',decided_at=now(),decided_by=p_actor WHERE id=request_row.id;
   IF entry->>'next_status'='received' THEN
    IF target.quantity<0 OR target.quantity+request_row.quantity>1000000 THEN RAISE check_violation; END IF;
    UPDATE public.items SET quantity=quantity+request_row.quantity WHERE item_id=target.item_id RETURNING * INTO updated;
   ELSE updated:=target;
   END IF;
  END IF;
  receipt:=jsonb_build_object('operation',action->>'operation','count',1,'confirmed_at',now(),
   'items',jsonb_build_array(jsonb_build_object('item_id',updated.item_id,'name',updated.name,'quantity',CASE WHEN updated.quantity>=0 THEN updated.quantity ELSE NULL END,
    'location',coalesce(updated.location,'Unsorted'),'details',entry->'details','inventory_id',updated.inventory_id)));
  INSERT INTO public.item_events(event_id,item_id,user_id,inventory_id,event_type,content)
   VALUES(gen_random_uuid(),updated.item_id,p_actor,updated.inventory_id,'note',
    'Reviewed Chat '||(action->>'operation')||': '||coalesce((entry->'details')::text,''));
  SELECT * INTO STRICT inv FROM public.app_inventories WHERE inventory_id=updated.inventory_id;
  INSERT INTO public.app_access_audit(actor_id,team_id,inventory_id,action,target_id,changes)
   VALUES(p_actor,inv.team_id,updated.inventory_id,'chat_item_'||(action->>'operation'),updated.item_id,
    jsonb_build_object('source_inventory',p_inventory,'action_id',p_action,'details',entry->'details'));
  action:=action||jsonb_build_object('status','confirmed','receipt',receipt,'items',receipt->'items');
 END IF;
 UPDATE public.messages SET answer_context=jsonb_set(context,'{pending_actions}',
  (SELECT jsonb_agg(CASE WHEN value->>'id'=p_action::text THEN action ELSE value END) FROM jsonb_array_elements(context->'pending_actions')))
  WHERE id=message_id;
 GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>1 THEN RAISE check_violation; END IF;
 RETURN action||jsonb_build_object('conversation_id',conversation);
END $$;
REVOKE ALL ON FUNCTION public.findez_world_item_change(uuid,text,uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_world_item_change(uuid,text,uuid,uuid,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;

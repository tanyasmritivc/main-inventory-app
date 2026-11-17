-- Candidate: rehearse against a restored database before production approval.
BEGIN;
CREATE TABLE public.cad_purchase_plans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 bom_version_id uuid NOT NULL REFERENCES public.cad_bom_versions(id),
 name text NOT NULL CHECK(length(name) BETWEEN 1 AND 512),
 state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','approved','ordered','completed','cancelled')),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0),
 lines jsonb NOT NULL CHECK(jsonb_typeof(lines)='array' AND jsonb_array_length(lines) BETWEEN 1 AND 500 AND octet_length(lines::text)<=4194304),
 inventory_as_of timestamptz NOT NULL,
 created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 approved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 approved_at timestamptz,
 order_reference text CHECK(length(order_reference)<=1000),
 ordered_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,inventory_id)
);
CREATE INDEX cad_purchase_plans_inventory ON public.cad_purchase_plans(inventory_id,created_at DESC,id);
CREATE INDEX cad_purchase_plans_bom ON public.cad_purchase_plans(bom_version_id);
CREATE TABLE public.cad_purchase_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 plan_id uuid NOT NULL,
 inventory_id uuid NOT NULL,
 actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 request_id uuid NOT NULL,
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 action text NOT NULL CHECK(action IN ('create','quote','select_quote','approve','reopen','order','receive','cancel')),
 detail jsonb NOT NULL CHECK(octet_length(detail::text)<=4194304),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(plan_id,inventory_id) REFERENCES public.cad_purchase_plans(id,inventory_id) ON DELETE CASCADE,
 UNIQUE(inventory_id,request_id)
);
CREATE INDEX cad_purchase_events_plan ON public.cad_purchase_events(plan_id,created_at,id);
ALTER TABLE public.cad_purchase_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cad_purchase_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cad_purchase_plans,public.cad_purchase_events FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.cad_purchase_plans,public.cad_purchase_events TO service_role;

-- Only the JWT application workflow calls this RPC. Existing Fusion grants do
-- not gain stock or procurement permissions. All retries are actor/payload bound.
CREATE FUNCTION public.findez_cad_purchase_action(p_actor uuid,p_inventory uuid,p_request uuid,
 p_hash text,p_plan uuid,p_action text,p_expected integer,p_data jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE role_name text; old_event cad_purchase_events; plan cad_purchase_plans;
 line jsonb; quote jsonb; n integer; qty integer; stock integer; item_owner uuid; destination uuid; event_detail jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('cad-purchase:'||p_inventory::text,0));
 role_name:=coalesce(findez_inventory_role(p_inventory,p_actor),'');
 IF role_name NOT IN ('owner','admin','editor') THEN RETURN jsonb_build_object('error','forbidden'); END IF;
 IF p_action IN ('approve','order','reopen','cancel') AND role_name NOT IN ('owner','admin') THEN
  RETURN jsonb_build_object('error','approval_required'); END IF;
 SELECT * INTO old_event FROM cad_purchase_events WHERE inventory_id=p_inventory AND request_id=p_request;
 IF FOUND THEN
  IF old_event.actor_id IS DISTINCT FROM p_actor OR old_event.request_hash<>p_hash THEN
   RETURN jsonb_build_object('error','conflict'); END IF;
  RETURN jsonb_build_object('id',old_event.plan_id,'replayed',true);
 END IF;
 event_detail:=p_data;
 IF p_action='create' THEN
  IF p_plan IS NOT NULL OR NOT EXISTS(SELECT 1 FROM cad_bom_versions WHERE id=(p_data->>'bom_version_id')::uuid AND inventory_id=p_inventory)
  THEN RETURN jsonb_build_object('error','not_found'); END IF;
  IF EXISTS(SELECT 1 FROM cad_purchase_plans pp JOIN cad_bom_versions old ON old.id=pp.bom_version_id
    JOIN cad_bom_versions chosen ON chosen.project_id=old.project_id
    WHERE pp.inventory_id=p_inventory AND chosen.id=(p_data->>'bom_version_id')::uuid
    AND pp.state IN ('draft','approved','ordered'))
  THEN RETURN jsonb_build_object('error','active_plan'); END IF;
  IF (SELECT count(*) FROM cad_purchase_plans WHERE inventory_id=p_inventory AND state IN ('draft','approved','ordered'))>=200
  THEN RETURN jsonb_build_object('error','limit'); END IF;
  INSERT INTO cad_purchase_plans(inventory_id,bom_version_id,name,lines,inventory_as_of,created_by)
  VALUES(p_inventory,(p_data->>'bom_version_id')::uuid,p_data->>'name',p_data->'lines',(p_data->>'inventory_as_of')::timestamptz,p_actor)
  RETURNING * INTO plan;
 ELSE
  SELECT * INTO plan FROM cad_purchase_plans WHERE id=p_plan AND inventory_id=p_inventory FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error','not_found'); END IF;
  IF plan.revision IS DISTINCT FROM p_expected THEN RETURN jsonb_build_object('error','stale'); END IF;
  IF p_action IN ('quote','select_quote','receive') THEN
   SELECT value,ordinality::integer-1 INTO line,n FROM jsonb_array_elements(plan.lines) WITH ORDINALITY
   WHERE value->>'id'=p_data->>'line_id';
   IF line IS NULL THEN RETURN jsonb_build_object('error','not_found'); END IF;
  END IF;
  IF p_action='quote' AND plan.state='draft' THEN
   IF jsonb_array_length(line->'quotes')>=30 THEN RETURN jsonb_build_object('error','limit'); END IF;
   line:=jsonb_set(line,'{quotes}',(line->'quotes')||jsonb_build_array(p_data->'quote'));
   plan.lines:=jsonb_set(plan.lines,ARRAY[n::text],line);
  ELSIF p_action='select_quote' AND plan.state='draft' THEN
   SELECT value INTO quote FROM jsonb_array_elements(line->'quotes') WHERE value->>'id'=p_data->>'quote_id';
   IF quote IS NULL OR (quote->>'valid_until')::timestamptz<=now() OR quote->>'availability'='out_of_stock'
   THEN RETURN jsonb_build_object('error','quote_unavailable'); END IF;
   line:=jsonb_set(line,'{selected_quote}',quote);
   plan.lines:=jsonb_set(plan.lines,ARRAY[n::text],line);
  ELSIF p_action='approve' AND plan.state='draft' THEN
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(plan.lines) l WHERE l->'selected_quote'='null'::jsonb OR l->'selected_quote' IS NULL
    OR (l->'selected_quote'->>'valid_until')::timestamptz<=now() OR l->'selected_quote'->>'availability'='out_of_stock')
   THEN RETURN jsonb_build_object('error','quote_unavailable'); END IF;
   plan.state:='approved'; plan.approved_by:=p_actor; plan.approved_at:=now();
  ELSIF p_action='reopen' AND plan.state='approved' THEN
   plan.state:='draft'; plan.approved_by:=NULL; plan.approved_at:=NULL;
  ELSIF p_action='order' AND plan.state='approved' THEN
   IF nullif(btrim(p_data->>'order_reference'),'') IS NULL THEN RETURN jsonb_build_object('error','invalid'); END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(plan.lines) l WHERE (l->'selected_quote'->>'valid_until')::timestamptz<=now())
   THEN RETURN jsonb_build_object('error','quote_unavailable'); END IF;
   plan.state:='ordered'; plan.order_reference:=p_data->>'order_reference'; plan.ordered_at:=now();
  ELSIF p_action='receive' AND plan.state='ordered' THEN
   IF p_data->>'identity_confirmed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('error','invalid'); END IF;
   qty:=(p_data->>'quantity')::integer; destination:=(p_data->>'item_id')::uuid;
   IF qty IS NULL OR qty<1 OR qty>(line->'selected_quote'->'estimate'->>'order_quantity')::integer-(line->>'received')::integer
   THEN RETURN jsonb_build_object('error','over_receipt'); END IF;
   SELECT quantity,user_id INTO stock,item_owner FROM items WHERE item_id=destination AND inventory_id=p_inventory FOR UPDATE;
   IF NOT FOUND THEN RETURN jsonb_build_object('error','not_found'); END IF;
   IF stock IS NULL OR stock<0 OR stock>1000000000-qty THEN RETURN jsonb_build_object('error','invalid_stock'); END IF;
   -- Preserve existing audit triggers, with the explicitly authorized actor.
   PERFORM set_config('request.headers',(coalesce(nullif(current_setting('request.headers',true),''),'{}')::jsonb||jsonb_build_object('x-findez-actor',p_actor))::text,true);
   UPDATE items SET quantity=quantity+qty WHERE item_id=destination AND inventory_id=p_inventory;
   INSERT INTO item_events(item_id,user_id,inventory_id,event_type,content,quantity_delta)
   VALUES(destination,item_owner,p_inventory,'restock','Received CAD purchase plan '||plan.id::text,qty);
   line:=jsonb_set(line,'{received}',to_jsonb((line->>'received')::integer+qty));
   plan.lines:=jsonb_set(plan.lines,ARRAY[n::text],line);
   event_detail:=p_data||jsonb_build_object('stock_before',stock,'stock_after',stock+qty);
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(plan.lines) l WHERE (l->>'received')::integer<(l->'selected_quote'->'estimate'->>'order_quantity')::integer)
   THEN plan.state:='completed'; END IF;
  ELSIF p_action='cancel' AND plan.state IN ('draft','approved') THEN
   plan.state:='cancelled';
  ELSE RETURN jsonb_build_object('error','transition');
  END IF;
  UPDATE cad_purchase_plans SET state=plan.state,revision=revision+1,lines=plan.lines,
   approved_by=plan.approved_by,approved_at=plan.approved_at,order_reference=plan.order_reference,
   ordered_at=plan.ordered_at,updated_at=now() WHERE id=plan.id;
 END IF;
 INSERT INTO cad_purchase_events(plan_id,inventory_id,actor_id,request_id,request_hash,action,detail)
 VALUES(plan.id,p_inventory,p_actor,p_request,p_hash,p_action,event_detail);
 RETURN jsonb_build_object('id',plan.id,'replayed',false);
END $$;
REVOKE ALL ON FUNCTION public.findez_cad_purchase_action(uuid,uuid,uuid,text,uuid,text,integer,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_cad_purchase_action(uuid,uuid,uuid,text,uuid,text,integer,jsonb) TO service_role;
COMMIT;

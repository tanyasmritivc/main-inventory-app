BEGIN;

CREATE TABLE public.supplier_order_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.app_organizations ON DELETE CASCADE,
  supplier text NOT NULL, supplier_name text NOT NULL, digest text NOT NULL, filename text NOT NULL,
  reviewed_lines jsonb NOT NULL, historical boolean NOT NULL, source_bytes bytea NOT NULL,
  imported_by uuid NOT NULL, imported_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, digest)
);
CREATE TABLE public.supplier_order_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.app_organizations ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES public.supplier_order_documents ON DELETE CASCADE,
  supplier text NOT NULL, order_number text NOT NULL, line_key text NOT NULL,
  sku text NOT NULL, name text NOT NULL, purchase_quantity integer NOT NULL CHECK (purchase_quantity > 0),
  units_per_pack integer NOT NULL CHECK (units_per_pack > 0), historical boolean NOT NULL,
  source_status text NOT NULL CHECK (source_status IN ('unknown','ordered','shipped','delivered','cancelled','returned')),
  received integer NOT NULL DEFAULT 0 CHECK (received >= 0),
  cancelled integer NOT NULL DEFAULT 0 CHECK (cancelled >= 0),
  CHECK (received::bigint + cancelled <= purchase_quantity::bigint * units_per_pack),
  UNIQUE (organization_id, supplier, order_number, line_key)
);
CREATE TABLE public.supplier_order_receipts (
  organization_id uuid NOT NULL REFERENCES public.app_organizations ON DELETE CASCADE,
  request_id uuid NOT NULL, actor_id uuid NOT NULL,
  line_id uuid NOT NULL REFERENCES public.supplier_order_lines ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('receive','already_counted','cancel')),
  inventory_id uuid, item_id uuid, space_id uuid, space_name text, quantity integer NOT NULL CHECK (quantity > 0),
  stock_before integer, stock_after integer, created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, request_id)
);
CREATE INDEX supplier_receipts_line ON public.supplier_order_receipts(line_id);
CREATE INDEX supplier_receipts_item ON public.supplier_order_receipts(inventory_id,item_id);
ALTER TABLE public.supplier_order_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_order_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_order_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.supplier_order_documents,public.supplier_order_lines,public.supplier_order_receipts FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.findez_supplier_orders(p_actor uuid,p_org uuid,p_action text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  org_role text; doc supplier_order_documents; line supplier_order_lines; receipt supplier_order_receipts;
  r jsonb; supplier_key text; hist boolean; created integer := 0; q text;
  line_rows jsonb; stock_rows jsonb; target uuid; inv uuid; req uuid; units integer;
  stock integer; owner_id uuid; recorded_space uuid; recorded_space_name text; op text; start_at integer;
BEGIN
  SELECT role INTO org_role FROM app_organization_members WHERE organization_id=p_org AND user_id=p_actor;
  IF org_role IS NULL THEN RAISE insufficient_privilege; END IF;
  IF p_action IN ('search','items') THEN
    q := lower(trim(coalesce(p_data->>'query','')));
    start_at := greatest(coalesce((p_data->>'offset')::integer,0),0);
    inv := (p_data->>'inventory_id')::uuid;
    IF p_action='items' AND (inv IS NULL OR NOT EXISTS(SELECT 1 FROM app_inventories i WHERE i.inventory_id=inv AND i.organization_id=p_org AND findez_inventory_role(inv,p_actor) IN ('editor','owner','admin'))) THEN RAISE insufficient_privilege; END IF;
    SELECT coalesce(jsonb_agg(to_jsonb(s)),'[]') INTO stock_rows FROM (
      SELECT i.item_id,i.name,i.part_number,i.quantity AS recorded_quantity,i.location,
             s.inventory_id,i.space_id,coalesce(sp.name,s.name) AS space_name
      FROM items i JOIN app_inventories s ON s.inventory_id=i.inventory_id
      LEFT JOIN spaces sp ON sp.id=i.space_id AND sp.inventory_id=i.inventory_id
      WHERE (q<>'' OR p_action='items') AND s.organization_id=p_org
        AND (inv IS NULL OR inv=s.inventory_id)
        AND (p_data->>'space_id' IS NULL OR i.space_id=(p_data->>'space_id')::uuid)
        AND findez_inventory_role(s.inventory_id,p_actor) IN ('viewer','editor','admin','owner')
        AND NOT EXISTS (SELECT 1 FROM regexp_split_to_table(q,'[[:space:]]+') t WHERE strpos(lower(concat_ws(' ',i.name,i.part_number)),t)=0)
      ORDER BY i.name,i.item_id LIMIT 51 OFFSET start_at
    ) s;
    IF p_action='items' THEN RETURN jsonb_build_object('items',stock_rows); END IF;
    SELECT coalesce(jsonb_agg(to_jsonb(s)),'[]') INTO line_rows FROM (
      SELECT l.id,d.supplier_name AS supplier,l.order_number,l.line_key,l.sku,l.name,l.purchase_quantity,l.units_per_pack,
        l.purchase_quantity*l.units_per_pack AS ordered,l.received,l.cancelled,l.historical,l.source_status,
        CASE WHEN NOT l.historical AND l.source_status NOT IN ('returned','cancelled') THEN l.purchase_quantity*l.units_per_pack-l.received-l.cancelled END AS outstanding,
        d.filename AS source_file,d.id AS source_id,
        coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.created_at) FROM (
          SELECT a.action,a.item_id,a.quantity,a.created_at,coalesce(a.space_name,s.name) AS space_name FROM supplier_order_receipts a
          LEFT JOIN app_inventories s ON a.inventory_id=s.inventory_id AND s.organization_id=p_org
          WHERE a.line_id=l.id AND (a.action='cancel' OR findez_inventory_role(s.inventory_id,p_actor) IN ('viewer','editor','admin','owner'))
          ORDER BY a.created_at DESC LIMIT 20) h),'[]') AS recent_receipts
      FROM supplier_order_lines l JOIN supplier_order_documents d ON d.id=l.document_id
      WHERE l.organization_id=p_org AND NOT EXISTS (SELECT 1 FROM regexp_split_to_table(q,'[[:space:]]+') t WHERE strpos(lower(concat_ws(' ',l.name,l.sku,l.supplier,l.order_number)),t)=0)
      ORDER BY d.imported_at DESC,l.id LIMIT 51 OFFSET start_at
    ) s;
    RETURN jsonb_build_object('order_lines',line_rows - 50,'recorded_inventory',stock_rows - 50,
      'has_more',jsonb_array_length(line_rows)>50 OR jsonb_array_length(stock_rows)>50,
      'can_manage',org_role IN ('owner','admin'),
      'basis','Quantities in Spaces are recorded on hand. Ordered and received are purchase history. Outstanding is open order quantity. Never sum those columns with stock. A text match does not establish identity or origin.');
  END IF;
  IF org_role NOT IN ('owner','admin') THEN RAISE insufficient_privilege; END IF;
  IF p_action='fields' THEN
    SELECT x INTO STRICT r FROM supplier_order_lines l JOIN supplier_order_documents d ON d.id=l.document_id
    CROSS JOIN LATERAL jsonb_array_elements(d.reviewed_lines) x
    WHERE l.organization_id=p_org AND l.id=(p_data->>'id')::uuid AND x->>'order'=l.order_number AND x->>'line'=l.line_key;
    RETURN jsonb_build_object('file',r->>'source_file','sheet',r->>'source_sheet','row',r->'source_row','original',r->'original');
  ELSIF p_action='source' THEN
    SELECT * INTO STRICT doc FROM supplier_order_documents WHERE organization_id=p_org AND id=(p_data->>'id')::uuid;
    RETURN jsonb_build_object('filename',doc.filename,'content',encode(doc.source_bytes,'base64'));
  ELSIF p_action='import' THEN
    supplier_key := lower(trim(p_data->>'supplier')); hist := (p_data->>'historical')::boolean;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_org::text||(p_data->>'digest'),0));
    PERFORM pg_advisory_xact_lock(hashtextextended(p_org::text||supplier_key,0));
    SELECT * INTO doc FROM supplier_order_documents WHERE organization_id=p_org AND digest=p_data->>'digest';
    IF FOUND THEN
      IF doc.supplier<>supplier_key OR (SELECT jsonb_agg(CASE WHEN x->>'source_file'=doc.filename THEN x-'source_file' ELSE x END ORDER BY x->>'order',x->>'line') FROM jsonb_array_elements(doc.reviewed_lines) x)
          IS DISTINCT FROM (SELECT jsonb_agg(CASE WHEN x->>'source_file'=p_data->>'filename' THEN x-'source_file' ELSE x END ORDER BY x->>'order',x->>'line') FROM jsonb_array_elements(p_data->'rows') x)
          OR doc.historical<>hist THEN RAISE serialization_failure; END IF;
      RETURN jsonb_build_object('created',0,'duplicate',true,'document_id',doc.id);
    END IF;
    INSERT INTO supplier_order_documents(organization_id,supplier,supplier_name,digest,filename,reviewed_lines,historical,source_bytes,imported_by)
    VALUES(p_org,supplier_key,trim(p_data->>'supplier'),p_data->>'digest',p_data->>'filename',p_data->'rows',hist,decode(p_data->>'content','base64'),p_actor) RETURNING * INTO doc;
    FOR r IN SELECT value FROM jsonb_array_elements(doc.reviewed_lines) LOOP
      SELECT * INTO line FROM supplier_order_lines WHERE organization_id=p_org AND supplier=supplier_key AND order_number=r->>'order' AND line_key=r->>'line';
      IF FOUND THEN
        IF (line.name,line.sku,line.purchase_quantity,line.units_per_pack,line.historical,line.source_status) IS DISTINCT FROM
           (r->>'name',r->>'sku',(r->>'quantity')::integer,(r->>'pack')::integer,hist,r->>'status') THEN RAISE serialization_failure; END IF;
      ELSE
        INSERT INTO supplier_order_lines(organization_id,document_id,supplier,order_number,line_key,sku,name,purchase_quantity,units_per_pack,historical,source_status)
        VALUES(p_org,doc.id,supplier_key,r->>'order',r->>'line',r->>'sku',r->>'name',(r->>'quantity')::integer,(r->>'pack')::integer,hist,r->>'status');
        created := created+1;
      END IF;
    END LOOP;
    RETURN jsonb_build_object('created',created,'duplicate',false,'document_id',doc.id);
  ELSIF p_action='receipt' THEN
    req := (p_data->>'request_id')::uuid; target := (p_data->>'item_id')::uuid; inv := (p_data->>'inventory_id')::uuid;
    units := (p_data->>'quantity')::integer; op := p_data->>'action';
    IF units IS NULL OR units<1 OR op NOT IN ('receive','already_counted','cancel') THEN RAISE check_violation; END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_org::text||req::text,0));
    IF op<>'cancel' AND NOT EXISTS(SELECT 1 FROM app_inventories i WHERE i.inventory_id=inv AND i.organization_id=p_org AND findez_inventory_role(inv,p_actor) IN ('editor','owner','admin')) THEN RAISE insufficient_privilege; END IF;
    SELECT * INTO receipt FROM supplier_order_receipts WHERE organization_id=p_org AND request_id=req;
    IF FOUND THEN
      IF (receipt.actor_id,receipt.line_id,receipt.quantity,receipt.action,receipt.item_id,receipt.inventory_id) IS DISTINCT FROM
         (p_actor,(p_data->>'line_id')::uuid,units,op,target,inv) THEN RAISE serialization_failure; END IF;
      IF p_data->>'space_id' IS NOT NULL AND receipt.space_id IS DISTINCT FROM (p_data->>'space_id')::uuid THEN RAISE serialization_failure; END IF;
      RETURN to_jsonb(receipt);
    END IF;
    SELECT * INTO STRICT line FROM supplier_order_lines WHERE organization_id=p_org AND id=(p_data->>'line_id')::uuid FOR UPDATE;
    IF line.source_status IN ('cancelled','returned') OR (line.historical AND op='receive') OR units>line.purchase_quantity*line.units_per_pack-line.received-line.cancelled THEN RAISE check_violation; END IF;
    IF op<>'cancel' THEN
      SELECT i.quantity,i.user_id,i.space_id,sp.name INTO STRICT stock,owner_id,recorded_space,recorded_space_name
      FROM items i LEFT JOIN spaces sp ON sp.id=i.space_id AND sp.inventory_id=i.inventory_id
      WHERE i.item_id=target AND i.inventory_id=inv FOR UPDATE OF i;
      IF p_data->>'space_id' IS NOT NULL AND recorded_space IS DISTINCT FROM (p_data->>'space_id')::uuid THEN RAISE serialization_failure; END IF;
      IF op='receive' THEN
        IF stock IS NULL OR stock<0 OR stock>1000000000-units THEN RAISE check_violation; END IF;
        PERFORM set_config('request.headers',(coalesce(nullif(current_setting('request.headers',true),''),'{}')::jsonb||jsonb_build_object('x-findez-actor',p_actor))::text,true);
        UPDATE items SET quantity=quantity+units WHERE item_id=target AND inventory_id=inv;
        INSERT INTO item_events(item_id,user_id,inventory_id,event_type,content,quantity_delta)
        VALUES(target,owner_id,inv,'restock','Received supplier order line '||line.id::text,units);
      END IF;
    END IF;
    UPDATE supplier_order_lines SET received=received+CASE WHEN op='cancel' THEN 0 ELSE units END,
      cancelled=cancelled+CASE WHEN op='cancel' THEN units ELSE 0 END WHERE id=line.id;
    INSERT INTO supplier_order_receipts(organization_id,request_id,actor_id,line_id,action,inventory_id,item_id,space_id,space_name,quantity,stock_before,stock_after)
    VALUES(p_org,req,p_actor,line.id,op,inv,target,recorded_space,recorded_space_name,units,stock,CASE WHEN op='receive' THEN stock+units ELSE stock END) RETURNING * INTO receipt;
    RETURN to_jsonb(receipt);
  END IF;
  RAISE check_violation;
END $$;
REVOKE ALL ON FUNCTION public.findez_supplier_orders(uuid,uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_supplier_orders(uuid,uuid,text,jsonb) TO service_role;
-- Keep supplier SKU matches out of the BOM allocator. Distributor SKUs only
-- identify possible incoming parts until a person verifies the engineering identity.
CREATE FUNCTION public.findez_supplier_bom_orders(p_actor uuid,p_inventory uuid,p_skus text[])
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(candidate)),'[]') FROM (
   SELECT l.id AS line_id,l.sku,l.name,l.order_number,l.supplier,
     l.purchase_quantity*l.units_per_pack-l.received-l.cancelled AS outstanding
   FROM app_inventories i
   JOIN app_organization_members m ON m.organization_id=i.organization_id AND m.user_id=p_actor
   JOIN supplier_order_lines l ON l.organization_id=i.organization_id
   WHERE i.inventory_id=p_inventory AND findez_inventory_role(i.inventory_id,p_actor) IN ('owner','admin','editor','viewer')
     AND l.sku<>'' AND lower(l.sku)=ANY(p_skus) AND NOT l.historical
     AND l.source_status NOT IN ('cancelled','returned') AND l.purchase_quantity*l.units_per_pack>l.received+l.cancelled
   ORDER BY l.order_number,l.id LIMIT 101
 ) candidate
$$;
REVOKE ALL ON FUNCTION public.findez_supplier_bom_orders(uuid,uuid,text[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_supplier_bom_orders(uuid,uuid,text[]) TO service_role;
COMMIT;

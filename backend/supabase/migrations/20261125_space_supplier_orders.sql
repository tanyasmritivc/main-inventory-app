BEGIN;

-- Keep the inventory access boundary even if the original Space is later removed.
-- An unassigned legacy order retains the original organization-level visibility.
ALTER TABLE public.supplier_order_documents
  ADD COLUMN order_space_id uuid REFERENCES public.spaces(id) ON DELETE SET NULL,
  ADD COLUMN order_inventory_id uuid;
CREATE INDEX supplier_order_documents_space ON public.supplier_order_documents(organization_id, order_space_id);
CREATE INDEX supplier_order_lines_document ON public.supplier_order_lines(document_id);

CREATE FUNCTION public.findez_order_text(value text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT trim(regexp_replace(regexp_replace(lower(coalesce(value,'')), '([0-9])[[:space:]]*[x×][[:space:]]*([0-9])', '\1x\2', 'g'), '[[:space:]]+', ' ', 'g'))
$$;

CREATE FUNCTION public.findez_order_search(value text, query text) RETURNS boolean
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT NOT EXISTS (
    SELECT FROM regexp_split_to_table(public.findez_order_text(query), ' ') t
    WHERE CASE WHEN t ~ '[0-9]' THEN NOT EXISTS (
      SELECT FROM regexp_split_to_table(public.findez_order_text(value), '[^[:alnum:]._-]+') v
      WHERE v=t OR (v LIKE t||'x%' AND t ~ '^m[0-9]+$')
    ) ELSE strpos(public.findez_order_text(value),t)=0 END
  )
$$;

CREATE OR REPLACE FUNCTION public.findez_supplier_orders(p_actor uuid,p_org uuid,p_action text,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  anchor uuid; anchor_inventory uuid; anchor_role text;
  org_role text; doc supplier_order_documents; line supplier_order_lines; receipt supplier_order_receipts;
  r jsonb; supplier_key text; hist boolean; created integer := 0; q text;
  line_rows jsonb; stock_rows jsonb; target uuid; inv uuid; req uuid; units integer;
  stock integer; owner_id uuid; recorded_space uuid; recorded_space_name text; op text; start_at integer;
BEGIN
  SELECT role INTO org_role FROM app_organization_members WHERE organization_id=p_org AND user_id=p_actor;
  IF org_role IS NULL THEN RAISE insufficient_privilege; END IF;
  IF p_action IN ('search','preview','import') THEN
    anchor := (p_data->>'space_id')::uuid;
    IF anchor IS NOT NULL THEN
      SELECT sp.inventory_id, findez_inventory_role(sp.inventory_id,p_actor)
        INTO anchor_inventory,anchor_role FROM spaces sp
        JOIN app_inventories i ON i.inventory_id=sp.inventory_id
        WHERE sp.id=anchor AND i.organization_id=p_org FOR SHARE OF sp,i;
      IF coalesce(anchor_role,'') NOT IN ('viewer','editor','owner','admin')
         OR (p_action IN ('import','preview') AND anchor_role='viewer') THEN RAISE insufficient_privilege; END IF;
    END IF;
  END IF;
  IF p_action IN ('search','items') THEN
    q := lower(trim(coalesce(p_data->>'query','')));
    start_at := greatest(coalesce((p_data->>'offset')::integer,0),0);
    inv := (p_data->>'inventory_id')::uuid;
    IF p_action='items' AND (inv IS NULL OR NOT EXISTS(SELECT 1 FROM app_inventories i WHERE i.inventory_id=inv AND i.organization_id=p_org AND findez_inventory_role(inv,p_actor) IN ('editor','owner','admin'))) THEN RAISE insufficient_privilege; END IF;
    SELECT coalesce(jsonb_agg(to_jsonb(s)),'[]') INTO stock_rows FROM (
      SELECT i.item_id,i.name,i.part_number,i.quantity AS recorded_quantity,coalesce(b.name,i.location) AS location,
             s.inventory_id,i.space_id,coalesce(sp.name,s.name) AS space_name
      FROM items i JOIN app_inventories s ON s.inventory_id=i.inventory_id
      LEFT JOIN spaces sp ON sp.id=i.space_id AND sp.inventory_id=i.inventory_id
      LEFT JOIN bins b ON b.id=i.bin_id AND b.space_id=sp.id
      WHERE (q<>'' OR p_action='items') AND s.organization_id=p_org
        AND (inv IS NULL OR inv=s.inventory_id)
        AND (p_data->>'space_id' IS NULL OR i.space_id=(p_data->>'space_id')::uuid)
        AND findez_inventory_role(s.inventory_id,p_actor) IN ('viewer','editor','admin','owner')
        AND findez_order_search(concat_ws(' ',i.name,i.part_number),q)
      ORDER BY i.name,i.item_id LIMIT 51 OFFSET start_at
    ) s;
    IF p_action='items' THEN RETURN jsonb_build_object('items',stock_rows); END IF;
    SELECT coalesce(jsonb_agg(to_jsonb(s)),'[]') INTO line_rows FROM (
      SELECT l.id,d.supplier_name AS supplier,l.order_number,l.line_key,l.sku,l.name,l.purchase_quantity,l.units_per_pack,
        l.purchase_quantity*l.units_per_pack AS ordered,l.received,l.cancelled,l.historical,l.source_status,
        CASE WHEN NOT l.historical AND l.source_status NOT IN ('returned','cancelled') THEN l.purchase_quantity*l.units_per_pack-l.received-l.cancelled END AS outstanding,
        d.filename AS source_file,d.id AS source_id,d.order_space_id,os.name AS order_space_name,
        coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.created_at) FROM (
          SELECT a.action,a.item_id,a.quantity,a.created_at,coalesce(a.space_name,s.name) AS space_name FROM supplier_order_receipts a
          LEFT JOIN app_inventories s ON a.inventory_id=s.inventory_id AND s.organization_id=p_org
          WHERE a.line_id=l.id AND (a.action='cancel' OR findez_inventory_role(s.inventory_id,p_actor) IN ('viewer','editor','admin','owner'))
          ORDER BY a.created_at DESC LIMIT 20) h),'[]') AS recent_receipts
      FROM supplier_order_lines l JOIN supplier_order_documents d ON d.id=l.document_id
      LEFT JOIN spaces os ON os.id=d.order_space_id
      WHERE l.organization_id=p_org AND (anchor IS NULL OR d.order_space_id=anchor)
        AND (d.order_inventory_id IS NULL OR findez_inventory_role(d.order_inventory_id,p_actor) IN ('viewer','editor','owner','admin'))
        AND findez_order_search(concat_ws(' ',l.name,l.sku,l.supplier,l.order_number),q)
      ORDER BY d.imported_at DESC,l.id LIMIT 51 OFFSET start_at
    ) s;
    RETURN jsonb_build_object('order_lines',line_rows - 50,'recorded_inventory',stock_rows - 50,
      'has_more',jsonb_array_length(line_rows)>50 OR jsonb_array_length(stock_rows)>50,
      'can_manage',org_role IN ('owner','admin') AND (anchor IS NULL OR anchor_role<>'viewer'), 'space_orders_supported',true, 'order_scope_id',anchor,
      'basis','Quantities in Spaces are recorded on hand. Ordered and received are purchase history. Outstanding is open order quantity. Never sum those columns with stock. A text match does not establish identity or origin.');
  END IF;
  IF org_role NOT IN ('owner','admin') THEN RAISE insufficient_privilege; END IF;
  IF p_action='preview' THEN
    SELECT * INTO doc FROM supplier_order_documents WHERE organization_id=p_org AND digest=p_data->>'digest';
    IF FOUND THEN
      -- Reveal no source or destination metadata outside the caller's inventory grant.
      RETURN jsonb_build_object('duplicate',true,'matches','[]'::jsonb);
    END IF;
    SELECT coalesce(jsonb_agg(to_jsonb(m)), '[]') INTO stock_rows FROM (
      SELECT r.row->>'name' AS name,r.row->>'sku' AS sku, candidate.*
      FROM (SELECT DISTINCT jsonb_build_object('name',v->>'name','sku',v->>'sku') AS row
            FROM jsonb_array_elements(p_data->'rows') v) r
      CROSS JOIN LATERAL (
        SELECT i.item_id,i.name AS item_name,i.quantity AS recorded_quantity,coalesce(b.name,i.location) AS location,
               coalesce(sp.name,a.name) AS space_name,i.space_id
        FROM items i JOIN app_inventories a ON a.inventory_id=i.inventory_id
        LEFT JOIN spaces sp ON sp.id=i.space_id AND sp.inventory_id=i.inventory_id
        LEFT JOIN bins b ON b.id=i.bin_id AND b.space_id=sp.id
        WHERE a.organization_id=p_org AND findez_inventory_role(a.inventory_id,p_actor) IN ('viewer','editor','admin','owner')
        AND ((nullif(trim(r.row->>'sku'),'') IS NOT NULL AND lower(trim(i.part_number))=lower(trim(r.row->>'sku')))
             OR (nullif(trim(r.row->>'name'),'') IS NOT NULL AND findez_order_text(i.name)=findez_order_text(r.row->>'name')))
        ORDER BY (i.space_id=anchor) DESC NULLS LAST,i.item_id LIMIT 5
      ) candidate
    ) m;
    RETURN jsonb_build_object('duplicate',false,'matches',stock_rows);
  ELSIF p_action='fields' THEN
    SELECT x INTO STRICT r FROM supplier_order_lines l JOIN supplier_order_documents d ON d.id=l.document_id
    CROSS JOIN LATERAL jsonb_array_elements(d.reviewed_lines) x
    WHERE l.organization_id=p_org AND l.id=(p_data->>'id')::uuid AND (d.order_inventory_id IS NULL OR findez_inventory_role(d.order_inventory_id,p_actor) IN ('viewer','editor','admin','owner')) AND x->>'order'=l.order_number AND x->>'line'=l.line_key;
    RETURN jsonb_build_object('file',r->>'source_file','sheet',r->>'source_sheet','row',r->'source_row','original',r->'original');
  ELSIF p_action='source' THEN
    SELECT * INTO STRICT doc FROM supplier_order_documents d WHERE organization_id=p_org AND id=(p_data->>'id')::uuid AND (d.order_inventory_id IS NULL OR findez_inventory_role(d.order_inventory_id,p_actor) IN ('viewer','editor','admin','owner'));
    RETURN jsonb_build_object('filename',doc.filename,'content',encode(doc.source_bytes,'base64'));
  ELSIF p_action='import' THEN
    supplier_key := lower(trim(p_data->>'supplier')); hist := (p_data->>'historical')::boolean;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_org::text||(p_data->>'digest'),0));
    PERFORM pg_advisory_xact_lock(hashtextextended(p_org::text||supplier_key,0));
    SELECT * INTO doc FROM supplier_order_documents WHERE organization_id=p_org AND digest=p_data->>'digest';
    IF FOUND THEN
      IF doc.order_inventory_id IS NOT NULL AND coalesce(findez_inventory_role(doc.order_inventory_id,p_actor),'') NOT IN ('viewer','editor','owner','admin') THEN RAISE insufficient_privilege; END IF;
      IF (anchor IS NOT NULL AND doc.order_space_id IS DISTINCT FROM anchor) OR doc.supplier<>supplier_key OR (SELECT jsonb_agg(CASE WHEN x->>'source_file'=doc.filename THEN x-'source_file' ELSE x END ORDER BY x->>'order',x->>'line') FROM jsonb_array_elements(doc.reviewed_lines) x)
          IS DISTINCT FROM (SELECT jsonb_agg(CASE WHEN x->>'source_file'=p_data->>'filename' THEN x-'source_file' ELSE x END ORDER BY x->>'order',x->>'line') FROM jsonb_array_elements(p_data->'rows') x)
          OR doc.historical<>hist THEN RAISE serialization_failure; END IF;
      RETURN jsonb_build_object('created',0,'duplicate',true,'document_id',doc.id);
    END IF;
    INSERT INTO supplier_order_documents(order_space_id,order_inventory_id,organization_id,supplier,supplier_name,digest,filename,reviewed_lines,historical,source_bytes,imported_by)
    VALUES(anchor,anchor_inventory,p_org,supplier_key,trim(p_data->>'supplier'),p_data->>'digest',p_data->>'filename',p_data->'rows',hist,decode(p_data->>'content','base64'),p_actor) RETURNING * INTO doc;
    FOR r IN SELECT value FROM jsonb_array_elements(doc.reviewed_lines) LOOP
      SELECT * INTO line FROM supplier_order_lines WHERE organization_id=p_org AND supplier=supplier_key AND order_number=r->>'order' AND line_key=r->>'line';
      IF FOUND THEN
        IF anchor IS NOT NULL AND NOT EXISTS (SELECT FROM supplier_order_documents d WHERE d.id=line.document_id AND d.order_space_id=anchor) THEN RAISE serialization_failure; END IF;
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
    IF NOT EXISTS (SELECT FROM supplier_order_lines l JOIN supplier_order_documents d ON d.id=l.document_id WHERE l.id=(p_data->>'line_id')::uuid AND l.organization_id=p_org AND (d.order_inventory_id IS NULL OR findez_inventory_role(d.order_inventory_id,p_actor) IN ('viewer','editor','admin','owner'))) THEN RAISE insufficient_privilege; END IF;
    SELECT * INTO receipt FROM supplier_order_receipts WHERE organization_id=p_org AND request_id=req;
    IF FOUND THEN
      IF (receipt.actor_id,receipt.line_id,receipt.quantity,receipt.action,receipt.item_id,receipt.inventory_id) IS DISTINCT FROM
         (p_actor,(p_data->>'line_id')::uuid,units,op,target,inv) THEN RAISE serialization_failure; END IF;
      IF p_data->>'space_id' IS NOT NULL AND receipt.space_id IS DISTINCT FROM (p_data->>'space_id')::uuid THEN RAISE serialization_failure; END IF;
      RETURN to_jsonb(receipt);
    END IF;
    SELECT * INTO STRICT line FROM supplier_order_lines WHERE organization_id=p_org AND id=(p_data->>'line_id')::uuid FOR UPDATE;
    IF NOT EXISTS (SELECT FROM supplier_order_documents d WHERE d.id=line.document_id AND (d.order_inventory_id IS NULL OR findez_inventory_role(d.order_inventory_id,p_actor) IN ('viewer','editor','admin','owner'))) THEN RAISE insufficient_privilege; END IF;
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
CREATE OR REPLACE FUNCTION public.findez_supplier_bom_orders(p_actor uuid,p_inventory uuid,p_skus text[])
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(candidate)),'[]') FROM (
   SELECT l.id AS line_id,l.sku,l.name,l.order_number,l.supplier,
     l.purchase_quantity*l.units_per_pack-l.received-l.cancelled AS outstanding
   FROM app_inventories i
   JOIN app_organization_members m ON m.organization_id=i.organization_id AND m.user_id=p_actor
   JOIN supplier_order_lines l ON l.organization_id=i.organization_id
   JOIN supplier_order_documents d ON d.id=l.document_id
   WHERE (d.order_inventory_id IS NULL OR findez_inventory_role(d.order_inventory_id,p_actor) IN ('viewer','editor','admin','owner')) AND i.inventory_id=p_inventory AND findez_inventory_role(i.inventory_id,p_actor) IN ('owner','admin','editor','viewer')
     AND l.sku<>'' AND lower(l.sku)=ANY(p_skus) AND NOT l.historical
     AND l.source_status NOT IN ('cancelled','returned') AND l.purchase_quantity*l.units_per_pack>l.received+l.cancelled
   ORDER BY l.order_number,l.id LIMIT 101
 ) candidate
$$;
REVOKE ALL ON FUNCTION public.findez_supplier_bom_orders(uuid,uuid,text[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_supplier_bom_orders(uuid,uuid,text[]) TO service_role;
CREATE FUNCTION public.findez_space_order_summary(p_actor uuid,p_inventory uuid,p_space uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
  WITH lines AS (
    SELECT d.supplier_name AS supplier,l.order_number,l.sku,l.name,
      l.purchase_quantity*l.units_per_pack AS ordered,l.received,l.cancelled,
      CASE WHEN NOT l.historical AND l.source_status NOT IN ('returned','cancelled')
           THEN l.purchase_quantity*l.units_per_pack-l.received-l.cancelled END AS outstanding,
      (SELECT coalesce(jsonb_agg(to_jsonb(t)),'[]') FROM (
        SELECT r.item_id,r.action,r.quantity FROM supplier_order_receipts r
        WHERE r.line_id=l.id AND r.space_id=p_space AND r.inventory_id=p_inventory
        ORDER BY r.created_at DESC LIMIT 5
      ) t) AS recent_receipts
    FROM supplier_order_documents d JOIN supplier_order_lines l ON l.document_id=d.id
    JOIN app_inventories i ON i.inventory_id=d.order_inventory_id AND i.organization_id=d.organization_id
    JOIN app_organization_members m ON m.organization_id=i.organization_id AND m.user_id=p_actor
    WHERE d.order_space_id=p_space AND i.inventory_id=p_inventory
      AND findez_inventory_role(i.inventory_id,p_actor) IN ('owner','admin','editor','viewer')
    ORDER BY d.imported_at DESC,l.id LIMIT 51
  )
  SELECT jsonb_build_object('lines',coalesce(jsonb_agg(to_jsonb(lines)), '[]'::jsonb) - 50,
                            'partial',count(*)>50) FROM lines
$$;
REVOKE ALL ON FUNCTION public.findez_space_order_summary(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_space_order_summary(uuid,uuid,uuid) TO service_role;
COMMIT;

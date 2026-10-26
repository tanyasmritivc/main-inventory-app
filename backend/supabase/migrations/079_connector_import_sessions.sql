BEGIN;
-- Private source snapshots and durable, atomic per-row import receipts.
CREATE TABLE IF NOT EXISTS public.connector_import_sessions (
 id uuid PRIMARY KEY,
 actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 inventory_id uuid NOT NULL REFERENCES public.app_inventories(inventory_id) ON DELETE CASCADE,
 share_id uuid,
 location text NOT NULL,
 filename text NOT NULL,
 source_hash text NOT NULL,
 kind text NOT NULL CHECK(kind IN ('inventory','bom')),
 tables jsonb NOT NULL CHECK(jsonb_typeof(tables)='array'),
 review jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(review)='array'),
 mapping jsonb NOT NULL DEFAULT '{}',
 decisions jsonb,
 receipts jsonb NOT NULL DEFAULT '{}',
 revision integer NOT NULL DEFAULT 0,
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','review','importing','complete')),
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT now()+interval '7 days'
);
CREATE INDEX IF NOT EXISTS connector_import_actor ON public.connector_import_sessions(actor_id,created_at DESC);
ALTER TABLE public.connector_import_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.connector_import_sessions FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.connector_import_sessions TO service_role;

CREATE OR REPLACE FUNCTION public.findez_connector_authorized(p_session uuid,p_actor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT coalesce(public.findez_actor_active(p_actor) AND s.actor_id=p_actor AND (
  public.findez_inventory_role(s.inventory_id,p_actor) IN ('owner','admin','editor') OR
  (i.access_mode='legacy' AND s.share_id IS NOT NULL AND EXISTS(
   SELECT 1 FROM public.team_shares sh JOIN public.team_members m USING(share_id)
   WHERE sh.share_id=s.share_id AND sh.owner_user_id=s.owner_id AND m.member_user_id=p_actor
    AND sh.permission='edit' AND sh.is_active AND (sh.expires_at IS NULL OR sh.expires_at>now())
    AND (sh.inventory_id IS NULL OR sh.inventory_id=s.inventory_id)
    AND lower(sh.share_name)=lower(s.location)
  ))),false)
 FROM public.connector_import_sessions s JOIN public.app_inventories i USING(inventory_id)
 WHERE s.id=p_session
$$;
REVOKE ALL ON FUNCTION public.findez_connector_authorized(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_connector_authorized(uuid,uuid) TO service_role;

-- Remove only the pre-release signature when rehearsing this migration again.
DROP FUNCTION IF EXISTS public.findez_commit_connector_import(uuid,uuid,integer,jsonb,integer,boolean);
CREATE OR REPLACE FUNCTION public.findez_commit_connector_import(p_actor uuid,p_session uuid,p_revision integer,
 p_decisions jsonb,p_item_limit integer DEFAULT NULL,p_retry_failed boolean DEFAULT false,p_quota jsonb DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE s public.connector_import_sessions; r jsonb; item jsonb; idx text; decision text;
 itemid uuid; space public.spaces; saved jsonb; receipt jsonb; count_done integer:=0; usage_count integer; quota integer;
 quota_period text:=to_char(now() AT TIME ZONE 'UTC','YYYY-MM');
 headers jsonb:=coalesce(nullif(current_setting('request.headers',true),'')::jsonb,'{}');
BEGIN
 SELECT * INTO s FROM public.connector_import_sessions WHERE id=p_session AND actor_id=p_actor FOR UPDATE;
 IF NOT FOUND OR NOT coalesce(public.findez_connector_authorized(p_session,p_actor),false) THEN RAISE insufficient_privilege; END IF;
 PERFORM public.findez_lock_inventory_authority(s.inventory_id,p_actor);
 -- Serialize imports into the same inventory, including duplicate checks.
 PERFORM 1 FROM public.app_inventories WHERE inventory_id=s.inventory_id FOR UPDATE;
 IF NOT coalesce(public.findez_connector_authorized(p_session,p_actor),false) THEN RAISE insufficient_privilege; END IF;
 IF s.kind<>'inventory' OR s.status='draft' OR s.revision<>p_revision THEN
  RAISE check_violation USING message='Review the latest preview before importing.'; END IF;
 IF s.decisions IS NULL THEN
  IF s.expires_at<now() OR jsonb_typeof(p_decisions)<>'object' THEN RAISE check_violation; END IF;
  FOR r IN SELECT value FROM jsonb_array_elements(s.review) LOOP
   idx:=r->>'index'; decision:=p_decisions->>idx;
   IF decision IS NULL OR decision NOT IN ('create','skip','create_duplicate') THEN
    RAISE check_violation USING message='Choose an action for every row.'; END IF;
   IF decision<>'skip' AND jsonb_array_length(r->'errors')>0 THEN
    RAISE check_violation USING message='Exclude invalid rows before importing.'; END IF;
   IF decision='create' AND (jsonb_array_length(r->'duplicates')>0 OR jsonb_array_length(r->'duplicate_rows')>0) THEN
    RAISE check_violation USING message='Review duplicate rows before importing.'; END IF;
  END LOOP;
  -- Counter and first batch commit together. A replay never charges again.
  quota:=(p_quota->>'limit')::integer;
  IF quota IS NOT NULL AND EXISTS(SELECT 1 FROM jsonb_each_text(p_decisions) WHERE value<>'skip') THEN
   IF p_quota->>'team_id' IS NOT NULL THEN
    SELECT imports_used INTO usage_count FROM public.increment_team_import_usage((p_quota->>'team_id')::uuid,quota_period);
   ELSE
    usage_count:=public.increment_usage_count(p_actor,'spreadsheet_import',quota_period);
   END IF;
   IF usage_count>quota THEN RAISE EXCEPTION 'CONNECTOR_IMPORT_LIMIT'; END IF;
  END IF;
  s.decisions:=p_decisions;
 ELSIF s.decisions IS DISTINCT FROM p_decisions THEN
  RAISE check_violation USING message='This import has already started with different choices.';
 END IF;
 PERFORM set_config('request.headers',(headers||jsonb_build_object('x-findez-actor',p_actor))::text,true);
 FOR r IN SELECT value FROM jsonb_array_elements(s.review) LOOP
  idx:=r->>'index'; receipt:=s.receipts->idx;
  IF receipt IS NOT NULL AND NOT (p_retry_failed AND receipt->>'status'='failed') THEN CONTINUE; END IF;
  EXIT WHEN count_done>=200;
  count_done:=count_done+1; decision:=s.decisions->>idx; item:=r->'item';
  IF decision='skip' THEN
   receipt:=jsonb_build_object('status','skipped');
  ELSE
   BEGIN
    SELECT * INTO space FROM public.spaces WHERE id=(item->>'space_id')::uuid AND inventory_id=s.inventory_id;
    IF NOT FOUND OR space.name IS DISTINCT FROM item->>'location'
       OR (s.share_id IS NOT NULL AND lower(space.name)<>lower(s.location)) THEN
     RAISE check_violation USING message='The destination changed. Start a new review.'; END IF;
    IF p_item_limit IS NOT NULL AND (SELECT count(*) FROM public.items WHERE user_id=s.owner_id)>=p_item_limit THEN
     RAISE check_violation USING message='Your item limit has been reached.'; END IF;
    IF decision='create' AND EXISTS(SELECT 1 FROM public.items i WHERE i.inventory_id=s.inventory_id AND (
      (nullif(item->>'barcode','') IS NOT NULL AND lower(btrim(i.barcode))=lower(btrim(item->>'barcode'))) OR
      (nullif(item->>'part_number','') IS NOT NULL AND lower(btrim(i.part_number))=lower(btrim(item->>'part_number')) AND lower(btrim(coalesce(i.brand,'')))=lower(btrim(coalesce(item->>'brand','')))) OR
      (lower(btrim(i.name))=lower(btrim(item->>'name')) AND lower(btrim(i.category))=lower(btrim(item->>'category')) AND lower(btrim(i.location))=lower(btrim(item->>'location'))))) THEN
     RAISE check_violation USING message='A matching item was added after preview. Start a new review.'; END IF;
    itemid:=md5('findez:connector:'||s.id||':'||idx)::uuid;
    INSERT INTO public.items(item_id,user_id,inventory_id,space_id,name,category,quantity,location,
      barcode,brand,part_number,subcategory,purchase_source,notes,import_data)
    VALUES(itemid,s.owner_id,s.inventory_id,space.id,item->>'name',item->>'category',
      (item->>'quantity')::integer,space.name,nullif(item->>'barcode',''),nullif(item->>'brand',''),
      nullif(item->>'part_number',''),nullif(item->>'subcategory',''),nullif(item->>'purchase_source',''),
      nullif(item->>'notes',''),item->'import_data');
    receipt:=jsonb_build_object('status','imported','item_id',itemid);
   EXCEPTION WHEN check_violation THEN
    receipt:=jsonb_build_object('status','failed','message',CASE WHEN SQLERRM IN ('The destination changed. Start a new review.','Your item limit has been reached.','A matching item was added after preview. Start a new review.') THEN SQLERRM ELSE 'This row could not be saved. Check its fields before retrying.' END);
   WHEN OTHERS THEN
    receipt:=jsonb_build_object('status','failed','message','This row was not saved. Retry this import.');
   END;
  END IF;
  s.receipts:=jsonb_set(s.receipts,ARRAY[idx],receipt);
 END LOOP;
 s.status:=CASE WHEN (SELECT count(*) FROM jsonb_object_keys(s.receipts))=jsonb_array_length(s.review) THEN 'complete' ELSE 'importing' END;
 UPDATE public.connector_import_sessions SET decisions=s.decisions,receipts=s.receipts,status=s.status WHERE id=s.id;
 RETURN jsonb_build_object('id',s.id,'revision',s.revision,'status',s.status,'receipts',s.receipts);
END $$;
REVOKE ALL ON FUNCTION public.findez_commit_connector_import(uuid,uuid,integer,jsonb,integer,boolean,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.findez_commit_connector_import(uuid,uuid,integer,jsonb,integer,boolean,jsonb) TO service_role;
-- Include this owned source metadata in the existing fail-closed deletion guard.
DO $$
DECLARE definition text; marker text:='''app_reorder_requests'')';
BEGIN
 definition:=pg_get_functiondef('public.findez_delete_inventory_contents(uuid,uuid,text)'::regprocedure);
 IF position('''connector_import_sessions'')' IN definition)>0 THEN RETURN; END IF;
 IF position(marker IN definition)=0 THEN RAISE EXCEPTION 'Review inventory deletion guard before applying'; END IF;
 EXECUTE replace(definition,marker,'''app_reorder_requests'',''connector_import_sessions'')');
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

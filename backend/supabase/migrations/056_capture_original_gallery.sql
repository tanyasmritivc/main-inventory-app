-- Preserve the original while the pending Review still authorizes both photos.
-- Photo insertion and Review resolution commit or roll back together.
BEGIN;
DO $$
DECLARE definition text:=pg_get_functiondef('public.resolve_capture_review(uuid,uuid,jsonb,uuid,uuid)'::regprocedure);
 marker text:='  update public.capture_reviews';
 addition text:=$body$
  -- findez: retain original scan in item gallery (v1)
  if nullif(btrim(v_review.source_frame_url), '') is not null
     and btrim(v_review.source_frame_url) is distinct from v_item.image_url then
    insert into public.item_events(event_id,item_id,user_id,inventory_id,event_type,content,image_url)
    values(gen_random_uuid(),v_item.item_id,v_item.user_id,v_item.inventory_id,
           'photo','Original scan photo',btrim(v_review.source_frame_url));
  end if;

$body$;
BEGIN
 IF position('findez: retain original scan in item gallery (v1)' IN definition)>0 THEN RETURN; END IF;
 IF position(marker IN definition)=0 THEN RAISE EXCEPTION 'Review resolution source differs'; END IF;
 EXECUTE replace(definition,marker,addition||marker);
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;

-- Run only in the composed disposable fixture, after private_item_images.sql.
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
ALTER TABLE public.item_events ADD COLUMN IF NOT EXISTS event_type text,
 ADD COLUMN IF NOT EXISTS content text, ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
\ir ../../supabase/migrations/056_capture_original_gallery.sql
\ir ../../supabase/migrations/056_capture_original_gallery.sql
CREATE FUNCTION pg_temp.fail_original_photo() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF current_setting('findez.qa_fail_photo',true)='true' THEN RAISE check_violation USING message='Synthetic photo failure'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER qa_fail_original BEFORE INSERT ON public.item_events FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_original_photo();
DO $$
DECLARE actor uuid:='d4000000-0000-0000-0000-000000000003';
 teammate uuid:='d4000000-0000-0000-0000-000000000004';
 inv uuid; review uuid:=gen_random_uuid(); result jsonb; replay jsonb;
 source text:='https://storage.test/storage/v1/object/public/item-images/'||actor||'/original-scan.jpg';
 crop text:='https://storage.test/storage/v1/object/public/item-images/'||actor||'/crop-scan.jpg';
 payload jsonb;
BEGIN
 INSERT INTO public.team_memberships(team_id,user_id,role)
 SELECT id,teammate,'viewer' FROM permission_demo WHERE key='workspace';
 inv:=(public.findez_create_inventory(actor,(SELECT id FROM permission_demo WHERE key='workspace'),'Original gallery QA','restricted')->>'inventory_id')::uuid;
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,teammate,'viewer');
 PERFORM public.findez_register_image_preview(actor,inv,actor||'/original-scan.jpg');
 PERFORM public.findez_register_image_preview(actor,inv,actor||'/crop-scan.jpg');
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',false);
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',actor)::text,false);
 INSERT INTO public.capture_reviews(review_id,user_id,inventory_id,source_key,name,category,quantity,image_url,source_frame_url)
 VALUES(review,actor,inv,'original-gallery-qa','Uncertain bolt','Hardware',1,crop,source);
 payload:=jsonb_build_object('name','Confirmed bolt','category','Hardware','location','Unsorted','quantity',1,'image_url',crop);
 result:=public.resolve_capture_review(review,actor,payload,null,null);
 replay:=public.resolve_capture_review(review,actor,payload,null,null);
 PERFORM pg_temp.check(result->>'item_id'=replay->>'item_id','review retry returns one actual item');
 PERFORM pg_temp.check(result->>'image_url'=crop,'review keeps crop as primary');
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.item_events WHERE item_id=(result->>'item_id')::uuid AND image_url=source AND content='Original scan photo'),'review stores original exactly once');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_image_previews WHERE storage_path IN(actor||'/original-scan.jpg',actor||'/crop-scan.jpg')),'both temporary grants consumed');
 PERFORM pg_temp.check(public.findez_can_read_item_image(teammate,actor||'/original-scan.jpg'),'authorized teammate reads original after Review resolved');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image('d4000000-0000-0000-0000-000000000005',actor||'/original-scan.jpg'),'copied source URL grants outsider nothing');
 BEGIN
  INSERT INTO public.item_events(item_id,user_id,inventory_id,event_type,image_url)
  VALUES((result->>'item_id')::uuid,actor,inv,'photo','https://storage.test/storage/v1/object/public/item-images/d4000000-0000-0000-0000-000000000005/foreign.jpg');
  RAISE EXCEPTION 'copied private URL was attached';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 -- A photo write failure rolls back item creation and Review resolution.
 PERFORM set_config('request.jwt.claims','{}',false);
 PERFORM set_config('request.headers','{}',false);
 review:=gen_random_uuid();
 INSERT INTO public.capture_reviews(review_id,user_id,inventory_id,source_key,name,category,quantity,image_url,source_frame_url)
 VALUES(review,actor,inv,'original-gallery-denied','Denied original','Hardware',1,crop,source);
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',false);
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',actor)::text,false);
 PERFORM set_config('findez.qa_fail_photo','true',false);
 BEGIN
  PERFORM public.resolve_capture_review(review,actor,payload||'{"name":"Must roll back"}',null,null);
  RAISE EXCEPTION 'photo failure did not abort resolution';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM set_config('findez.qa_fail_photo','false',false);
 PERFORM pg_temp.check((SELECT status='pending' FROM public.capture_reviews WHERE review_id=review),'failed original leaves review pending');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.items WHERE name='Must roll back'),'failed original rolls back item');
 UPDATE public.app_inventory_members SET role='none' WHERE inventory_id=inv AND user_id=teammate;
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(teammate,actor||'/original-scan.jpg'),'revoked teammate loses original immediately');
END $$;
DROP TRIGGER qa_fail_original ON public.item_events;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);

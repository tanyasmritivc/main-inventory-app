-- Run only after resource_permissions.sql in the disposable fixture.
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
ALTER TABLE public.item_events ADD COLUMN IF NOT EXISTS item_id uuid, ADD COLUMN IF NOT EXISTS image_url text;
\ir ../../supabase/migrations/055_private_item_images.sql
\ir ../../supabase/migrations/055_private_item_images.sql
SELECT pg_temp.check((SELECT NOT public FROM storage.buckets WHERE id='item-images'),'item image bucket is private');
SELECT pg_temp.check(public.findez_item_image_path('https://storage.test/storage/v1/object/sign/item-images/d4000000-0000-0000-0000-000000000003/Photo%20one.jpg?token=old')='d4000000-0000-0000-0000-000000000003/Photo one.jpg','legacy signed/public locators resolve without reuploading');
SELECT pg_temp.check(public.findez_item_image_path('https://storage.test/storage/v1/object/public/item-images/d4000000-0000-0000-0000-000000000003/%2e%2e/photo.jpg') IS NULL,'image path traversal rejected');
UPDATE public.items SET image_url='https://storage.test/storage/v1/object/public/item-images/d4000000-0000-0000-0000-000000000003/kept.jpg' WHERE item_id='d4200000-0000-0000-0000-000000000001';
UPDATE public.app_inventory_members SET role='viewer' WHERE inventory_id=(SELECT id FROM permission_demo WHERE key='inventory') AND user_id='d4000000-0000-0000-0000-000000000003';
SELECT pg_temp.check(public.findez_can_read_item_image('d4000000-0000-0000-0000-000000000003','d4000000-0000-0000-0000-000000000003/kept.jpg'),'authorized Viewer sees existing photos');
SELECT pg_temp.check(NOT public.findez_can_read_item_image('d4000000-0000-0000-0000-000000000005','d4000000-0000-0000-0000-000000000003/kept.jpg'),'organization membership alone does not expose photos');
UPDATE public.app_inventory_members SET role='none' WHERE inventory_id=(SELECT id FROM permission_demo WHERE key='inventory') AND user_id='d4000000-0000-0000-0000-000000000003';
SELECT pg_temp.check(NOT public.findez_can_read_item_image('d4000000-0000-0000-0000-000000000003','d4000000-0000-0000-0000-000000000003/kept.jpg'),'No access blocks even the workspace owner photo');
UPDATE public.app_inventory_members SET role='editor' WHERE inventory_id=(SELECT id FROM permission_demo WHERE key='inventory') AND user_id='d4000000-0000-0000-0000-000000000003';
DO $$ DECLARE actor uuid:='d4000000-0000-0000-0000-000000000003'; inv uuid:=(SELECT id FROM permission_demo WHERE key='inventory'); image text:='d4000000-0000-0000-0000-000000000003/new.jpg'; BEGIN
 PERFORM public.findez_register_image_preview(actor,inv,image);
 PERFORM pg_temp.check(public.findez_can_read_item_image(actor,image),'scan preview is private to its uploader');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image('d4000000-0000-0000-0000-000000000001',image),'workspace Admin cannot see another uploader unsaved preview');
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',false);
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',actor)::text,false);
 UPDATE public.items SET image_url='https://storage.test/storage/v1/object/public/item-images/'||image WHERE item_id='d4200000-0000-0000-0000-000000000001';
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_image_previews WHERE storage_path=image),'saving consumes temporary photo grant');
 DELETE FROM public.items WHERE item_id='d4200000-0000-0000-0000-000000000001';
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(actor,image),'deleted item photo cannot be fetched via old URL');
END $$;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
SET ROLE anon;
SELECT pg_temp.check((SELECT count(*)=0 FROM storage.objects WHERE bucket_id='item-images'),'anonymous direct Storage reads are blocked');
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=0 FROM storage.objects WHERE bucket_id='item-images'),'JWT users cannot bypass image delivery through Storage');
DO $$ BEGIN
 BEGIN PERFORM public.findez_can_read_item_image('d4000000-0000-0000-0000-000000000003','x'); RAISE EXCEPTION 'arbitrary-actor photo helper exposed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',false);
DO $$ DECLARE inv uuid; actor uuid:='d4000000-0000-0000-0000-000000000003'; path text:='d4000000-0000-0000-0000-000000000003/empty-preview.jpg'; receipt jsonb; BEGIN
 inv:=(public.findez_create_inventory(actor,(SELECT id FROM permission_demo WHERE key='workspace'),'Empty private preview','workspace')->>'inventory_id')::uuid;
 PERFORM public.findez_register_image_preview(actor,inv,path);
 receipt:=public.findez_delete_empty_inventory(actor,inv,'Empty private preview');
 PERFORM pg_temp.check(receipt->>'file_cleanup_pending'='true','empty inventory deletion queues its unsaved private photos');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_image_previews WHERE inventory_id=inv),'inventory deletion revokes temporary photo metadata');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(actor,path),'deleted preview cannot be fetched from an old URL');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_inventory_deletions WHERE inventory_id=inv AND files->0->>'path'=path),'durable cleanup retains the exact private object path');
END $$;

-- Run only after the composed synthetic fixture in a disposable database.
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
\ir ../../supabase/migrations/075_chat_capture_images.sql
\ir ../../supabase/migrations/075_chat_capture_images.sql
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_chat_capture_image(uuid,text)','EXECUTE'),'capture photo lookup service-only');
DO $$
DECLARE actor uuid:='d4000000-0000-0000-0000-000000000003'; stranger uuid:='d4000000-0000-0000-0000-000000000004';
 cid uuid:=gen_random_uuid(); mid uuid:=gen_random_uuid(); p text; ctx jsonb; org uuid; n integer;
BEGIN
 p:=actor::text||'/capture-durable-qa.jpg';
 ctx:=jsonb_build_object('chat_capture',jsonb_build_object('id',mid,'version',1,'revision',1,'status','draft','items',jsonb_build_array(jsonb_build_object('image_url','https://storage.test/storage/v1/object/public/item-images/'||p))));
 INSERT INTO public.conversations(id,user_id,title,world_key) VALUES(cid,actor,'Auto Extract QA','personal');
 INSERT INTO public.messages(id,conversation_id,role,content,answer_context) VALUES(mid,cid,'assistant','Draft',ctx);
 PERFORM pg_temp.check(public.findez_can_read_item_image(actor,p),'canonical author draft survives no preview grant');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(stranger,p),'draft photos private from other actors');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(actor,actor::text||'/unrecorded.jpg'),'unknown paths denied');
 -- Real JSONB compare-and-swap: stale revisions cannot edit or retarget saving.
 UPDATE public.messages SET answer_context=jsonb_set(ctx,'{chat_capture,status}','"saving"') WHERE id=mid AND answer_context=ctx;
 GET DIAGNOSTICS n=ROW_COUNT;
 PERFORM pg_temp.check(n=1,'save lock acquired');
 UPDATE public.messages SET answer_context=jsonb_set(ctx,'{chat_capture,revision}','2') WHERE id=mid AND answer_context=ctx;
 GET DIAGNOSTICS n=ROW_COUNT;
 PERFORM pg_temp.check(n=0,'stale edit cannot overwrite save lock');
 DELETE FROM public.messages WHERE id=mid;
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(actor,p),'deleting draft revokes image branch');
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Capture privacy QA"}')->>'organization_id')::uuid;
 INSERT INTO public.app_organization_members(organization_id,user_id,role) VALUES(org,stranger,'admin');
 cid:=gen_random_uuid(); mid:=gen_random_uuid(); p:=stranger::text||'/org-draft-qa.jpg';
 ctx:=jsonb_build_object('chat_capture',jsonb_build_object('id',mid,'version',1,'source_url','https://storage.test/storage/v1/object/public/item-images/'||p));
 INSERT INTO public.conversations(id,user_id,title,world_key) VALUES(cid,stranger,'Org extraction',org::text);
 INSERT INTO public.messages(id,conversation_id,role,content,answer_context) VALUES(mid,cid,'assistant','Draft',ctx);
 PERFORM pg_temp.check(public.findez_can_read_item_image(stranger,p),'org author allowed');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(actor,p),'org owner cannot read another author draft');
 DELETE FROM public.app_organization_members WHERE organization_id=org AND user_id=stranger;
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(stranger,p),'removed org member denied');
END $$;

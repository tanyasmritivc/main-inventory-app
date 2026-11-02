-- Isolated restored production database only. Every fixture is rolled back.
\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.check(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF; RAISE NOTICE 'PASS: %',label; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT
 ('e6000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'sharing-rehearsal-'||n||'@example.invalid',now() FROM generate_series(1,3) n;
CREATE TEMP TABLE sharing_fixture(key text PRIMARY KEY,id uuid);
DO $$ DECLARE owner_id uuid:='e6000000-0000-0000-0000-000000000001';
 viewer uuid:='e6000000-0000-0000-0000-000000000002';
 stranger uuid:='e6000000-0000-0000-0000-000000000003';
 inv uuid; other_inv uuid; ws uuid; team_inv uuid; loc uuid; otherloc uuid; item uuid; otheritem uuid; share uuid; claims text;
BEGIN
 inv:=(public.findez_create_inventory(owner_id,NULL,'Personal sharing test','workspace')->>'inventory_id')::uuid;
 other_inv:=(public.findez_create_inventory(owner_id,NULL,'Other personal test','workspace')->>'inventory_id')::uuid;
 ws:=(public.findez_create_legacy_workspace(owner_id,'{"name":"Sharing boundary team","program":"custom","custom_category":"QA"}')->>'team_id')::uuid;
 team_inv:=(public.findez_create_inventory(owner_id,ws,'Team sharing boundary','workspace')->>'inventory_id')::uuid;
 INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(owner_id,inv,'Same Name') RETURNING id INTO loc;
 INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(owner_id,other_inv,'Same Name') RETURNING id INTO otherloc;
 BEGIN INSERT INTO public.spaces(user_id,inventory_id,name) VALUES(owner_id,inv,' same NAME '); RAISE EXCEPTION 'duplicate Space admitted'; EXCEPTION WHEN unique_violation THEN NULL; END;
 INSERT INTO public.items(user_id,inventory_id,space_id,name,category,quantity,location,image_url)
 VALUES(owner_id,inv,loc,'Shared fixture','Other',1,'Same Name','https://storage.test/storage/v1/object/public/item-images/'||owner_id||'/shared-060.jpg') RETURNING item_id INTO item;
 INSERT INTO public.items(user_id,inventory_id,space_id,name,category,quantity,location,image_url)
 VALUES(owner_id,other_inv,otherloc,'Private fixture','Other',1,'Same Name','https://storage.test/storage/v1/object/public/item-images/'||owner_id||'/private-060.jpg') RETURNING item_id INTO otheritem;
 INSERT INTO public.team_shares(owner_user_id,inventory_id,space_id,share_code,share_name,permission,is_active)
 VALUES(owner_id,inv,loc,'QA060X','Same Name','view',true) RETURNING share_id INTO share;
 INSERT INTO public.team_members(share_id,member_user_id) VALUES(share,viewer);
 INSERT INTO sharing_fixture VALUES('owner',owner_id),('viewer',viewer),('stranger',stranger),('inventory',inv),('other_inventory',other_inv),('item',item),('other_item',otheritem),('share',share),('team_inventory',team_inv);
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.findez_inventory_fences(viewer)) f WHERE f->>'inventory_id'=inv::text),'new personal sharing is not blocked by a Team fence');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM jsonb_array_elements(public.findez_inventory_fences(viewer)) f WHERE f->>'inventory_id'=team_inv::text AND f->>'role' IS NULL),'Team outsider fence remains');
 PERFORM pg_temp.check(public.findez_inventory_role(inv,viewer) IS NULL,'Shared Space does not grant whole inventory access');
 PERFORM pg_temp.check(public.findez_can_read_item_image(viewer,owner_id||'/shared-060.jpg'),'accepted share can read its photo');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(stranger,owner_id||'/shared-060.jpg'),'stranger cannot read shared photo');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(viewer,owner_id||'/private-060.jpg'),'same-name Space in another inventory stays private');
 UPDATE public.team_shares SET space_id=NULL WHERE share_id=share;
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(viewer,owner_id||'/private-060.jpg'),'legacy name-only share also retains inventory boundary');
 UPDATE public.team_shares SET space_id=loc,expires_at=now()-interval '1 minute' WHERE share_id=share;
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(viewer,owner_id||'/shared-060.jpg'),'expired invitation cannot deliver private photos');
 UPDATE public.team_shares SET expires_at=NULL,is_active=false WHERE share_id=share;
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(viewer,owner_id||'/shared-060.jpg'),'revoked share cannot deliver photos');
 UPDATE public.team_shares SET is_active=true WHERE share_id=share;
 DELETE FROM public.team_members WHERE share_id=share AND member_user_id=viewer;
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(viewer,owner_id||'/shared-060.jpg'),'member removal immediately revokes photos');
 INSERT INTO public.team_members(share_id,member_user_id) VALUES(share,viewer);
 UPDATE public.app_inventories SET access_mode='restricted' WHERE inventory_id=inv;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM jsonb_array_elements(public.findez_inventory_fences(viewer)) f WHERE f->>'inventory_id'=inv::text AND f->>'role' IS NULL),'restricted personal inventory stays fenced');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(viewer,owner_id||'/shared-060.jpg'),'share cannot bypass restricted personal inventory');
 UPDATE public.app_inventories SET access_mode='workspace' WHERE inventory_id=inv;
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,viewer,'none');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM jsonb_array_elements(public.findez_inventory_fences(viewer)) f WHERE f->>'inventory_id'=inv::text AND f->>'role' IS NULL),'explicit No access remains fenced');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(viewer,owner_id||'/shared-060.jpg'),'share cannot bypass explicit No access');
 DELETE FROM public.app_inventory_members WHERE inventory_id=inv;
END $$;
GRANT SELECT ON sharing_fixture TO authenticated,service_role,anon;
SELECT set_config('request.jwt.claims',json_build_object('role','authenticated','sub',(SELECT id FROM sharing_fixture WHERE key='viewer'))::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=1 FROM public.team_members WHERE share_id=(SELECT id FROM sharing_fixture WHERE key='share')),'member can read own membership without RLS recursion');
SELECT pg_temp.check((SELECT count(*)=1 FROM public.team_shares WHERE share_id=(SELECT id FROM sharing_fixture WHERE key='share')),'member can read accepted share without RLS recursion');
SELECT pg_temp.check((SELECT count(*)=0 FROM public.items WHERE item_id IN (SELECT id FROM sharing_fixture WHERE key IN ('item','other_item'))),'direct RLS cannot read owner inventory even with accepted share');
DO $$ BEGIN
 BEGIN INSERT INTO public.team_members(share_id,member_user_id) VALUES((SELECT id FROM sharing_fixture WHERE key='share'),auth.uid()); RAISE EXCEPTION 'client forged membership'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.team_shares SET permission='edit' WHERE share_id=(SELECT id FROM sharing_fixture WHERE key='share'); RAISE EXCEPTION 'client changed share'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims',json_build_object('role','authenticated','sub',(SELECT id FROM sharing_fixture WHERE key='owner'))::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=1 FROM public.team_members WHERE share_id=(SELECT id FROM sharing_fixture WHERE key='share')),'owner can read share roster without RLS recursion');
SELECT pg_temp.check((SELECT count(*)=2 FROM public.items WHERE item_id IN (SELECT id FROM sharing_fixture WHERE key IN ('item','other_item'))),'owner direct reads retained');
RESET ROLE;
DO $$ DECLARE who text; tbl text; BEGIN
 FOREACH who IN ARRAY ARRAY['anon','authenticated'] LOOP
  FOREACH tbl IN ARRAY ARRAY['team_members','team_shares'] LOOP
   PERFORM pg_temp.check(NOT has_table_privilege(who,'public.'||tbl,'INSERT') AND NOT has_table_privilege(who,'public.'||tbl,'UPDATE') AND NOT has_table_privilege(who,'public.'||tbl,'DELETE'),who||' cannot mutate '||tbl);
  END LOOP;
 END LOOP;
 PERFORM pg_temp.check(has_table_privilege('service_role','public.team_members','INSERT,UPDATE,DELETE'),'trusted join/remove backend retains writes');
END $$;
ROLLBACK;
\echo Personal sharing, private photos, restricted inventory, direct-write denial and ownership controls passed.

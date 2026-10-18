-- Run last against the disposable composed schema only.
\ir ../../supabase/migrations/058_api_inventory_compatibility.sql
\ir ../../supabase/migrations/058_api_inventory_compatibility.sql
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES ('e1800000-0000-0000-0000-000000000001','release@example.invalid',now()) ON CONFLICT DO NOTHING;
INSERT INTO public.teams(team_id,name,owner_user_id) VALUES ('e1800000-0000-0000-0000-000000000002','Release API','e1800000-0000-0000-0000-000000000001');
INSERT INTO public.team_memberships(team_id,user_id,role) VALUES ('e1800000-0000-0000-0000-000000000002','e1800000-0000-0000-0000-000000000001','owner');
INSERT INTO public.spaces(id,user_id,inventory_id,name) VALUES ('e1800000-0000-0000-0000-000000000003','e1800000-0000-0000-0000-000000000001',public.findez_default_inventory('e1800000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000002'),'Release Shelf');
INSERT INTO public.api_keys(id,workspace_id,org_id,name,key_prefix,key_hash,scopes,created_by) VALUES
('e1800000-0000-0000-0000-000000000004',NULL,'e1800000-0000-0000-0000-000000000001','Global QA','qa','qa',ARRAY['org:read','org:write'],'e1800000-0000-0000-0000-000000000001'),
('e1800000-0000-0000-0000-000000000005','e1800000-0000-0000-0000-000000000002','e1800000-0000-0000-0000-000000000001','Workspace QA','qa','qa',ARRAY['items:read','items:write'],'e1800000-0000-0000-0000-000000000001');
INSERT INTO public.items(item_id,user_id,space_id,name,category,quantity,location,image_url) VALUES ('e1800000-0000-0000-0000-000000000006','e1800000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000003','Photo item','Other',1,'Release Shelf','https://storage.test/storage/v1/object/public/item-images/e1800000-0000-0000-0000-000000000001/qa.jpg');
SELECT set_config('request.jwt.claims','{"sub":"e1800000-0000-0000-0000-000000000004","api_key_id":"e1800000-0000-0000-0000-000000000004","api_workspace_id":null,"api_org_id":"e1800000-0000-0000-0000-000000000001","api_scopes":["org:read","org:write"]}',false);
SET ROLE authenticated;
DO $$ BEGIN
 BEGIN INSERT INTO public.items(user_id,workspace_id,name,category,quantity,location) VALUES ('e1800000-0000-0000-0000-000000000004','e1800000-0000-0000-0000-000000000002','Global item','Other',1,'Release Shelf');
 RAISE NOTICE 'PASS: global key creates an item in an owned workspace'; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"e1800000-0000-0000-0000-000000000005","api_key_id":"e1800000-0000-0000-0000-000000000005","api_workspace_id":"e1800000-0000-0000-0000-000000000002","api_org_id":"e1800000-0000-0000-0000-000000000001","api_scopes":["items:read","items:write"]}',false);
SET ROLE authenticated;
DO $$ BEGIN
 BEGIN UPDATE public.items SET quantity=2 WHERE item_id='e1800000-0000-0000-0000-000000000006';
 RAISE NOTICE 'PASS: workspace key updates quantity while retaining a private photo'; END;
END $$;

DO $$ BEGIN
 IF (SELECT quantity FROM public.items WHERE item_id='e1800000-0000-0000-0000-000000000006')<>2 THEN RAISE EXCEPTION 'photo quantity unchanged'; END IF;
 BEGIN UPDATE public.items SET image_url='https://storage.test/storage/v1/object/public/item-images/e1800000-0000-0000-0000-000000000001/stolen.jpg' WHERE item_id='e1800000-0000-0000-0000-000000000006';
  RAISE EXCEPTION 'key attached unowned private photo'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: key cannot attach an arbitrary private photo'; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',false);
INSERT INTO public.app_inventory_members(inventory_id,user_id,role)
 SELECT inventory_id,'e1800000-0000-0000-0000-000000000001','none' FROM public.spaces WHERE id='e1800000-0000-0000-0000-000000000003';
SELECT set_config('request.jwt.claims','{"sub":"e1800000-0000-0000-0000-000000000004","api_key_id":"e1800000-0000-0000-0000-000000000004","api_workspace_id":null,"api_org_id":"e1800000-0000-0000-0000-000000000001","api_scopes":["org:read","org:write"]}',false);
SET ROLE authenticated;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.items WHERE workspace_id='e1800000-0000-0000-0000-000000000002') THEN RAISE EXCEPTION 'global key bypassed No access'; END IF;
 BEGIN INSERT INTO public.items(user_id,workspace_id,name,category,quantity,location) VALUES ('e1800000-0000-0000-0000-000000000004','e1800000-0000-0000-0000-000000000002','Forbidden','Other',1,'Release Shelf');
  RAISE EXCEPTION 'global key bypassed No access on write'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: No access still blocks global writes'; END;
END $$;
RESET ROLE;
ROLLBACK;

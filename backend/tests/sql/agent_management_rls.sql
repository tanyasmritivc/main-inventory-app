\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claims','{}',true);
SELECT set_config('request.headers','{}',true);
CREATE OR REPLACE FUNCTION pg_temp.check(p_condition boolean,p_name text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p_condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',p_name; END IF; RAISE NOTICE 'PASS: %',p_name; END $$;
CREATE TEMP TABLE agent_rls_fixture(key text PRIMARY KEY,id uuid);
CREATE FUNCTION pg_temp.agent_id(p_key text) RETURNS uuid LANGUAGE sql SECURITY DEFINER AS $$ SELECT id FROM agent_rls_fixture WHERE key=p_key $$;
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT
 ('e7100000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'agent-rls-'||n||'@example.invalid',now() FROM generate_series(1,2) n;
DO $$
DECLARE actor uuid:='e7100000-0000-0000-0000-000000000001'; viewer uuid:='e7100000-0000-0000-0000-000000000002';
 org uuid; otherorg uuid; ws uuid; otherws uuid; inv uuid; otherinv uuid; samewsinv uuid; loc uuid; otherloc uuid;
 key uuid:=gen_random_uuid(); viewerkey uuid:=gen_random_uuid(); legacy uuid:=gen_random_uuid();
BEGIN
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"RLS organization"}')->>'organization_id')::uuid;
 otherorg:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Other owned organization"}')->>'organization_id')::uuid;
 ws:=(public.findez_manage_collaboration(actor,'workspace_create',jsonb_build_object('organization_id',org,'name','RLS workspace'))->>'team_id')::uuid;
 otherws:=(public.findez_manage_collaboration(actor,'workspace_create',jsonb_build_object('organization_id',otherorg,'name','Other owned workspace'))->>'team_id')::uuid;
 inv:=(public.findez_create_inventory(actor,ws,'Parts','workspace')->>'inventory_id')::uuid;
 samewsinv:=(public.findez_create_inventory(actor,ws,'Same names elsewhere','workspace')->>'inventory_id')::uuid;
 otherinv:=(public.findez_create_inventory(actor,otherws,'Private parts','workspace')->>'inventory_id')::uuid;
 loc:=(public.findez_get_or_create_inventory_space(actor,inv,'Shelf',100)->>'id')::uuid;
 PERFORM public.findez_get_or_create_inventory_space(actor,samewsinv,'Shelf',100);
 otherloc:=(public.findez_get_or_create_inventory_space(actor,otherinv,'Shelf',100)->>'id')::uuid;
 INSERT INTO public.items(user_id,inventory_id,space_id,name,category,quantity,location) VALUES
 (actor,inv,loc,'Visible part','Other',2,'Shelf'),(actor,otherinv,otherloc,'PRIVATE_OTHER_ORG','Other',99,'Shelf');
 -- Synthetic setup bypasses invitation consent only as database administrator.
 INSERT INTO public.app_organization_members VALUES(org,viewer,'admin');
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,viewer,'viewer');
 INSERT INTO public.api_keys(id,org_id,organization_id,name,key_prefix,key_hash,scopes,created_by) VALUES
 (key,actor,org,'Bound','test','hash',ARRAY['org:read','org:write'],actor),
 (viewerkey,viewer,org,'Admin with viewer inventory','test','hash',ARRAY['org:read','org:write','structure:write'],viewer),
 (legacy,actor,NULL,'Legacy','test','hash',ARRAY['org:read','org:write'],actor);
 INSERT INTO agent_rls_fixture VALUES('actor',actor),('viewer',viewer),('organization',org),('workspace',ws),('otherworkspace',otherws),('inventory',inv),('otherinventory',otherinv),('key',key),('viewerkey',viewerkey),('legacy',legacy);
END $$;
CREATE FUNCTION pg_temp.agent_key(p_key text,p_actor text,p_org boolean DEFAULT true) RETURNS void LANGUAGE sql AS $$
 SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.agent_id(p_key),'role','authenticated',
 'api_key_id',pg_temp.agent_id(p_key),'api_org_id',pg_temp.agent_id(p_actor),'api_workspace_id',null,
 'api_organization_id',CASE WHEN p_org THEN pg_temp.agent_id('organization') END,'api_scopes',jsonb_build_array('org:read','org:write'))::text,true)
$$;
SET LOCAL ROLE authenticated;
SELECT pg_temp.agent_key('key','actor');
SELECT pg_temp.check((SELECT count(*)=1 FROM public.items),'new organization key excludes another owned organization');
SELECT pg_temp.check((public.api_query_items(NULL,jsonb_build_array(jsonb_build_object('field','inventory_id','op','eq','value',pg_temp.agent_id('inventory'))),'sum_quantity')->>'value')::int=2,'inventory ID filter totals only selected inventory');
SELECT pg_temp.check((public.api_query_items(pg_temp.agent_id('otherworkspace'),'[]','count')->>'value')::int=0,'explicit foreign workspace cannot escape organization');
INSERT INTO public.items(user_id,workspace_id,inventory_id,name,category,quantity,location)
 VALUES(pg_temp.agent_id('key'),pg_temp.agent_id('workspace'),pg_temp.agent_id('inventory'),'Agent created','Other',1,'Shelf');
SELECT pg_temp.check((SELECT count(*)=2 FROM public.items),'inventory ID disambiguates same-name Spaces');
SELECT pg_temp.check((SELECT bool_and(inventory_id=pg_temp.agent_id('inventory')) FROM public.items),'item write stays in selected inventory');
DO $$ BEGIN
 BEGIN INSERT INTO public.items(user_id,workspace_id,inventory_id,name,category,quantity,location)
 VALUES(pg_temp.agent_id('key'),pg_temp.agent_id('workspace'),pg_temp.agent_id('otherinventory'),'Escape','Other',1,'Shelf');
 RAISE EXCEPTION 'foreign inventory accepted'; EXCEPTION WHEN invalid_parameter_value OR insufficient_privilege THEN NULL; END;
END $$;
SELECT pg_temp.agent_key('viewerkey','viewer');
SELECT pg_temp.check((SELECT count(*)=2 FROM public.items),'organization admin with viewer inventory can read');
DO $$ BEGIN
 BEGIN UPDATE public.items SET quantity=999 WHERE name='Visible part';
 IF FOUND THEN RAISE EXCEPTION 'viewer could update'; END IF;
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.items(user_id,workspace_id,inventory_id,name,category,quantity,location)
 VALUES(pg_temp.agent_id('viewerkey'),pg_temp.agent_id('workspace'),pg_temp.agent_id('inventory'),'Viewer write','Other',1,'Shelf');
 RAISE EXCEPTION 'viewer could insert'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT pg_temp.agent_key('legacy','actor',false);
SELECT pg_temp.check((SELECT count(*)=3 FROM public.items),'legacy key retains all-owned-workspace behavior');
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',true);
UPDATE public.api_keys SET revoked_at=now() WHERE id=pg_temp.agent_id('key');
SET LOCAL ROLE authenticated;
SELECT pg_temp.agent_key('key','actor');
SELECT pg_temp.check((SELECT count(*)=0 FROM public.items),'database rejects revoked key even with a valid old JWT');
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',true);
DELETE FROM public.app_organization_members WHERE organization_id=pg_temp.agent_id('organization') AND user_id=pg_temp.agent_id('viewer');
SET LOCAL ROLE authenticated;
SELECT pg_temp.agent_key('viewerkey','viewer');
SELECT pg_temp.check((SELECT count(*)=0 FROM public.items),'removed organization member loses API access');
RESET ROLE;
ROLLBACK;

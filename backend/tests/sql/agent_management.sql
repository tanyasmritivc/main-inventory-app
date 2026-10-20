-- Run ONLY in the isolated restored database. Synthetic records roll back.
\set ON_ERROR_STOP on
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.check(p_condition boolean,p_name text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF p_condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',p_name; END IF; RAISE NOTICE 'PASS: %',p_name; END $$;
INSERT INTO auth.users(id,email,email_confirmed_at) SELECT
 ('e7000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'agent-qa-'||n||'@example.invalid',now() FROM generate_series(1,4) n;
DO $$
DECLARE actor uuid:='e7000000-0000-0000-0000-000000000001'; viewer uuid:='e7000000-0000-0000-0000-000000000002';
 stranger uuid:='e7000000-0000-0000-0000-000000000003'; org uuid; other_org uuid; ws uuid; inv uuid; inv2 uuid; loc uuid; item uuid;
 key uuid:=gen_random_uuid(); read_key uuid:=gen_random_uuid(); legacy uuid:=gen_random_uuid(); request uuid:=gen_random_uuid();
 saved jsonb; repeated jsonb; approval jsonb; confirmation jsonb; invitation uuid; physical uuid; empty_ws uuid; invite_request uuid;
BEGIN
 org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Agent QA organization"}')->>'organization_id')::uuid;
 other_org:=(public.findez_manage_collaboration(actor,'organization_create','{"name":"Other organization"}')->>'organization_id')::uuid;
 INSERT INTO public.api_keys(id,org_id,organization_id,name,key_prefix,key_hash,scopes,created_by) VALUES
 (key,actor,org,'QA full','test','hash',ARRAY['org:read','org:write','structure:read','structure:write','structure:delete','members:read','members:write','items:delete'],actor),
 (read_key,actor,org,'QA read','test','hash',ARRAY['org:read','structure:read','members:read'],actor),
 (legacy,actor,NULL,'QA legacy','test','hash',ARRAY['org:read','org:write'],actor);
 saved:=public.findez_agent_manage(key,request,'workspace_create','organization',org,'{"name":"Agent workspace"}');
 ws:=(saved->>'team_id')::uuid;
 PERFORM pg_temp.check(ws IS NOT NULL,'workspace created');
 repeated:=public.findez_agent_manage(key,request,'workspace_create','organization',org,'{"name":"Agent workspace"}');
 PERFORM pg_temp.check(repeated=saved,'retry returns original receipt without duplicate workspace');
 BEGIN PERFORM public.findez_agent_manage(key,request,'workspace_create','organization',org,'{"name":"Different workspace"}');
  RAISE EXCEPTION 'accepted reused request'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM public.findez_agent_manage(key,gen_random_uuid(),'workspace_create','organization',other_org,'{"name":"Escape"}');
  RAISE EXCEPTION 'cross org'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_agent_manage(read_key,gen_random_uuid(),'workspace_create','organization',org,'{"name":"Escape"}');
  RAISE EXCEPTION 'read wrote'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_agent_manage(legacy,gen_random_uuid(),'workspace_create','organization',org,'{"name":"Escape"}');
  RAISE EXCEPTION 'legacy gained management'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.check(true,'other organization, read-only and legacy keys denied');
 inv:=(public.findez_agent_manage(key,gen_random_uuid(),'inventory_create','workspace',ws,'{"name":"Parts","access_mode":"workspace"}')->>'inventory_id')::uuid;
 inv2:=(public.findez_agent_manage(key,gen_random_uuid(),'inventory_create','workspace',ws,'{"name":"Other parts","access_mode":"restricted"}')->>'inventory_id')::uuid;
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'space_create','inventory',inv,'{"name":"Shelf"}',100);
 loc:=(saved->>'id')::uuid;
 repeated:=public.findez_get_or_create_inventory_space(actor,inv,' shelf ',100);
 PERFORM pg_temp.check(saved->>'id'=repeated->>'id' AND repeated->'created'='false','case-insensitive Space creation is retry-safe');
 repeated:=public.findez_get_or_create_inventory_space(actor,inv2,'Shelf',100);
 PERFORM pg_temp.check(saved->>'id'<>repeated->>'id','same Space name in another inventory is isolated');
 BEGIN PERFORM public.findez_get_or_create_inventory_space(viewer,inv,'Viewer space',100);
  RAISE EXCEPTION 'viewer wrote'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.findez_get_or_create_inventory_space(actor,inv,'Over limit',0);
  RAISE EXCEPTION 'limit bypass'; EXCEPTION WHEN check_violation THEN NULL; END;
 INSERT INTO public.items(user_id,inventory_id,space_id,name,category,quantity,location)
 VALUES(actor,inv,loc,'Test part','Other',2,'Shelf') RETURNING item_id INTO item;
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'space_rename','space',loc,'{"name":"Shelf A"}');
 PERFORM pg_temp.check((SELECT location='Shelf A' FROM public.items WHERE item_id=item),'rename updates item location atomically');
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'space_move','space',loc,jsonb_build_object('inventory_id',inv2));
 PERFORM pg_temp.check((SELECT inventory_id=inv2 FROM public.items WHERE item_id=item),'Space move keeps dependent item in destination inventory');
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'member_invite','organization',org,
  jsonb_build_object('email','agent-qa-2@example.invalid','role','member','code_hash',md5('agent-management-a')||md5('agent-management-a')));
 invitation:=(saved->>'invitation_id')::uuid;
 PERFORM pg_temp.check(invitation IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=viewer),'invitation does not grant access before consent');
 saved:=public.findez_access_invitation(viewer,'accept',jsonb_build_object('invitation_id',invitation));
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=viewer),'recipient can accept');
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'member_change','organization',org,jsonb_build_object('user_id',viewer,'role','admin'));
 PERFORM pg_temp.check((SELECT role='admin' FROM public.app_organization_members WHERE organization_id=org AND user_id=viewer),'organization role can change');
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'member_remove','organization',org,jsonb_build_object('user_id',viewer));
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_organization_members WHERE organization_id=org AND user_id=viewer),'member removal works');

 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'organization_rename','organization',org,'{"name":"Renamed organization"}');
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'workspace_rename','workspace',ws,'{"name":"Renamed workspace"}');
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'inventory_rename','inventory',inv,'{"name":"Renamed parts"}');
 PERFORM pg_temp.check((SELECT name='Renamed organization' FROM public.app_organizations WHERE organization_id=org)
  AND (SELECT name='Renamed workspace' FROM public.teams WHERE team_id=ws)
  AND (SELECT name='Renamed parts' FROM public.app_inventories WHERE inventory_id=inv),'organization/workspace/inventory rename');
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'location_create','workspace',ws,'{"name":"Building A"}');
 physical:=(saved->>'location_id')::uuid;
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'location_attach','inventory',inv,jsonb_build_object('location_id',physical));
 PERFORM pg_temp.check(physical IS NOT NULL,'physical location created and attached');
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'inventory_policy','inventory',inv,'{"access_mode":"restricted","default_role":"viewer"}');
 PERFORM pg_temp.check((SELECT access_mode='restricted' AND default_role='viewer' FROM public.app_inventories WHERE inventory_id=inv),'inventory access policy');
 invite_request:=gen_random_uuid();
 saved:=public.findez_agent_manage(key,invite_request,'member_invite','organization',org,
  jsonb_build_object('email','agent-qa-2@example.invalid','role','member','code_hash',md5('agent-management-b')||md5('agent-management-b')));
 repeated:=public.findez_agent_manage(key,invite_request,'member_invite','organization',org,
  jsonb_build_object('email','agent-qa-2@example.invalid','role','member','code_hash',md5('agent-management-b')||md5('agent-management-b')));
 PERFORM pg_temp.check(repeated->>'invitation_id'=saved->>'invitation_id' AND repeated->>'_skip_delivery'='true','invitation retries do not resend delivery');
 PERFORM public.findez_access_invitation(viewer,'accept',jsonb_build_object('invitation_id',saved->>'invitation_id'));
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'member_invite','workspace',ws,
  jsonb_build_object('email','agent-qa-2@example.invalid','role','editor','code_hash',md5('agent-management-c')||md5('agent-management-c')));
 PERFORM public.findez_access_invitation(viewer,'accept',jsonb_build_object('invitation_id',saved->>'invitation_id'));
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'member_invite','inventory',inv,
  jsonb_build_object('email','agent-qa-2@example.invalid','role','editor','code_hash',md5('agent-management-d')||md5('agent-management-d')));
 PERFORM public.findez_access_invitation(viewer,'accept',jsonb_build_object('invitation_id',saved->>'invitation_id'));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,viewer)='editor','organization workspace and restricted inventory invitations grant access after acceptance');
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'member_change','inventory',inv,jsonb_build_object('user_id',viewer,'role','viewer'));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,viewer)='viewer','inventory role change');
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'member_remove','inventory',inv,jsonb_build_object('user_id',viewer));
 PERFORM pg_temp.check(public.findez_inventory_role(inv,viewer) IS NULL,'inventory access revoked');
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'member_change','workspace',ws,jsonb_build_object('user_id',viewer,'role','viewer'));
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'member_remove','workspace',ws,jsonb_build_object('user_id',viewer));
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.team_memberships WHERE team_id=ws AND user_id=viewer),'workspace access revoked');
 saved:=public.findez_agent_manage(key,gen_random_uuid(),'member_invite','organization',org,
  jsonb_build_object('email','agent-qa-3@example.invalid','role','member','code_hash',md5('agent-management-e')||md5('agent-management-e')));
 PERFORM public.findez_agent_manage(key,gen_random_uuid(),'invitation_cancel','organization',org,jsonb_build_object('invitation_id',saved->>'invitation_id'));
 PERFORM pg_temp.check((SELECT status='cancelled' FROM public.app_access_invitations WHERE invitation_id=(saved->>'invitation_id')::uuid),'pending invitation cancelled');
 empty_ws:=(public.findez_agent_manage(key,gen_random_uuid(),'workspace_create','organization',org,'{"name":"Empty workspace"}')->>'team_id')::uuid;
 approval:=public.findez_agent_prepare_delete(key,gen_random_uuid(),'workspace',empty_ws);
 PERFORM public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Empty workspace');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.teams WHERE team_id=empty_ws),'confirmed empty workspace deletion');
 approval:=public.findez_agent_prepare_delete(key,gen_random_uuid(),'item',item);
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.items WHERE item_id=item),'prepare deletion is read-only for target');
 BEGIN PERFORM public.findez_agent_confirm_delete(stranger,(approval->>'id')::uuid,'confirm','Test part');
  RAISE EXCEPTION 'stranger confirmed'; EXCEPTION WHEN no_data_found THEN NULL; END;
 BEGIN PERFORM public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Wrong name');
  RAISE EXCEPTION 'wrong name'; EXCEPTION WHEN check_violation THEN NULL; END;
 UPDATE public.items SET quantity=3 WHERE item_id=item;
 BEGIN PERFORM public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Test part');
  RAISE EXCEPTION 'stale preview'; EXCEPTION WHEN check_violation THEN NULL; END;
 approval:=public.findez_agent_prepare_delete(key,gen_random_uuid(),'item',item);
 UPDATE public.api_agent_delete_approvals SET expires_at=now()-interval '1 second' WHERE id=(approval->>'id')::uuid;
 BEGIN PERFORM public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Test part');
  RAISE EXCEPTION 'expired approval'; EXCEPTION WHEN check_violation THEN NULL; END;
 approval:=public.findez_agent_prepare_delete(key,gen_random_uuid(),'item',item);
 UPDATE public.api_keys SET revoked_at=now() WHERE id=key;
 BEGIN PERFORM public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Test part');
  RAISE EXCEPTION 'revoked key'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.api_keys SET revoked_at=NULL WHERE id=key;
 confirmation:=public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Test part');
 PERFORM pg_temp.check(confirmation->>'status'='confirmed' AND NOT EXISTS(SELECT 1 FROM public.items WHERE item_id=item),'confirmed exact item is deleted');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.api_agent_file_deletions WHERE approval_id=(approval->>'id')::uuid AND NOT completed),'durable file cleanup receipt created atomically');
 PERFORM pg_temp.check(public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Test part')=confirmation,'confirmation retry returns original receipt');
 approval:=public.findez_agent_prepare_delete(key,gen_random_uuid(),'space',loc);
 PERFORM public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'cancel','');
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.spaces WHERE id=loc),'cancel leaves Space intact');
 approval:=public.findez_agent_prepare_delete(key,gen_random_uuid(),'space',loc);
 PERFORM public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Shelf A');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.spaces WHERE id=loc),'confirmed Space is deleted');
 approval:=public.findez_agent_prepare_delete(key,gen_random_uuid(),'inventory',inv2);
 PERFORM public.findez_agent_confirm_delete(actor,(approval->>'id')::uuid,'confirm','Other parts');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.app_inventories WHERE inventory_id=inv2),'confirmed inventory is deleted');
 BEGIN PERFORM public.findez_agent_prepare_delete(key,gen_random_uuid(),'workspace',ws);
  RAISE EXCEPTION 'workspace cascaded unreviewed inventories'; EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(NOT has_function_privilege('authenticated','public.findez_agent_confirm_delete(uuid,uuid,text,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.findez_agent_manage(uuid,uuid,text,text,uuid,jsonb,integer)','EXECUTE'),'public callers cannot invoke delegated management or confirmation RPCs');
END $$;
ROLLBACK;

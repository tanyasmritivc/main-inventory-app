-- Only in the composed disposable fixture; all identities are synthetic.
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);
\ir ../../supabase/migrations/057_chat_item_actions.sql
\ir ../../supabase/migrations/057_chat_item_actions.sql
SELECT pg_temp.check(NOT has_function_privilege('anon','public.findez_chat_item_action(uuid,uuid,uuid,text,integer)','EXECUTE'),'anonymous cannot confirm Chat actions');
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.findez_chat_item_action(uuid,uuid,uuid,text,integer)','EXECUTE'),'direct authenticated clients cannot spoof Chat actors');
CREATE TABLE chat_action_demo(key text PRIMARY KEY,id uuid);
CREATE FUNCTION pg_temp.chat_proposal(actor uuid, inv uuid, op text, proposed_rows jsonb, proposed uuid DEFAULT gen_random_uuid()) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE conversation uuid:=gen_random_uuid();
BEGIN
 INSERT INTO public.conversations(id,user_id,inventory_id,title) VALUES(conversation,actor,inv,'Synthetic Chat action');
 INSERT INTO public.messages(conversation_id,inventory_id,role,content,answer_context)
 VALUES(conversation,inv,'assistant','Synthetic model proposal',jsonb_build_object('pending_actions',jsonb_build_array(jsonb_build_object(
  'id',proposed,'version',1,'inventory_id',inv,'operation',op,'status','pending','expires_at',now()+interval '30 minutes','items',proposed_rows))));
 RETURN proposed;
END $$;
CREATE FUNCTION pg_temp.chat_action_call(actor uuid,inv uuid,action_id uuid,decision text,lim integer) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE claims text:=current_setting('request.jwt.claims',true); headers text:=current_setting('request.headers',true); result jsonb;
BEGIN
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
 PERFORM set_config('request.headers',jsonb_build_object('x-findez-actor',actor)::text,true);
 result:=public.findez_chat_item_action(actor,inv,action_id,decision,lim);
 PERFORM set_config('request.jwt.claims',claims,true); PERFORM set_config('request.headers',headers,true);
 RETURN result;
END $$;
DO $$
DECLARE owner uuid:='d4000000-0000-0000-0000-000000000003'; editor uuid:='d4000000-0000-0000-0000-000000000004';
 viewer uuid:='d4000000-0000-0000-0000-000000000005'; ws uuid; inv uuid; other_inv uuid; place uuid:=gen_random_uuid();
 proposal uuid; result jsonb; replay jsonb; selected_item uuid; second uuid; third uuid; proposed_rows jsonb; before_count integer;
 source text; crop text;
BEGIN
 ws:=(public.findez_create_legacy_workspace(owner,'{"name":"Chat actions QA","program":"custom","custom_category":"Test"}')->>'team_id')::uuid;
 INSERT INTO public.team_memberships(team_id,user_id,role) VALUES(ws,editor,'member'),(ws,viewer,'viewer');
 inv:=(public.findez_create_inventory(owner,ws,'Chat action inventory','workspace')->>'inventory_id')::uuid;
 other_inv:=(public.findez_create_inventory(owner,ws,'Separate inventory','restricted')->>'inventory_id')::uuid;
 INSERT INTO public.spaces(id,user_id,inventory_id,name) VALUES(place,owner,inv,'Chat shelf');
 INSERT INTO chat_action_demo VALUES('workspace',ws),('inventory',inv),('space',place),('owner',owner),('editor',editor),('viewer',viewer);
 proposed_rows:=jsonb_build_array(jsonb_build_object('name','Chat bolt','category','Hardware','quantity',3,'location','Chat shelf','space_id',place,'notes',null));
 proposal:=pg_temp.chat_proposal(editor,inv,'add',proposed_rows);
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.items WHERE inventory_id=inv),'proposing never writes an item');
 result:=pg_temp.chat_action_call(editor,inv,proposal,'confirm',1000);
 replay:=pg_temp.chat_action_call(editor,inv,proposal,'confirm',1000);
 selected_item:=(result->'receipt'->'items'->0->>'item_id')::uuid;
 PERFORM pg_temp.check(result=replay AND result->>'status'='confirmed','confirmation retry returns the same receipt');
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.items WHERE inventory_id=inv AND quantity=3 AND user_id=owner),'inherited Editor creates exactly one owner-bound item');
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.app_access_audit WHERE target_id=proposal AND action='chat_items_add'),'replay does not duplicate action audit');
 proposal:=pg_temp.chat_proposal(editor,inv,'add',proposed_rows||proposed_rows);
 PERFORM pg_temp.chat_action_call(editor,inv,proposal,'cancel',1000);
 PERFORM pg_temp.check((pg_temp.chat_action_call(editor,inv,proposal,'confirm',1000)->>'status')='cancelled','cancelled actions cannot execute');
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.items WHERE inventory_id=inv),'cancellation adds no records');
 -- Viewers can cancel their own stale proposal but cannot mutate items.
 proposal:=pg_temp.chat_proposal(viewer,inv,'add',proposed_rows);
 BEGIN PERFORM pg_temp.chat_action_call(viewer,inv,proposal,'confirm',1000); RAISE EXCEPTION 'viewer wrote';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM pg_temp.check((pg_temp.chat_action_call(viewer,inv,proposal,'cancel',1000)->>'status')='cancelled','Viewer can dismiss own pending card');
 -- An Owner cannot approve another actor's private card.
 proposal:=pg_temp.chat_proposal(editor,inv,'add',proposed_rows);
 BEGIN PERFORM pg_temp.chat_action_call(owner,inv,proposal,'confirm',1000); RAISE EXCEPTION 'wrong actor approved';
 EXCEPTION WHEN no_data_found THEN NULL; END;
 BEGIN PERFORM pg_temp.chat_action_call(editor,other_inv,proposal,'confirm',1000); RAISE EXCEPTION 'cross inventory approved';
 EXCEPTION WHEN insufficient_privilege OR no_data_found THEN NULL; END;
 -- Item limits and a bad second record roll back all additions and the receipt.
 BEGIN PERFORM pg_temp.chat_action_call(editor,inv,proposal,'confirm',1); RAISE EXCEPTION 'limit bypassed';
 EXCEPTION WHEN check_violation THEN NULL; END;
 proposal:=pg_temp.chat_proposal(editor,inv,'add',proposed_rows||jsonb_build_array((proposed_rows->0)||'{"quantity":-1}'));
 BEGIN PERFORM pg_temp.chat_action_call(editor,inv,proposal,'confirm',1000); RAISE EXCEPTION 'partial add committed';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.items WHERE inventory_id=inv),'invalid second row rolls back first insertion');
 PERFORM pg_temp.check((pg_temp.chat_action_call(editor,inv,proposal,'read',null)->>'status')='pending','failed addition has no success receipt');
 -- Snapshot checks cover rename, movement, quantity and notes before deletion.
 SELECT jsonb_build_array(jsonb_build_object('item_id',i.item_id,'name',i.name,'quantity',i.quantity,'location',i.location,'snapshot',public.findez_chat_item_fingerprint(to_jsonb(i)))) INTO proposed_rows
 FROM public.items i WHERE i.item_id=selected_item;
 proposal:=pg_temp.chat_proposal(editor,inv,'delete',proposed_rows);
 UPDATE public.items SET quantity=4 WHERE public.items.item_id=selected_item;
 BEGIN PERFORM pg_temp.chat_action_call(editor,inv,proposal,'confirm',null); RAISE EXCEPTION 'stale selection deleted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM pg_temp.check(EXISTS(SELECT 1 FROM public.items i WHERE i.item_id=selected_item AND quantity=4),'changed item survives stale deletion');
 -- New matching proposed_rows are never swept into a frozen deletion.
 INSERT INTO public.items(item_id,user_id,inventory_id,name,category,quantity,location,space_id)
 VALUES(gen_random_uuid(),owner,inv,'Chat bolt','Hardware',3,'Chat shelf',place) RETURNING public.items.item_id INTO third;
 SELECT jsonb_build_array(jsonb_build_object('item_id',i.item_id,'name',i.name,'quantity',i.quantity,'location',i.location,'snapshot',public.findez_chat_item_fingerprint(to_jsonb(i)))) INTO proposed_rows
 FROM public.items i WHERE i.item_id=selected_item;
 proposal:=pg_temp.chat_proposal(editor,inv,'delete',proposed_rows);
 result:=pg_temp.chat_action_call(editor,inv,proposal,'confirm',null);
 replay:=pg_temp.chat_action_call(editor,inv,proposal,'confirm',null);
 PERFORM pg_temp.check(result=replay AND (result->'receipt'->>'count')::int=1,'deletion retry has one durable receipt');
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.items i WHERE i.item_id=selected_item) AND EXISTS(SELECT 1 FROM public.items i WHERE i.item_id=third),'deletion affects only reviewed IDs');
 -- Permission revocation between proposal and confirmation wins.
 proposed_rows:=jsonb_build_array(jsonb_build_object('name','Revoked addition','category','Hardware','quantity',1,'location','Chat shelf','space_id',place));
 proposal:=pg_temp.chat_proposal(editor,inv,'add',proposed_rows);
 UPDATE public.team_memberships SET role='viewer' WHERE team_id=ws AND user_id=editor;
 BEGIN PERFORM pg_temp.chat_action_call(editor,inv,proposal,'confirm',1000); RAISE EXCEPTION 'revoked Editor wrote';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.team_memberships SET role='member' WHERE team_id=ws AND user_id=editor;
 -- Photo additions retain crop first and original second, with private access.
 source:='https://storage.test/storage/v1/object/public/item-images/'||editor||'/chat-original.jpg';
 crop:='https://storage.test/storage/v1/object/public/item-images/'||editor||'/chat-crop.jpg';
 PERFORM public.findez_register_image_preview(editor,inv,editor||'/chat-original.jpg');
 PERFORM public.findez_register_image_preview(editor,inv,editor||'/chat-crop.jpg');
 proposed_rows:=jsonb_build_array((proposed_rows->0)||jsonb_build_object('name','Photo bolt','image_url',crop,'source_frame_url',source));
 proposal:=pg_temp.chat_proposal(editor,inv,'add',proposed_rows);
 PERFORM pg_temp.check(public.findez_can_read_item_image(editor,editor||'/chat-crop.jpg'),'pending crop stays private and readable to its actor');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(viewer,editor||'/chat-crop.jpg'),'pending crop is not exposed to teammates before confirmation');
 result:=pg_temp.chat_action_call(editor,inv,proposal,'confirm',1000);
 selected_item:=(result->'receipt'->'items'->0->>'item_id')::uuid;
 PERFORM pg_temp.check((SELECT image_url=crop FROM public.items i WHERE i.item_id=selected_item),'photo addition stores crop as primary');
 PERFORM pg_temp.check((SELECT count(*)=1 FROM public.item_events e WHERE e.item_id=selected_item AND image_url=source AND content='Original scan photo'),'photo original retained once');
 PERFORM pg_temp.check(public.findez_can_read_item_image(viewer,editor||'/chat-original.jpg'),'authorized teammate can view original');
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image('d4000000-0000-0000-0000-000000000008',editor||'/chat-original.jpg'),'copied original URL grants outsider no access');
END $$;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);

-- Every dependent write must acknowledge its row, or the entire action rolls back.
CREATE FUNCTION pg_temp.skip_chat_qa_write() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END $$;
DO $$
DECLARE actor uuid; inv uuid; place uuid; proposed uuid; rows jsonb; original_count integer; table_name text; crop text; source text;
BEGIN
 SELECT id INTO actor FROM chat_action_demo WHERE key='editor';
 SELECT id INTO inv FROM chat_action_demo WHERE key='inventory';
 SELECT id INTO place FROM chat_action_demo WHERE key='space';
 rows:=jsonb_build_array(jsonb_build_object('name','Atomic QA item','category','Other','quantity',1,'location','Chat shelf','space_id',place));
 FOREACH table_name IN ARRAY ARRAY['items','app_access_audit','messages'] LOOP
  proposed:=pg_temp.chat_proposal(actor,inv,'add',rows);
  SELECT count(*) INTO original_count FROM public.items WHERE inventory_id=inv;
  EXECUTE format('CREATE TRIGGER chat_qa_skip BEFORE %s ON public.%I FOR EACH ROW EXECUTE FUNCTION pg_temp.skip_chat_qa_write()',CASE WHEN table_name='messages' THEN 'UPDATE' ELSE 'INSERT' END,table_name);
  BEGIN
   PERFORM pg_temp.chat_action_call(actor,inv,proposed,'confirm',1000);
   RAISE EXCEPTION 'a skipped % write was accepted',table_name;
  EXCEPTION WHEN check_violation THEN NULL; END;
  EXECUTE format('DROP TRIGGER chat_qa_skip ON public.%I',table_name);
  PERFORM pg_temp.check((SELECT count(*)=original_count FROM public.items WHERE inventory_id=inv),'skipped dependent write rolls back all items');
  PERFORM pg_temp.check((pg_temp.chat_action_call(actor,inv,proposed,'read',null)->>'status')='pending','skipped dependent write leaves no success receipt');
 END LOOP;
 -- Expiry and a deliberate inventory override both defeat inherited Editor.
 proposed:=pg_temp.chat_proposal(actor,inv,'add',rows);
 UPDATE public.messages SET answer_context=jsonb_set(answer_context,ARRAY['pending_actions','0','expires_at'],to_jsonb((now()-interval '1 second')::text))
  WHERE answer_context->'pending_actions'->0->>'id'=proposed::text;
 BEGIN PERFORM pg_temp.chat_action_call(actor,inv,proposed,'confirm',1000); RAISE EXCEPTION 'expired action accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
 proposed:=pg_temp.chat_proposal(actor,inv,'add',rows);
 INSERT INTO public.app_inventory_members(inventory_id,user_id,role) VALUES(inv,actor,'none');
 BEGIN PERFORM pg_temp.chat_action_call(actor,inv,proposed,'confirm',1000); RAISE EXCEPTION 'explicit No access accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.app_inventory_members SET role='viewer' WHERE inventory_id=inv AND user_id=actor;
 BEGIN PERFORM pg_temp.chat_action_call(actor,inv,proposed,'confirm',1000); RAISE EXCEPTION 'custom Viewer accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 DELETE FROM public.app_inventory_members WHERE inventory_id=inv AND user_id=actor;
 -- A skipped original-photo write must not leave an item with a partial gallery.
 crop:=actor||'/chat-atomic-crop.jpg'; source:=actor||'/chat-atomic-original.jpg';
 PERFORM public.findez_register_image_preview(actor,inv,crop);
 PERFORM public.findez_register_image_preview(actor,inv,source);
 rows:=jsonb_build_array((rows->0)||jsonb_build_object('image_url','https://storage.test/storage/v1/object/public/item-images/'||crop,
  'source_frame_url','https://storage.test/storage/v1/object/public/item-images/'||source));
 proposed:=pg_temp.chat_proposal(actor,inv,'add',rows);
 SELECT count(*) INTO original_count FROM public.items WHERE inventory_id=inv;
 CREATE TRIGGER chat_qa_skip BEFORE INSERT ON public.item_events FOR EACH ROW EXECUTE FUNCTION pg_temp.skip_chat_qa_write();
 BEGIN PERFORM pg_temp.chat_action_call(actor,inv,proposed,'confirm',1000); RAISE EXCEPTION 'partial photo gallery committed'; EXCEPTION WHEN check_violation THEN NULL; END;
 DROP TRIGGER chat_qa_skip ON public.item_events;
 PERFORM pg_temp.check((SELECT count(*)=original_count FROM public.items WHERE inventory_id=inv),'missing original photo rolls back new item');
 PERFORM pg_temp.chat_action_call(actor,inv,proposed,'cancel',null);
 PERFORM pg_temp.check(NOT public.findez_can_read_item_image(actor,crop),'cancel ends pending crop grant');
 -- Unknown quantities remain unknown in the reviewed selection, and can be
 -- deleted without JSON null being confused with SQL NULL during comparison.
 INSERT INTO public.items(item_id,user_id,inventory_id,name,category,quantity,location,space_id)
 VALUES(gen_random_uuid(),(SELECT id FROM chat_action_demo WHERE key='owner'),inv,'Unknown quantity QA','Other',-1,'Chat shelf',place);
 SELECT public.findez_chat_delete_snapshot(actor,inv,ARRAY[(SELECT item_id FROM public.items WHERE inventory_id=inv AND name='Unknown quantity QA')]) INTO rows;
 PERFORM pg_temp.check(rows->0->'quantity'='null'::jsonb,'review preserves unknown quantity');
 proposed:=pg_temp.chat_proposal(actor,inv,'delete',rows);
 PERFORM pg_temp.chat_action_call(actor,inv,proposed,'confirm',null);
 PERFORM pg_temp.check(NOT EXISTS(SELECT 1 FROM public.items WHERE inventory_id=inv AND name='Unknown quantity QA'),'unknown quantity does not block reviewed deletion');
END $$;
SELECT set_config('request.jwt.claims','{}',false);
SELECT set_config('request.headers','{}',false);

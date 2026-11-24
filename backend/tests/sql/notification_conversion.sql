\ir ../../supabase/migrations/20261125_04_notification_conversion.sql
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); n uuid; t uuid[]; i int;
BEGIN
 INSERT INTO auth.users VALUES(u); INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(v,u); INSERT INTO test_grants VALUES(u,v,'owner');
 PERFORM findez_notification_activity(u);
 UPDATE notification_preferences SET cleanup_insights=true WHERE user_id=u;
 INSERT INTO items(item_id,inventory_id,user_id) SELECT gen_random_uuid(),v,u FROM generate_series(1,4);
 SELECT array_agg(item_id) INTO t FROM items WHERE inventory_id=v;
 INSERT INTO personalization_notifications(user_id,inventory_id,policy_version,category,entity_type,entity_id,condition_key,action_targets,attempted_at,accepted_at,state)
 VALUES(u,v,1,'discovery','item',t[1],'conversion',t,now(),now(),'accepted') RETURNING id INTO n;
 ASSERT NOT findez_personalization_feedback(gen_random_uuid(),n,'push_tapped');
 ASSERT findez_personalization_feedback(u,n,'push_tapped'); ASSERT findez_personalization_feedback(u,n,'push_tapped');
 ASSERT findez_personalization_feedback(u,n,'destination_opened');
 ASSERT NOT EXISTS(SELECT FROM notification_action_results WHERE notification_id=n);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u)::text,true);
 FOR i IN 1..3 LOOP UPDATE items SET location='Drawer' WHERE item_id=t[i]; END LOOP;
 UPDATE items SET location='Other drawer' WHERE item_id=t[1];
 ASSERT (SELECT count(*)=3 FROM notification_action_results WHERE notification_id=n);
 ASSERT (SELECT action_started_at IS NOT NULL AND workflow_finished_at IS NULL FROM personalization_notifications WHERE id=n);
 ASSERT jsonb_array_length(findez_personalization_destination(u,n)->'remaining_ids')=1;
 UPDATE items SET location='Drawer' WHERE item_id=t[4];
 ASSERT (SELECT workflow_finished_at IS NOT NULL FROM personalization_notifications WHERE id=n);
 ASSERT findez_personalization_destination(u,n) IS NULL;
 ASSERT NOT has_function_privilege('authenticated','findez_notification_activity(uuid)','execute');
END $$;
ROLLBACK;

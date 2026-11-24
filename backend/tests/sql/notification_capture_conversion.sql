BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); n uuid; review uuid:=gen_random_uuid(); other_id uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users VALUES(u);
 INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(v,u);
 INSERT INTO test_grants VALUES(u,v,'owner');
 INSERT INTO notification_preferences(user_id,reengagement) VALUES(u,true);
 INSERT INTO items(item_id,inventory_id,user_id,created_at) VALUES(gen_random_uuid(),v,u,now()-interval '4 days');
 INSERT INTO personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key,policy_version,accepted_at,state)
 VALUES(u,v,'snap','inventory',v,'capture-test',1,now(),'accepted') RETURNING id INTO n;
 ASSERT findez_personalization_feedback(u,n,'destination_opened');
 ASSERT NOT findez_personalization_feedback(u,n,'scan_saved');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u)::text,true);
 INSERT INTO capture_reviews VALUES(review,v,u,'pending');
 ASSERT (SELECT count(*)=1 FROM notification_action_results WHERE notification_id=n AND action='capture_queued');
 ASSERT (SELECT workflow_finished_at IS NULL FROM personalization_notifications WHERE id=n);
 INSERT INTO items(item_id,inventory_id,user_id) VALUES(other_id,v,u);
 ASSERT NOT findez_tip_active(u,v,'snap',v);
 ASSERT findez_personalization_feedback(u,n,'scan_saved');
 ASSERT findez_personalization_feedback(u,n,'scan_saved');
 ASSERT (SELECT count(*)=1 FROM notification_action_results WHERE notification_id=n AND action='scan_saved');
END $$;
ROLLBACK;

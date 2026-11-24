\ir ../../supabase/migrations/20261125_03_notification_opportunities.sql
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); id uuid; target uuid;
BEGIN
 INSERT INTO auth.users VALUES(u); INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(v,u);
 INSERT INTO test_grants VALUES(u,v,'owner');
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations,inventory_push_actions)
 VALUES ('opportunity',u,'sandbox',true,now(),true,true);
 UPDATE notification_preferences SET cleanup_insights=true,reengagement=true,quiet_enabled=false WHERE user_id=u;
 INSERT INTO items(item_id,inventory_id,user_id,created_at) SELECT gen_random_uuid(),v,u,now()-interval '4 days' FROM generate_series(1,4);
 PERFORM findez_seed_inventory_pushes(100); PERFORM findez_seed_inventory_pushes(100);
 SELECT n.id INTO STRICT id FROM personalization_notifications n WHERE user_id=u AND category='discovery';
 ASSERT jsonb_array_length(findez_personalization_destination(u,id)->'remaining_ids')=4;
 ASSERT findez_personalization_destination(gen_random_uuid(),id) IS NULL;
 ASSERT findez_notification_content(id)->>'body' NOT LIKE '%4%';
 UPDATE notification_preferences SET show_details=true WHERE user_id=u;
 ASSERT findez_notification_content(id)->>'body' LIKE '4 records%';
 ASSERT findez_notification_inbox(u) @> '[{"category":"discovery"}]';
 SELECT entity_id INTO target FROM personalization_notifications WHERE user_id=u AND category='snap';
 ASSERT target=v;
 INSERT INTO items(item_id,inventory_id,user_id) VALUES(gen_random_uuid(),v,u);
 ASSERT NOT findez_tip_active(u,v,'snap',v);
 UPDATE notification_preferences SET cleanup_insights=false WHERE user_id=u;
 ASSERT findez_notification_content(id) IS NULL;
 UPDATE notification_preferences SET cleanup_insights=true WHERE user_id=u;
 DELETE FROM test_grants WHERE user_id=u;
 ASSERT findez_personalization_destination(u,id) IS NULL;
END $$;
-- One real gap and a record with a Space and zero quantity do not qualify as a batch.
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); first_gap uuid:=gen_random_uuid();
 second_gap uuid:=gen_random_uuid(); n personalization_notifications;
BEGIN
 INSERT INTO auth.users VALUES(u);
 INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(v,u);
 INSERT INTO test_grants VALUES(u,v,'owner');
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations)
 VALUES(u::text,u,'sandbox',true,now(),true);
 UPDATE notification_preferences SET cleanup_insights=true,weekly_recap=true,quiet_enabled=false WHERE user_id=u;
 INSERT INTO items(item_id,inventory_id,user_id,quantity,space_id)
 VALUES(first_gap,v,u,NULL,NULL),(gen_random_uuid(),v,u,0,gen_random_uuid());
 PERFORM findez_seed_inventory_pushes(100);
 ASSERT NOT EXISTS(SELECT FROM personalization_notifications WHERE user_id=u AND category IN ('discovery','weekly_insight'));
 INSERT INTO items(item_id,inventory_id,user_id) VALUES(second_gap,v,u);
 PERFORM findez_seed_inventory_pushes(100);
 ASSERT (SELECT count(*)=2 FROM personalization_notifications WHERE user_id=u AND category IN ('discovery','weekly_insight'));
 UPDATE items SET space_id=gen_random_uuid(),quantity=0 WHERE item_id=first_gap;
 FOR n IN SELECT * FROM personalization_notifications WHERE user_id=u AND category IN ('discovery','weekly_insight') LOOP
  ASSERT findez_discovery_remaining(n)=ARRAY[second_gap];
 END LOOP;
 DELETE FROM items WHERE item_id=second_gap;
 FOR n IN SELECT * FROM personalization_notifications WHERE user_id=u AND category IN ('discovery','weekly_insight') LOOP
  ASSERT findez_notification_content(n.id) IS NULL;
 END LOOP;
END $$;
ROLLBACK;

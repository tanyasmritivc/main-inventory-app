\ir ../../supabase/migrations/20261124_daily_inventory_actions.sql
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); inv uuid:=gen_random_uuid(); item uuid:=gen_random_uuid();
 n uuid; plan jsonb; banner jsonb; dest jsonb; d date:=(now() AT TIME ZONE 'UTC')::date; review uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users VALUES(u),(other_user);
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations)
 VALUES('focus-fixture',u,'sandbox',true,now(),true);
 UPDATE notification_preferences SET timezone='UTC',quiet_enabled=false WHERE user_id=u;
 INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(inv,u);
 INSERT INTO test_grants VALUES(u,inv,'owner');
 ASSERT findez_choose_daily_focus(u,d,gen_random_uuid()) IS NULL;
 UPDATE notification_preferences SET reengagement=true WHERE user_id=u;
 UPDATE push_devices SET inventory_push_actions=true WHERE user_id=u;
 ASSERT findez_choose_daily_focus(u,d,gen_random_uuid())->>'kind'='add_item';
 INSERT INTO personalization_notifications(user_id,category,entity_type,entity_id,condition_key,policy_version,accepted_at,state)
 VALUES(u,'daily_inventory','account',gen_random_uuid(),'daily-inventory/'||(d-1)::text,1,now()-interval '1 day','accepted');
 ASSERT findez_choose_daily_focus(u,d,gen_random_uuid())->>'kind'='snap';
 INSERT INTO items(item_id,inventory_id,user_id,name,quantity,location,created_at)
 VALUES(item,inv,u,'M4 screws',3,NULL,now()-interval '2 weeks');
 INSERT INTO notification_stock_rules(user_id,item_id,threshold) VALUES(u,item,4);
 INSERT INTO personalization_notifications(user_id,category,entity_type,entity_id,condition_key,policy_version)
 VALUES(u,'daily_inventory','account',gen_random_uuid(),'daily-inventory/'||d::text,1) RETURNING id INTO n;
 SELECT findez_notification_content(n),findez_personalization_destination(u,n) INTO banner,dest;
 ASSERT (banner->>'direct')::boolean AND banner->>'title'='Time for a stock check';
 ASSERT (banner->>'body') NOT LIKE '%M4%';
 ASSERT dest->>'entity_id'=item::text AND dest->>'entity_type'='item';
 UPDATE notification_preferences SET show_details=true WHERE user_id=u;
 ASSERT findez_notification_content(n)->>'body' LIKE '%M4 screws%3%';
 ASSERT findez_personalization_destination(other_user,n) IS NULL;
 UPDATE items SET quantity=20 WHERE item_id=item;
 ASSERT findez_choose_daily_focus(u,d,n)->>'kind'='location';
 UPDATE items SET location='Drawer A',quantity=NULL WHERE item_id=item;
 ASSERT findez_choose_daily_focus(u,d,n)->>'kind'='quantity';
 UPDATE items SET quantity=4,created_at=now() WHERE item_id=item;
 DELETE FROM notification_stock_rules WHERE user_id=u;
 ASSERT findez_choose_daily_focus(u,d,n)->>'kind'='progress';
 INSERT INTO capture_reviews VALUES(review,inv,u,'pending');
 ASSERT findez_choose_daily_focus(u,d,n)->>'kind'='review';
 UPDATE capture_reviews SET status='complete' WHERE review_id=review;
 UPDATE items SET expires_on=d+2 WHERE item_id=item;
 ASSERT findez_choose_daily_focus(u,d,n)->>'kind'='expiry';
 UPDATE items SET expires_on=NULL,created_at=now()-interval '2 weeks' WHERE item_id=item;
 UPDATE notification_preferences SET reengagement=false WHERE user_id=u;
 ASSERT findez_choose_daily_focus(u,d,n)->>'kind'='rediscover';
 -- Previously sent ID keeps its original target, even if stock recovered.
 ASSERT findez_personalization_destination(u,n)->>'entity_id'=item::text;
 DELETE FROM test_grants WHERE user_id=u;
 ASSERT findez_personalization_destination(u,n)->>'entity_type'='account';
 ASSERT findez_notification_content(n)->>'body' NOT LIKE '%M4%';
 ASSERT NOT has_function_privilege('authenticated','findez_choose_daily_focus(uuid,date,uuid)','execute');
END $$;
ROLLBACK;

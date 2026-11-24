-- All times, records and provider responses below are synthetic. No network calls.
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); it uuid:=gen_random_uuid(); review uuid:=gen_random_uuid();
 d uuid; s uuid; photo uuid; req uuid; today date:=(now() AT TIME ZONE 'UTC')::date; policy notification_preferences;
BEGIN
 INSERT INTO auth.users VALUES(u);
 INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(v,u);
 INSERT INTO test_grants VALUES(u,v,'owner');
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations,inventory_push_actions)
 VALUES('journey',u,'sandbox',true,now(),true,true);
 UPDATE notification_preferences SET quiet_enabled=false,timezone='UTC',reengagement=true WHERE user_id=u RETURNING * INTO policy;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u)::text,true);
 INSERT INTO items(item_id,user_id,inventory_id,quantity,reorder_enabled,reorder_threshold,created_at)
 VALUES(it,u,v,20,true,3,now()-interval '7 days');
 INSERT INTO personalization_notifications(user_id,category,entity_type,entity_id,condition_key,policy_version)
 VALUES(u,'daily_inventory','account',gen_random_uuid(),'daily-inventory/'||today,1) RETURNING id INTO d;
 ASSERT findez_personalization_claim(d) IS NOT NULL;
 ASSERT findez_notification_begin_attempt(d,'journey',policy.revision);
 PERFORM findez_notification_finish(d,'accepted',NULL);
 UPDATE items SET quantity=3 WHERE item_id=it;
 SELECT id INTO STRICT s FROM personalization_notifications WHERE user_id=u AND category='low_stock';
 ASSERT findez_personalization_claim(s) IS NULL; -- spaced behind the noncritical daily push
 UPDATE notification_delivery_attempts SET reserved_at=now()-interval '3 hours' WHERE notification_id=d;
 UPDATE personalization_notifications SET scheduled_for=now() WHERE id=s;
 ASSERT findez_personalization_claim(s)->>'entity_id'=it::text;
 ASSERT findez_notification_begin_attempt(s,'journey',policy.revision);
 PERFORM findez_notification_finish(s,'accepted',NULL);
 UPDATE items SET quantity=2 WHERE item_id=it;
 ASSERT (SELECT count(*)=1 FROM personalization_notifications WHERE user_id=u AND category='low_stock');
 INSERT INTO capture_reviews VALUES(review,v,u,'pending');
 SELECT id INTO STRICT photo FROM personalization_notifications WHERE user_id=u AND category='scan_review';
 ASSERT (SELECT scheduled_for<=now() FROM personalization_notifications WHERE id=photo);
 -- A different account-day scenario with the daily send but no prior inventory event.
 UPDATE notification_delivery_attempts SET reserved_at=now()-interval '2 days' WHERE notification_id=s;
 ASSERT findez_personalization_claim(photo)->>'entity_id'=review::text;
 ASSERT findez_notification_begin_attempt(photo,'journey',policy.revision);
 PERFORM findez_notification_finish(photo,'accepted',NULL);
 ASSERT findez_personalization_claim(photo) IS NULL;
 -- A replenishment followed by a second crossing is a new event, but repeat-target cooldown protects the phone.
 INSERT INTO personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key,policy_version)
 VALUES(u,v,'low_stock','item',it,'second-crossing',1) RETURNING id INTO req;
 UPDATE notification_delivery_attempts SET reserved_at=now()-interval '3 hours' WHERE notification_id=s;
 UPDATE notification_channel_policy SET event_daily=5,event_gap=interval '0',spacing=interval '0';
 ASSERT findez_personalization_claim(req) IS NULL;
 ASSERT (SELECT suppression_reason='stock_cooldown' FROM personalization_notifications WHERE id=req);
 ASSERT (SELECT count(*)=3 FROM notification_delivery_attempts WHERE user_id=u AND state='accepted');
 UPDATE notification_preferences SET inventory_alerts=false WHERE user_id=u;
 ASSERT (SELECT daily_enabled FROM notification_preferences WHERE user_id=u);
 ASSERT findez_personalization_destination(u,d) IS NOT NULL;
 -- Apple's acceptance alone is never a tap or an action.
 ASSERT (SELECT bool_and(push_tapped_at IS NULL AND destination_at IS NULL AND workflow_finished_at IS NULL)
   FROM personalization_notifications WHERE user_id=u);
 PERFORM findez_seed_inventory_pushes(100);
 SELECT id INTO STRICT req FROM personalization_notifications WHERE user_id=u AND category='snap';
 PERFORM findez_notification_activity(u);
 ASSERT findez_notification_eligible(req,now())='active_session';
 INSERT INTO items(item_id,user_id,inventory_id) VALUES(gen_random_uuid(),u,v);
 ASSERT findez_notification_content(req) IS NULL;
END $$;
ROLLBACK;

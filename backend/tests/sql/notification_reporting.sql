\ir ../../supabase/migrations/20261125_05_notification_reporting.sql
BEGIN;
DO $$
DECLARE c jsonb; preview text; u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); n uuid; original text; report jsonb;
BEGIN
 INSERT INTO auth.users VALUES(u); INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES(v,u); INSERT INTO test_grants VALUES(u,v,'owner');
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations,inventory_push_actions)
 VALUES ('report',u,'sandbox',true,now(),true,true);
 UPDATE notification_preferences SET reengagement=true,quiet_enabled=false WHERE user_id=u;
 UPDATE notification_channel_policy SET add_experiment=true;
 PERFORM findez_seed_inventory_pushes(100); SELECT id,experiment_variant INTO STRICT n,original FROM personalization_notifications WHERE user_id=u;
 ASSERT original IN ('add-v1/A','add-v1/B');
 ASSERT findez_personalization_claim(n)->>'entity_type'='inventory';
 ASSERT (SELECT experiment_variant=original FROM personalization_notifications WHERE id=n);
 UPDATE push_devices SET conversion_events=true WHERE device_token='report';
 c:=findez_notification_content(n);
 preview:=encode(sha256(convert_to((c->>'title')||chr(31)||(c->>'body')||chr(31)||coalesce(c->>'direct','false'),'UTF8')),'hex');
 ASSERT NOT findez_notification_submit(n,'report',1,'stale');
 ASSERT findez_notification_submit(n,'report',1,preview);
 PERFORM findez_notification_receipt(n,'accepted',now()); PERFORM findez_notification_receipt(n,'accepted',now());
 PERFORM findez_notification_finish(n,'accepted',NULL);
 PERFORM findez_personalization_feedback(u,n,'push_tapped'); PERFORM findez_personalization_feedback(u,n,'destination_opened');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u)::text,true);
 INSERT INTO items(item_id,user_id,inventory_id) VALUES(gen_random_uuid(),u,v);
 ASSERT (SELECT count(*)=1 FROM notification_provider_receipts WHERE notification_id=n);
 report:=findez_notification_analytics();
 ASSERT EXISTS(SELECT FROM jsonb_array_elements(report->'groups') g WHERE g->>'variant'=original AND (g->>'attributed_additions')::int>=1 AND (g->>'tap_rate')::numeric=100);
 ASSERT EXISTS(SELECT FROM jsonb_array_elements(report->'groups') g WHERE g->>'variant'=original AND (g->>'additions_after_interaction')::int>=1);
 UPDATE notification_channel_policy SET add_experiment=false;
 INSERT INTO personalization_notifications(user_id,inventory_id,category,entity_type,entity_id,condition_key,policy_version)
 VALUES(u,v,'add_item','inventory',v,'next-experiment-off',1) RETURNING id INTO n;
 ASSERT (SELECT experiment_variant IS NULL FROM personalization_notifications WHERE id=n);
 ASSERT NOT has_function_privilege('authenticated','findez_notification_analytics()','execute');
END $$;
ROLLBACK;

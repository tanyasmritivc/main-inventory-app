-- Empty, disposable PostgreSQL database only. Reuse the real notification preferences and quiet-hours function.
\ir notification_policy.sql
ALTER TABLE auth.users ADD COLUMN created_at timestamptz DEFAULT now(), ADD COLUMN email text,
  ADD COLUMN email_confirmed_at timestamptz, ADD COLUMN banned_until timestamptz,
  ADD COLUMN deleted_at timestamptz, ADD COLUMN is_anonymous boolean DEFAULT false;
ALTER TABLE app_inventories ADD COLUMN owner_user_id uuid, ADD COLUMN team_id uuid, ADD COLUMN organization_id uuid;
ALTER TABLE items ADD COLUMN created_at timestamptz DEFAULT now();
ALTER TABLE capture_reviews ADD COLUMN created_at timestamptz DEFAULT now();
CREATE TABLE app_organizations(organization_id uuid PRIMARY KEY, owner_user_id uuid);
CREATE TABLE app_organization_members(organization_id uuid,user_id uuid);
CREATE TABLE teams(team_id uuid PRIMARY KEY,organization_id uuid);
CREATE TABLE team_memberships(team_id uuid,user_id uuid);
CREATE TABLE spaces(user_id uuid,inventory_id uuid,created_at timestamptz DEFAULT now());
CREATE TABLE app_physical_locations(team_id uuid);
CREATE TABLE connector_import_sessions(actor_id uuid,inventory_id uuid,kind text,tables jsonb,created_at timestamptz DEFAULT now());
CREATE TABLE activity_log(user_id uuid,inventory_id uuid,event_type text,metadata jsonb,created_at timestamptz DEFAULT now());
CREATE TABLE team_activity(actor_id uuid,team_id uuid,action text,created_at timestamptz DEFAULT now());
CREATE FUNCTION findez_default_inventory(actor uuid) RETURNS uuid LANGUAGE sql AS $$
 SELECT inventory_id FROM app_inventories WHERE owner_user_id=actor AND team_id IS NULL LIMIT 1
$$;
ALTER TABLE push_devices ADD COLUMN platform text DEFAULT 'ios', ADD COLUMN inventory_push_actions boolean DEFAULT false;
ALTER TABLE notification_preferences DROP CONSTRAINT notification_preferences_reengagement_check;

CREATE FUNCTION test_user(n int) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT md5('weekly fixture '||n)::uuid $$;
INSERT INTO auth.users(id,created_at,email,email_confirmed_at)
SELECT test_user(n),now()-interval '90 days','person'||n||'@example.invalid',now() FROM generate_series(1,7) n;
INSERT INTO app_organizations VALUES(test_user(41),test_user(4));
INSERT INTO app_organization_members VALUES(test_user(41),test_user(5));
INSERT INTO teams VALUES(test_user(31),test_user(41));
INSERT INTO team_memberships VALUES(test_user(31),test_user(6));
INSERT INTO app_inventories VALUES(test_user(22),test_user(2),NULL,NULL);
INSERT INTO spaces VALUES(test_user(2),test_user(22),now()-interval '80 days');
INSERT INTO team_activity VALUES(test_user(4),test_user(31),'item_deleted',now()-interval '20 days');
INSERT INTO activity_log VALUES(test_user(3),NULL,'spreadsheet_import','{"inserted":3}',now()-interval '30 days');
INSERT INTO activity_log VALUES(test_user(1),NULL,'bulk_create','{"inserted":0}',now());
UPDATE auth.users SET email_confirmed_at=NULL WHERE id=test_user(7);

\ir ../../supabase/migrations/20261126_weekly_activation.sql
BEGIN;
DO $$
DECLARE r uuid; payload jsonb;
BEGIN
 ASSERT findez_activation_inactive(test_user(1));
 ASSERT NOT EXISTS(SELECT FROM generate_series(2,6) n WHERE findez_activation_inactive(test_user(n)));
 ASSERT (SELECT first_space_at IS NOT NULL FROM activation_accounts WHERE user_id=test_user(2));
 ASSERT NOT EXISTS(SELECT FROM findez_activation_channels(test_user(7),true,true));
 ASSERT NOT has_table_privilege('authenticated','activation_accounts','SELECT');
 ASSERT NOT has_function_privilege('authenticated','findez_activation_claim(boolean,boolean)','EXECUTE');
 INSERT INTO auth.users(id,created_at,email,email_confirmed_at) VALUES(test_user(8),now(),'new@example.invalid',now());
 ASSERT (SELECT next_due>=now()+interval '7 days' FROM activation_accounts WHERE user_id=test_user(8));

 INSERT INTO app_inventories VALUES(test_user(21),test_user(1),NULL,NULL);
 INSERT INTO notification_preferences(user_id,push_enabled,reengagement,quiet_enabled) VALUES(test_user(1),true,true,false);
 INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations,inventory_push_actions)
 VALUES('fixture',test_user(1),'sandbox',true,now(),true,true);
 r:=findez_activation_claim(true,true);
 ASSERT r IS NOT NULL AND findez_activation_claim(true,true) IS NULL;
 payload:=findez_activation_begin(r,true,true);
 ASSERT payload->>'channel'='email' AND payload->>'step'='1' AND (payload->>'cycle')::integer>=12;
 ASSERT findez_activation_begin(r,true,true) IS NULL;
 ASSERT findez_activation_destination(test_user(1),r) IS NULL;
 ASSERT (SELECT next_due>=now()+interval '168 hours' FROM activation_accounts WHERE user_id=test_user(1));

 -- Move the synthetic account forward one weekly cycle.
 UPDATE activation_accounts SET signed_up_at=signed_up_at-interval '7 days',next_due=now() WHERE user_id=test_user(1);
 r:=findez_activation_claim(true,true);
 payload:=findez_activation_begin(r,true,true);
 ASSERT payload->>'channel'='push' AND payload->>'step'='2';
 ASSERT findez_activation_destination(test_user(1),r)->>'quick_action'='first_item';
 ASSERT findez_activation_destination(test_user(7),r) IS NULL;
 UPDATE notification_preferences SET quiet_enabled=true,quiet_start=0,quiet_end=0 WHERE user_id=test_user(1);
 ASSERT NOT EXISTS(SELECT FROM findez_activation_channels(test_user(1),false,true));
 UPDATE notification_preferences SET quiet_enabled=false,paused_until=now()+interval '1 day' WHERE user_id=test_user(1);
 ASSERT NOT EXISTS(SELECT FROM findez_activation_channels(test_user(1),false,true));
 UPDATE notification_preferences SET paused_until=NULL,reengagement=false WHERE user_id=test_user(1);
 ASSERT NOT EXISTS(SELECT FROM findez_activation_channels(test_user(1),false,true));
 UPDATE activation_accounts SET signed_up_at=signed_up_at-interval '7 days',next_due=now() WHERE user_id=test_user(1);
 r:=findez_activation_claim(true,true);
 ASSERT r IS NOT NULL;
 UPDATE activation_accounts SET email_enabled=false WHERE user_id=test_user(1);
 ASSERT findez_activation_begin(r,true,true) IS NULL;
 ASSERT (SELECT outcome='cancelled' FROM activation_reminders WHERE id=r);

 INSERT INTO connector_import_sessions VALUES(test_user(1),test_user(21),'inventory','[]',now());
 ASSERT findez_activation_inactive(test_user(1));
 INSERT INTO connector_import_sessions VALUES(test_user(1),test_user(21),'inventory','[{"rows":[["x"]]}]',now());
 ASSERT NOT findez_activation_inactive(test_user(1));
 DELETE FROM connector_import_sessions;
 ASSERT NOT findez_activation_inactive(test_user(1));

 INSERT INTO app_inventories VALUES(test_user(28),test_user(8),NULL,NULL);
 INSERT INTO spaces VALUES(test_user(8),test_user(28),now());
 INSERT INTO items(item_id,user_id,inventory_id,name,quantity) VALUES(gen_random_uuid(),test_user(8),test_user(28),'fixture',1);
 DELETE FROM spaces WHERE user_id=test_user(8);
 DELETE FROM items WHERE user_id=test_user(8);
 ASSERT (SELECT first_item_at IS NOT NULL AND first_space_at IS NOT NULL FROM activation_campaign_metrics WHERE user_id=test_user(8));
 ASSERT NOT findez_activation_inactive(test_user(8));
 -- An opt-in alone is insufficient with a stale device registration.
 UPDATE notification_preferences SET reengagement=true WHERE user_id=test_user(1);
 UPDATE push_devices SET updated_at=now()-interval '91 days' WHERE user_id=test_user(1);
 ASSERT NOT EXISTS(SELECT FROM findez_activation_channels(test_user(1),false,true));

 -- Activation after reservation cancels delivery.
 INSERT INTO auth.users(id,created_at,email,email_confirmed_at) VALUES(test_user(9),now()-interval '8 days','claim@example.invalid',now());
 r:=findez_activation_claim(true,false);
 ASSERT r IS NOT NULL;
 INSERT INTO activity_log VALUES(test_user(9),NULL,'scan_image','{"total_detected":2}',now());
 ASSERT findez_activation_begin(r,true,false) IS NULL;
 ASSERT (SELECT outcome='cancelled' FROM activation_reminders WHERE id=r);
 DELETE FROM activity_log WHERE user_id=test_user(9);
 ASSERT NOT findez_activation_inactive(test_user(9));

 INSERT INTO app_organization_members VALUES(test_user(41),test_user(7));
 ASSERT NOT findez_activation_inactive(test_user(7));
END $$;
SET LOCAL ROLE service_role;
SELECT findez_activation_claim(true,true);
ROLLBACK;

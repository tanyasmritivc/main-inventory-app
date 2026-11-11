-- EMPTY DISPOSABLE DATABASE ONLY.
\ir commerce.sql
CREATE TABLE public.app_organizations(organization_id uuid PRIMARY KEY);
CREATE TABLE public.app_organization_members(organization_id uuid REFERENCES app_organizations,user_id uuid REFERENCES auth.users ON DELETE CASCADE,role text,PRIMARY KEY(organization_id,user_id));
INSERT INTO auth.users VALUES('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002'),('10000000-0000-0000-0000-000000000003') ON CONFLICT DO NOTHING;
INSERT INTO app_organizations VALUES('30000000-0000-0000-0000-000000000001');
INSERT INTO app_organization_members VALUES('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','owner'),('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','admin'),('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003','member');
INSERT INTO test_grants VALUES('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','owner');
INSERT INTO commerce_connections(actor_id,inventory_id,provider,external_account,status) VALUES('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','amazon_consumer','old-export','connected') RETURNING id AS old_id \gset
INSERT INTO commerce_source_records VALUES(:'old_id','purchase_line','order:item','purchases','{"title":"Motor","physically_verified":false}',now());
INSERT INTO commerce_connections(actor_id,inventory_id,provider,external_account,status) VALUES('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','amazon_consumer','revoked-export','connected') RETURNING id AS revoked_id \gset
\ir ../../supabase/migrations/20261111_commerce_ownership.sql
\ir ../../supabase/migrations/20261111_commerce_ownership.sql
SELECT pg_temp.check((SELECT scope_type='personal' AND inventory_id IS NULL AND owner_user_id=actor_id AND organization_id IS NULL FROM commerce_connections WHERE id=:'old_id'),'legacy upload becomes private personal, not organization');
SELECT pg_temp.check((SELECT count(*)=1 FROM commerce_source_records WHERE connection_id=:'old_id'),'migration preserves history');
SELECT pg_temp.check((SELECT scope_type='legacy_inventory' AND NOT findez_commerce_can_access(c,'10000000-0000-0000-0000-000000000002') FROM commerce_connections c WHERE id=:'revoked_id'),'migration never restores revoked inventory access');
SELECT pg_temp.check((SELECT bool_and(c.scope_type='legacy_inventory') FROM commerce_connections c JOIN commerce_gmail_accounts g ON g.connection_id=c.id),'Gmail connections retain legacy scope');
SELECT pg_temp.check((SELECT NOT findez_commerce_can_access(c,'10000000-0000-0000-0000-000000000002') FROM commerce_connections c WHERE id=:'old_id'),'organization admin cannot read personal history');
SELECT pg_temp.check(findez_commerce_start_scoped('10000000-0000-0000-0000-000000000001','personal',NULL,'amazon_consumer','personal','','','')->>'id'=:'old_id','new uploads reuse migrated personal destination');
SELECT findez_commerce_start_scoped('10000000-0000-0000-0000-000000000001','organization','30000000-0000-0000-0000-000000000001','amazon_consumer','org','','','')->>'id' AS org_id \gset
SELECT pg_temp.check((SELECT owner_user_id IS NULL AND inventory_id IS NULL FROM commerce_connections WHERE id=:'org_id'),'organization connection has no inventory or personal owner');
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000002',:'org_id','sync_claim')->>'lease_id' AS lease \gset
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000002',:'org_id','commit',jsonb_build_object('lease_id',:'lease','resource','purchases','records','[{"kind":"purchase_line","external_id":"order:item","physically_verified":false}]'::jsonb));
SELECT pg_temp.check((SELECT count(*)=1 FROM commerce_source_records WHERE connection_id=:'org_id'),'another organization admin may import');
SELECT pg_temp.denied(format('SELECT findez_commerce_transition(%L,%L,%L)','10000000-0000-0000-0000-000000000003',:'org_id','disconnect'),'ordinary organization member cannot delete');
SELECT findez_commerce_transition('10000000-0000-0000-0000-000000000002',:'org_id','sync_claim')->>'lease_id' AS lease \gset
DELETE FROM app_organization_members WHERE user_id='10000000-0000-0000-0000-000000000002';
SELECT pg_temp.denied(format('SELECT findez_commerce_transition(%L,%L,%L,%L::jsonb)','10000000-0000-0000-0000-000000000002',:'org_id','commit',jsonb_build_object('lease_id',:'lease','resource','purchases','records','[]'::jsonb)),'revoked admin cannot commit in-flight import');
SELECT pg_temp.denied(format('SELECT findez_commerce_transition(%L,%L,%L)','10000000-0000-0000-0000-000000000002',:'org_id','disconnect'),'revoked admin cannot delete');
SELECT pg_temp.denied($q$SELECT findez_commerce_start_scoped('10000000-0000-0000-0000-000000000003','organization','30000000-0000-0000-0000-000000000001','shopify','deny.myshopify.com','','','')$q$,'member cannot create connection');
SET ROLE authenticated;
SELECT pg_temp.denied('SELECT * FROM commerce_connections','RLS and grants still block browser reads');
SELECT pg_temp.denied($q$SELECT findez_commerce_start_scoped('10000000-0000-0000-0000-000000000001','personal',NULL,'amazon_consumer','spoof','','','')$q$,'browser cannot impersonate actor in scoped RPC');
RESET ROLE;
DELETE FROM auth.users WHERE id='10000000-0000-0000-0000-000000000001';
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_connections WHERE id=:'old_id'),'account deletion removes private history');
SELECT pg_temp.check((SELECT actor_id IS NULL FROM commerce_connections WHERE id=:'org_id'),'organization history survives creator account deletion');
DELETE FROM app_organization_members;
DELETE FROM app_organizations;
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_connections WHERE id=:'org_id'),'organization deletion removes its connections');

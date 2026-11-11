-- Included by commerce.sql in its empty disposable database only.
\ir ../../supabase/migrations/20261111_purchase_email.sql
\ir ../../supabase/migrations/20261111_purchase_email.sql
SELECT pg_temp.denied($q$SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','start','{}')$q$,'Gmail nonmember denied');
SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','start','{"state_hash":"state","verifier_ciphertext":"encrypted"}')->>'connection_id' AS gc \gset
SELECT pg_temp.denied(format($q$SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','claim',%L::jsonb)$q$,jsonb_build_object('connection_id',:'gc','state_hash','wrong')::text),'Gmail state mismatch denied');
SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','claim',jsonb_build_object('connection_id',:'gc','state_hash','state'))->>'lease' AS gl \gset
SELECT pg_temp.denied(format($q$SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','claim',%L::jsonb)$q$,jsonb_build_object('connection_id',:'gc','state_hash','state')::text),'Gmail state replay denied');
SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','finish',jsonb_build_object('lease',:'gl','token_ciphertext','encrypted-token','email','test@example.test'));
SELECT pg_temp.check((SELECT verifier_ciphertext IS NULL AND state_hash IS NULL FROM commerce_gmail_accounts WHERE connection_id=:'gc'),'OAuth verifier removed after exchange');
SELECT findez_gmail_job('claim')->>'lease' AS synclease \gset
SELECT pg_temp.check(findez_gmail_job('claim') IS NULL,'concurrent Gmail poll denied');
SELECT findez_gmail_job('commit',jsonb_build_object('connection_id',:'gc','lease',:'synclease','cursor','{}'::jsonb,'messages','[{"email_id":"m1","body_ciphertext":"encrypted-body"}]'::jsonb));
UPDATE commerce_gmail_accounts SET next_poll_at=now() WHERE connection_id=:'gc';
SELECT findez_gmail_job('claim')->>'lease' AS synclease \gset
SELECT findez_gmail_job('commit',jsonb_build_object('connection_id',:'gc','lease',:'synclease','cursor','{}'::jsonb,'messages','[{"email_id":"m1","body_ciphertext":"encrypted-body"}]'::jsonb));
SELECT pg_temp.check((SELECT count(*)=1 FROM commerce_purchase_emails),'repeat Gmail message queues once');
SELECT findez_purchase_email_job('claim') AS mailjob \gset
SELECT pg_temp.check(findez_purchase_email_job('claim') IS NULL,'concurrent extraction denied');
SELECT findez_purchase_email_job('finish',:'mailjob'::jsonb || jsonb_build_object('content_hash',repeat('a',64),'result','{"lines":[{"title":"motor","quantity":2,"status":"purchased"}]}'::jsonb));
SELECT pg_temp.check((SELECT body_ciphertext IS NULL AND status='ready' FROM commerce_purchase_emails LIMIT 1),'raw body discarded after extraction');
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_source_records),'mail extraction never mutates stock or merchant records');
UPDATE commerce_gmail_accounts SET next_poll_at=now() WHERE connection_id=:'gc';
SELECT findez_gmail_job('claim')->>'lease' AS synclease \gset
SELECT findez_gmail_job('commit',jsonb_build_object('connection_id',:'gc','lease',:'synclease','cursor','{}'::jsonb,'messages','[{"email_id":"m2","body_ciphertext":"encrypted-body"}]'::jsonb));
SELECT findez_purchase_email_job('claim') AS mailjob \gset
SELECT findez_purchase_email_job('finish',:'mailjob'::jsonb || jsonb_build_object('content_hash',repeat('a',64),'result','{"lines":[]}'::jsonb));
SELECT pg_temp.check((SELECT count(*)=1 FROM commerce_purchase_emails WHERE status='ready'),'same content from another message does not duplicate evidence');
UPDATE commerce_gmail_accounts SET next_poll_at=now() WHERE connection_id=:'gc';
SELECT findez_gmail_job('claim')->>'lease' AS synclease \gset
SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','disconnect');
SELECT pg_temp.denied(format($q$SELECT findez_gmail_job('tokens',%L::jsonb)$q$,jsonb_build_object('connection_id',:'gc','lease',:'synclease','token_ciphertext','late')::text),'disconnect defeats late refresh');
SELECT pg_temp.check((SELECT token_ciphertext IS NULL FROM commerce_gmail_accounts WHERE connection_id=:'gc'),'disconnect removes tokens');
DELETE FROM test_grants;
SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','purge');
SELECT pg_temp.check((SELECT count(*)=0 FROM commerce_purchase_emails),'purge allowed after membership revocation');
SET ROLE authenticated;
SELECT pg_temp.denied('SELECT * FROM commerce_gmail_accounts','client cannot read Gmail tokens');
SELECT pg_temp.denied('SELECT * FROM commerce_purchase_emails','client cannot read another mailbox');
SELECT pg_temp.denied($q$SELECT findez_gmail_manage('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','purge')$q$,'client cannot impersonate Gmail actor');
SELECT pg_temp.denied($q$SELECT findez_purchase_email_job('claim')$q$,'client cannot claim purchase emails');
RESET ROLE;
SELECT pg_temp.check((SELECT bool_and(relrowsecurity) FROM pg_class WHERE relname IN ('commerce_gmail_accounts','commerce_purchase_emails')),'Gmail private tables use RLS');

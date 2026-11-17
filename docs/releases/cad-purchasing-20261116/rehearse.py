from pathlib import Path
import subprocess as sp, time, uuid, os, json
os.umask(0o077)
root=Path('/home/ubuntu/findez-cad-purchasing-20261116');root.mkdir(exist_ok=True)
name='findez-cad-rehearsal-'+uuid.uuid4().hex[:10]
def run(args,**kw):return sp.run(args,check=True,**kw)
def sql(query,container=name):
 r=sp.run(['docker','exec','-i',container,'psql','-X','-h','/var/run/postgresql' if container=='supabase-db' else '/tmp','-U','postgres','-d','postgres','-Atq','-v','ON_ERROR_STOP=1'],input=query,text=True,capture_output=True)
 if r.returncode:
  (root/'sql-error.log').write_text(r.stderr);raise RuntimeError('Inspect private sql-error.log')
 return r.stdout.strip()
with (root/'database-before.dump').open('wb') as out:
 run(['docker','exec','supabase-db','pg_dump','-U','postgres','-d','postgres','-Fc'],stdout=out)
roles=sql("SELECT 'CREATE ROLE '||quote_ident(rolname)||' '||CASE WHEN rolsuper THEN 'SUPERUSER ' ELSE '' END||CASE WHEN rolbypassrls THEN 'BYPASSRLS ' ELSE '' END||';' FROM pg_roles WHERE rolname NOT LIKE 'pg_%' AND rolname<>'postgres';",'supabase-db')
print('Fresh read-only production backup retained privately on server.',flush=True)
try:
 run(['docker','run','-d','--name',name,'--network','none','--label','codex-task=cad-bom-rehearsal','--entrypoint','bash','--user','postgres','supabase/postgres:17.6.1.136','-lc','initdb -D /tmp/rehearsal-db -A trust --no-instructions >/tmp/init.log 2>&1 && exec postgres -D /tmp/rehearsal-db -k /tmp -c listen_addresses="" >/tmp/postgres.log 2>&1'],stdout=sp.DEVNULL)
 for _ in range(100):
  if sp.run(['docker','exec',name,'pg_isready','-h','/tmp'],stdout=sp.DEVNULL,stderr=sp.DEVNULL).returncode==0:break
  time.sleep(.2)
 else:raise RuntimeError('Rehearsal database did not start')
 sql(roles)
 sql('CREATE SCHEMA auth; CREATE SCHEMA extensions; CREATE SCHEMA storage; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;')
 run(['docker','cp',str(root/'database-before.dump'),name+':/tmp/database.dump'])
 run(['docker','exec','--user','root',name,'chmod','644','/tmp/database.dump'])
 restored=sp.run(['docker','exec',name,'pg_restore','-h','/tmp','-U','postgres','-d','postgres','--no-owner','--schema=public','--schema=auth','--schema=extensions','--schema=storage','/tmp/database.dump'],capture_output=True)
 (root/'restore.log').write_bytes(restored.stdout+restored.stderr)
 if restored.returncode:raise RuntimeError('Inspect private restore.log')
 print('Restored into network-disabled disposable database.',flush=True)
 sql("""CREATE SCHEMA cad_rehearsal;
 CREATE TABLE cad_rehearsal.originals(schema_name text,table_name text,row_count bigint,digest text);
 DO $$ DECLARE t record; n bigint; h text; BEGIN
 FOR t IN SELECT schemaname,tablename FROM pg_tables WHERE schemaname IN ('public','auth','storage') LOOP
 EXECUTE format($q$SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'|' ORDER BY md5(to_jsonb(x)::text)),'')) FROM %I.%I x$q$,t.schemaname,t.tablename ) INTO n,h;
 INSERT INTO cad_rehearsal.originals VALUES(t.schemaname,t.tablename,n,h);
 END LOOP; END $$;
 CREATE TABLE cad_rehearsal.policies AS SELECT * FROM pg_policies;
 CREATE TABLE cad_rehearsal.functions AS SELECT p.oid,pg_get_functiondef(p.oid) definition,p.proacl::text acl FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','auth','storage') AND p.prokind='f';""")
 sql((root/'20261117_cad_purchasing.sql').read_text())
 receipt=sql("""DO $$ DECLARE t record; n bigint; h text; BEGIN
 FOR t IN SELECT * FROM cad_rehearsal.originals LOOP
 EXECUTE format($q$SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'|' ORDER BY md5(to_jsonb(x)::text)),'')) FROM %I.%I x$q$,t.schema_name,t.table_name ) INTO n,h;
 IF n<>t.row_count OR h<>t.digest THEN RAISE EXCEPTION 'Original values changed'; END IF;
 END LOOP;
 IF EXISTS(SELECT * FROM cad_rehearsal.policies EXCEPT SELECT * FROM pg_policies) THEN RAISE EXCEPTION 'Policy changed'; END IF;
 IF EXISTS(SELECT 1 FROM cad_rehearsal.functions f LEFT JOIN pg_proc p ON f.oid=p.oid WHERE p.oid IS NULL OR f.definition<>pg_get_functiondef(p.oid) OR f.acl IS DISTINCT FROM p.proacl::text) THEN RAISE EXCEPTION 'Existing function changed'; END IF;
 IF has_table_privilege('anon','cad_device_grants','SELECT') OR has_table_privilege('authenticated','cad_device_grants','SELECT') THEN RAISE EXCEPTION 'Token exposure'; END IF;
 IF has_table_privilege('authenticated','cad_purchase_plans','SELECT') OR has_table_privilege('anon','cad_purchase_events','SELECT') THEN RAISE EXCEPTION 'Purchase plans exposed'; END IF;
 IF has_table_privilege('authenticated','cad_bom_versions','SELECT') OR has_table_privilege('anon','cad_generation_jobs','SELECT') OR has_function_privilege('authenticated','findez_cad_can_write(uuid,uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'CAD access exposed'; END IF;
 END $$;
 SELECT jsonb_build_object('original_tables_verified',(SELECT count(*) FROM cad_rehearsal.originals),'original_rows_unchanged',true,'existing_policies_unchanged',true,'existing_functions_unchanged',true,'credential_table_private',true,'production_modified',false);""")
 (root/'rehearsal-results.json').write_text(receipt+'\n');print(receipt,flush=True)
 sql((root/'restored-workflow.sql').read_text()); print('Restored-schema approval and receiving workflow passed; synthetic transaction rolled back.',flush=True)
finally:
 sp.run(['docker','rm','-f',name],stdout=sp.DEVNULL,stderr=sp.DEVNULL)

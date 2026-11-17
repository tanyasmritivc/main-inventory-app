"""Apply only the reviewed migration after explicit user approval."""
from pathlib import Path
import hashlib
import json
import os
import subprocess as sp

os.umask(0o077)
root=Path('/home/ubuntu/findez-cad-native-planning-20261116')
migration=root/'20261118_cad_native_purchasing.sql'
expected='e722b5af9a7606828699936410f168aa06415c62e1bfe4723702532bf39441de'
assert hashlib.sha256(migration.read_bytes()).hexdigest()==expected
assert json.loads((root/'rehearsal-results.json').read_text())['original_rows_unchanged'] is True
assert sp.check_output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'],text=True).strip()=='/home/ubuntu/findez-cad-purchasing-20261116/frontend'
command=['docker','exec','-i','supabase-db','psql','-X','-U','postgres','-d','postgres','-Atq','-v','ON_ERROR_STOP=1']
def sql(query):return sp.check_output(command,input=query,text=True).strip()
assert sql("SELECT NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cad_device_grants' AND column_name='allow_purchasing')")=='t'
inventory_digest="SELECT md5(coalesce(string_agg(md5(jsonb_build_array(item_id,inventory_id,quantity)::text),'|' ORDER BY item_id),'')) FROM items"
before=sql(inventory_digest)
with (root/'database-activation.dump').open('xb') as backup:
    sp.run(['docker','exec','supabase-db','pg_dump','-U','postgres','-d','postgres','-Fc'],stdout=backup,check=True)
sql(migration.read_text())
assert sql(inventory_digest)==before,'Inventory changed during migration window; inspect before activation'
assert sql("SELECT NOT EXISTS(SELECT 1 FROM cad_device_grants WHERE allow_purchasing) AND NOT has_function_privilege('authenticated','findez_cad_native_purchase_action(uuid,uuid,uuid,uuid,text,uuid,text,integer,jsonb)','EXECUTE') AND NOT has_function_privilege('anon','findez_cad_device_approve_purchasing(text,uuid,uuid,boolean)','EXECUTE')")=='t'
sql("NOTIFY pgrst, 'reload schema'")
(root/'migration-applied.json').write_text(json.dumps({'migration_sha256':expected,'existing_stock_unchanged':True,'private_acl_verified':True,'approved_by_user':True},indent=2))
print('Approved migration applied. Existing stock unchanged; private permissions verified.')

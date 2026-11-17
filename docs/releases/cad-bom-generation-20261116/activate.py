"""Activate the explicitly approved CAD release with source guards and rollback."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import sys
import time
import urllib.request
import urllib.error
from cryptography.fernet import Fernet

os.umask(0o077)
root=Path('/home/ubuntu/findez-cad-bom-generation-20261116')
manifest=json.loads((root/'manifest.json').read_text())
receipt=json.loads((root/'preparation.json').read_text())
backend=Path('/home/ubuntu/findez/backend');front=root/'frontend'
def run(args,**kw):return sp.run(args,check=True,**kw)
def output(args):return sp.check_output(args,text=True).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
def sql(query):
 r=sp.run(['docker','exec','-i','supabase-db','psql','-X','-U','postgres','-d','postgres','-Atq','-v','ON_ERROR_STOP=1'],input=query,text=True,capture_output=True)
 if r.returncode:
  (root/'activation-sql-error.log').write_text(r.stderr);raise RuntimeError('Database activation failed; private log retained.')
 return r.stdout.strip()
def request(path,expected=200):
 try:
  with urllib.request.urlopen(path,timeout=10) as response: code=response.status;body=response.read()
 except urllib.error.HTTPError as e:code=e.code;body=e.read()
 assert code==expected,(path,code,expected)
 return body
def ready(url):
 for _ in range(30):
  try:request(url);return
  except Exception:time.sleep(1)
 raise RuntimeError('Service failed health check')
def dropin(service):
 directory=Path('/etc/systemd/system')/(service+'.service.d')
 names=[p.name for p in directory.glob('*.conf')]
 count=max([len(n)-len(n.lstrip('z')) for n in names]+[0])+1
 result=directory/('z'*count+'-cad-bom-generation.conf');assert not result.exists()
 return result

def verify_front():
 active=Path(output(['systemctl','show','findez-web','-p','WorkingDirectory','--value']))
 assert str(active)==receipt['base'],'Concurrent web release; refresh/rebuild first'
 old={str(p.relative_to(active/'src')):sha(p) for p in (active/'src').rglob('*') if p.is_file()}
 assert old==receipt['before']['frontend'],'Concurrent web source edit'
 for name,hashes in manifest['frontend'].items():
  assert sha(active/name)==hashes['before'],name
  assert sha(front/name)==hashes['after'],name
 return active

stage=sys.argv[1]
if stage=='backend':
 verify_front()
 assert not (root/'backend-activated.json').exists()
 for name,h in manifest['backend'].items():
  assert sha(backend/name)==h['before'],'Concurrent backend edit: '+name
  assert sha(root/'backend'/name)==h['after'],'Candidate mismatch: '+name
 migration=root/'20261116_cad_bom_generation.sql'
 assert sha(migration)=='dc402aeb1f97a36e51befdff5189d980b620ecdbbedd12524a23655392106623'
 # Rehearsal is required and its dump is retained independently of this backup.
 assert json.loads((root/'rehearsal-results.json').read_text())['original_rows_unchanged']
 applied=root/'migration-applied.json'
 if applied.exists():
  assert json.loads(applied.read_text())['sha256']==sha(migration)
  assert sql("SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='cad_device_grants' AND column_name='allow_cad_writes'")=='1'
 else:
  with (root/'database-at-activation.dump').open('wb') as f:
   run(['docker','exec','supabase-db','pg_dump','-U','postgres','-d','postgres','-Fc'],stdout=f)
  assert sql("SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='cad_device_grants' AND column_name='allow_cad_writes'")=='0','Migration already applied; inspect before retry'
  sql(migration.read_text())
  sql("NOTIFY pgrst, 'reload schema';")
  assert sql('SELECT count(*) FROM cad_device_grants WHERE allow_cad_writes')=='0'
  assert sql("SELECT has_table_privilege('authenticated','cad_generation_jobs','SELECT') OR has_table_privilege('anon','cad_bom_versions','SELECT')")=='f'
  applied.write_text(json.dumps({'sha256':sha(migration),'existing_grants_read_only':True}))
 pid=output(['systemctl','show','findez','-p','MainPID','--value'])
 env=dict(v.split('=',1) for v in Path('/proc/'+pid+'/environ').read_bytes().decode().split('\0') if '=' in v)
 secret=env.get('CAD_SECRET_KEY') or Fernet.generate_key().decode();Fernet(secret.encode())
 provider=(root/'rexcad-private.env').read_text().strip().split('=',1)[1].strip().strip("'\"")
 assert provider.startswith('rxgen_') and all(c.isalnum() or c=='_' for c in provider)
 private=Path('/etc/findez/cad-generation.env');private.parent.mkdir(mode=0o700,exist_ok=True)
 if private.exists():
  prior=dict(line.split('=',1) for line in private.read_text().splitlines() if '=' in line)
  assert prior.get('REXCAD_GENERATION_KEY')==provider
  Fernet(prior['CAD_SECRET_KEY'].encode())
 else:
  private.write_text('CAD_BOM_ENABLED=true\nCAD_GENERATION_ENABLED=true\nCAD_SECRET_KEY='+secret+'\nREXCAD_GENERATION_KEY='+provider+'\n');private.chmod(0o600)
 conf=dropin('findez');conf.write_text('[Service]\nEnvironmentFile='+str(private)+'\n')
 backups=root/'backend-rollback'
 for name in manifest['backend']:
  target=backend/name;copy=backups/name
  if target.exists():copy.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(target,copy)
  target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/'backend'/name,target)
 try:
  run(['systemctl','daemon-reload']);run(['systemctl','restart','findez']);ready('http://127.0.0.1:8000/health')
  for path in ['/fusion/session','/fusion/bom/versions','/fusion/generation/jobs']:
   request('http://127.0.0.1:8000'+path,401)
  # Production intentionally disables public OpenAPI. Guarded endpoints above prove routing.
  request('http://127.0.0.1:8000/openapi.json',404)
 except Exception:
  for name,h in manifest['backend'].items():
   target=backend/name
   if h['before'] is None:target.unlink(missing_ok=True)
   else:shutil.copy2(backups/name,target)
  conf.unlink();run(['systemctl','daemon-reload']);run(['systemctl','restart','findez'])
  raise
 (root/'backend-activated.json').write_text(json.dumps({'migration':sha(migration),'files':len(manifest['backend']),'environment_file':str(private),'dropin':str(conf),'health':'passed','unauthenticated_guards':'passed'},indent=2))
 print('Approved migration and backend active. Existing grants remain read-only. Health and unauthorized-route checks pass.')
elif stage=='web':
 assert (root/'backend-activated.json').exists()
 active=verify_front();assert (front/'.next/BUILD_ID').is_file()
 # Preserve immutable chunks for already-open browser tabs without copying caches.
 for p in (active/'.next/static').rglob('*'):
  if p.is_file():
   target=front/'.next/static'/p.relative_to(active/'.next/static')
   if target.exists():assert sha(target)==sha(p),'Immutable asset collision'
   else:target.parent.mkdir(parents=True,exist_ok=True);os.link(p,target)
 # Public immutable asset directories must be traversable by the service user.
 for directory in (front/'.next/static').rglob('*'):
  if directory.is_dir():directory.chmod(0o755)
 run(['runuser','-u','ubuntu','--','find',str(front/'.next/static'),'-type','f','-readable'],stdout=sp.DEVNULL)
 conf=dropin('findez-web');conf.write_text('[Service]\nWorkingDirectory='+str(front)+'\n')
 try:
  run(['systemctl','daemon-reload']);run(['systemctl','restart','findez-web']);ready('http://127.0.0.1:3000/docs/cad')
  for path in ['/','/docs/api','/cad-intelligence','/cad/fusion/connect']:
   request('http://127.0.0.1:3000'+path)
  downloaded=request('http://127.0.0.1:3000/downloads/findez-fusion-workspace.zip?v=0.4.0')
  assert hashlib.sha256(downloaded).hexdigest()==manifest['frontend']['public/downloads/findez-fusion-workspace.zip']['after']
 except Exception:
  conf.unlink();run(['systemctl','daemon-reload']);run(['systemctl','restart','findez-web']);raise
 (root/'web-activated.json').write_text(json.dumps({'previous':str(active),'active':str(front),'dropin':str(conf),'build':(front/'.next/BUILD_ID').read_text().strip(),'zip_sha256':hashlib.sha256(downloaded).hexdigest(),'health':'passed'},indent=2))
 print('Web candidate active. Public routes and download hash pass; prior immutable assets retained.')
else:raise ValueError('Use backend or web')

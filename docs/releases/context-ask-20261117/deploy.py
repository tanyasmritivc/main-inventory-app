"""Guarded source patch; preserves the active release and supports rollback."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess as sp,sys,time,urllib.request
ROOT=Path('/home/ubuntu/findez-context-ask-20261117'); FRONT=ROOT/'frontend'
BASE=Path('/home/ubuntu/findez-fusion-051-20261117/frontend')
API=Path('/home/ubuntu/findez/backend')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
def run(args,**kw):return sp.run(args,check=True,**kw)
def active():return sp.check_output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'],text=True).strip()
def hashes(root):return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*') if p.is_file()}
def get(port,path):
 with urllib.request.urlopen(f'http://127.0.0.1:{port}'+path,timeout=20) as r:return r.read()
manifest=json.loads((ROOT/'manifest.json').read_text())
def check_api():
 for name,record in manifest.items():
  if name.startswith('backend/'):
   assert sha(API/name.removeprefix('backend/'))==record['before'], 'API source changed: '+name
if sys.argv[1]=='stage':
 assert active()==str(BASE) and not FRONT.exists()
 check_api()
 before=hashes(BASE)
 shutil.copytree(BASE,FRONT,ignore=shutil.ignore_patterns('.next','node_modules','public','.git','coverage','*.tsbuildinfo'),symlinks=True)
 os.symlink((BASE/'node_modules').resolve(),FRONT/'node_modules')
 shutil.copytree(BASE/'public',FRONT/'public',copy_function=os.link)
 shutil.copytree(API/'app',ROOT/'backend/app',ignore=shutil.ignore_patterns('__pycache__'))
 for name,record in manifest.items():
  target=ROOT/name
  assert sha(target)==record['before'], 'Candidate baseline mismatch: '+name
  target.parent.mkdir(parents=True,exist_ok=True)
  shutil.copy2(ROOT/'patch'/name,target)
  assert sha(target)==record['after']
 after=hashes(FRONT)
 assert {k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)}=={p.removeprefix('frontend/') for p in manifest if p.startswith('frontend/')}
 assert hashes(BASE)==before
 (ROOT/'receipt.json').write_text(json.dumps({'before':before,'after':after},indent=2))
 # Disposable webpack build cache from our completed 0.5.0 build. No runtime,
 # source, uploaded files, database data or release artifacts are removed.
 old_cache=Path('/dev/shm/findez-cad-native-planning-cache')
 if old_cache.is_dir():shutil.rmtree(old_cache)
 cache=Path('/dev/shm/findez-context-ask-cache');cache.mkdir(exist_ok=False)
 (FRONT/'.next').mkdir();os.symlink(cache,FRONT/'.next/cache')
 run(['npm','run','build','--','--webpack'],cwd=FRONT)
 print('Candidate built:',(FRONT/'.next/BUILD_ID').read_text().strip())
elif sys.argv[1]=='refresh':
 assert active()==str(BASE)
 receipt=json.loads((ROOT/'receipt.json').read_text())
 assert hashes(BASE)==receipt['before'] and hashes(FRONT)==receipt['after']
 check_api()
 for name,record in manifest.items():
  target=ROOT/name;target.parent.mkdir(parents=True,exist_ok=True)
  shutil.copy2(ROOT/'patch'/name,target)
  assert sha(target)==record['after']
 receipt['after']=hashes(FRONT)
 assert {k for k in receipt['before'].keys()|receipt['after'].keys() if receipt['before'].get(k)!=receipt['after'].get(k)}=={p.removeprefix('frontend/') for p in manifest if p.startswith('frontend/')}
 (ROOT/'receipt.json').write_text(json.dumps(receipt,indent=2))
 run(['npm','run','build','--','--webpack'],cwd=FRONT)
 print('Candidate refreshed:',(FRONT/'.next/BUILD_ID').read_text().strip())
elif sys.argv[1]=='activate':
 assert active()==str(BASE)
 receipt=json.loads((ROOT/'receipt.json').read_text())
 assert hashes(BASE)==receipt['before'] and hashes(FRONT)==receipt['after']
 check_api()
 for name,record in manifest.items():assert sha(ROOT/name)==record['after']
 assert (FRONT/'.next/BUILD_ID').is_file()
 for p in (BASE/'.next/static').rglob('*'):
  if p.is_file():
   t=FRONT/'.next/static'/p.relative_to(BASE/'.next/static')
   if t.exists():assert sha(t)==sha(p)
   else:t.parent.mkdir(parents=True,exist_ok=True);os.link(p,t)
 for p in (FRONT/'.next/static').rglob('*'):
  if p.is_dir():p.chmod(0o755)
 directory=Path('/etc/systemd/system/findez-web.service.d')
 n=max([len(p.name)-len(p.name.lstrip('z')) for p in directory.glob('*.conf')]+[0])+1
 override=directory/('z'*n+'-context-ask.conf');assert not override.exists()
 changed=[]
 try:
  for name,record in manifest.items():
   if not name.startswith('backend/'):continue
   target=API/name.removeprefix('backend/');backup=ROOT/'rollback'/name
   if target.exists():backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(target,backup)
   changed.append((target,backup))
   shutil.copy2(ROOT/name,target)
  run(['systemctl','restart','findez'])
  for attempt in range(40):
   try:get(8000,'/health');get(8000,'/health/db');break
   except Exception:
    if attempt==39:raise
    time.sleep(1)
  override.write_text('[Service]\nWorkingDirectory='+str(FRONT)+'\n')
  run(['systemctl','daemon-reload']);run(['systemctl','restart','findez-web'])
  for attempt in range(30):
   try:get(3000,'/');break
   except Exception:
    if attempt==29:raise
    time.sleep(1)
  for path in ['/spaces','/assist','/docs/cad','/cad-intelligence']:get(3000,path)
 except Exception:
  for target,backup in reversed(changed):
   if backup.exists():shutil.copy2(backup,target)
   else:target.unlink(missing_ok=True)
  override.unlink(missing_ok=True);run(['systemctl','daemon-reload']);run(['systemctl','restart','findez','findez-web']);raise
 (ROOT/'activation.json').write_text(json.dumps({'base':str(BASE),'active':str(FRONT),'build':(FRONT/'.next/BUILD_ID').read_text().strip(),'override':str(override),'checks':'health, database health and web routes passed','schema_changes':False},indent=2))
 print('Published organization Ask scope and stream recovery. No schema changes.')
else:raise ValueError('Use stage, refresh or activate')

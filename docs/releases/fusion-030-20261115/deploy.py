import hashlib, json, os, shutil, subprocess, sys, tarfile, time
from pathlib import Path
base=Path('/home/ubuntu/findez-world-web-20261116/frontend')
release=Path('/home/ubuntu/findez-fusion-ai-current-20261115')
front=release/'frontend'
backend=Path('/home/ubuntu/findez/backend')
manifest=json.loads(Path('/home/ubuntu/findez-fusion-ai-manifest.json').read_text())
old_backend={'app/api/routes/cad_workspace.py':'9993b42c880051b4a8f2bdec3818cb67672bcd9b25f894a7ae01f23ea9fa3edb','app/services/cad/workspace.py':'1ac839e1d3a6818760d55666d0f67e6b9c68adbdaa950adede6a109ce5dbd6ed'}
old_zip='4956ac0824fd4451f697773a34f701f852d6dc92cd8fd4d6954f4491baf7797e'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def active(): return subprocess.check_output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'],text=True).strip()
def hashes(root): return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*') if p.is_file()}
def guard_backend():
 for p,h in old_backend.items(): assert sha(backend/p)==h, 'Backend changed: '+p
 assert not (backend/'app/services/cad/search.py').exists(), 'Search module already exists'
def write_atomic(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True)
 temp=dst.with_name(dst.name+'.fusion-ai-tmp'); shutil.copy2(src,temp); os.replace(temp,dst)
def health_backend():
 for _ in range(30):
  r=subprocess.run(['curl','-fsS','http://127.0.0.1:8000/health'],capture_output=True)
  if r.returncode==0: return
  time.sleep(1)
 raise RuntimeError('Backend health check failed')
mode=sys.argv[1]
if mode=='prepare':
 assert active()==str(base), 'Active web release changed'
 for p,h in manifest['backend_new'].items(): assert sha(backend/p)==h, 'Backend changed: '+p
 assert not front.exists(), 'Candidate already exists'
 assert sha(base/'public/downloads/findez-fusion-workspace.zip')==old_zip
 before=hashes(base)
 shutil.copytree(base,front,ignore=shutil.ignore_patterns('.next','node_modules','public','.git','coverage','*.tsbuildinfo'))
 os.symlink(str((base/'node_modules').resolve()),front/'node_modules')
 shutil.copytree(base/'public',front/'public',copy_function=os.link)
 cache=base/'.next/cache/webpack'
 if cache.exists():
  (front/'.next/cache').mkdir(parents=True,exist_ok=True); shutil.move(str(cache),str(front/'.next/cache/webpack'))
 patch=Path('/home/ubuntu/findez-fusion-ai-web.patch')
 subprocess.run(['patch','--dry-run','-p1','-i',str(patch)],cwd=release,check=True)
 subprocess.run(['patch','--no-backup-if-mismatch','-p1','-i',str(patch)],cwd=release,check=True)
 after=hashes(front)
 changed=sorted(k for k in before if before[k]!=after[k])
 assert changed==sorted(manifest['files']), changed
 zip_source=Path('/home/ubuntu/findez-fusion-ai-workspace.zip')
 assert sha(zip_source)==manifest['zip_sha256']
 write_atomic(zip_source,front/'public/downloads/findez-fusion-workspace.zip')
 shutil.copytree(backend/'app',release/'backend/app',ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
 with tarfile.open('/home/ubuntu/findez-fusion-ai-backend.tar.gz') as t:
  for member in t.getmembers():
   assert member.name in manifest['backend_new'] and member.isfile()
  t.extractall(release/'backend',filter='data')
 for p,h in manifest['backend_new'].items(): assert sha(release/'backend'/p)==h
 (release/'receipt.json').write_text(json.dumps({'base':str(base),'before':before,'changed':changed,'backend_before':old_backend,**manifest},indent=2))
 print('Prepared scoped production-source release and rollback guards.')
elif mode=='backend':
 guard_backend()
 assert (release/'frontend/.next/BUILD_ID').is_file(), 'Build must pass first'
 for p,h in manifest['backend_new'].items(): assert sha(release/'backend'/p)==h
 for p in old_backend:
  target=release/'backend-rollback'/p; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(backend/p,target)
 try:
  for p in manifest['backend_new']: write_atomic(release/'backend'/p,backend/p)
  subprocess.run(['sudo','systemctl','restart','findez'],check=True); health_backend()
 except BaseException:
  for p in old_backend: write_atomic(release/'backend-rollback'/p,backend/p)
  (backend/'app/services/cad/search.py').unlink(missing_ok=True)
  subprocess.run(['sudo','systemctl','restart','findez'],check=True); raise
 print('Backend active; health passed; no schema change.')
elif mode=='activate':
 assert active()==str(base), 'Active web release changed'
 receipt=json.loads((release/'receipt.json').read_text())
 assert hashes(base)==receipt['before'], 'Production source changed'
 assert sha(base/'public/downloads/findez-fusion-workspace.zip')==old_zip
 assert sha(front/'public/downloads/findez-fusion-workspace.zip')==manifest['zip_sha256']
 for p,h in manifest['backend_new'].items(): assert sha(backend/p)==h
 assert (front/'.next/BUILD_ID').is_file(), 'Missing build'
 oldstatic=base/'.next/static'
 for p in oldstatic.rglob('*'):
  if p.is_file():
   dest=front/'.next/static'/p.relative_to(oldstatic)
   if not dest.exists(): dest.parent.mkdir(parents=True,exist_ok=True); os.link(p,dest)
 override=sorted(Path('/etc/systemd/system/findez-web.service.d').glob('*.conf'))[-1]
 previous=override.read_text()
 assert previous.count('WorkingDirectory='+str(base))==1, 'Effective override changed'
 (release/'previous-service.conf').write_text(override.read_text())
 replacement=release/'service.conf'; replacement.write_text(previous.replace('WorkingDirectory='+str(base), 'WorkingDirectory='+str(front)))
 def install(p):
  subprocess.run(['sudo','install','-m','644',str(p),str(override)],check=True)
  subprocess.run(['sudo','systemctl','daemon-reload'],check=True)
  subprocess.run(['sudo','systemctl','restart','findez-web'],check=True)
 try:
  install(replacement)
  for _ in range(30):
   r=subprocess.run(['curl','-fsS','http://127.0.0.1:3000/docs/cad'],capture_output=True)
   if r.returncode==0 and b'Version 0.3.0' in r.stdout: break
   time.sleep(1)
  else: raise RuntimeError('CAD docs health check failed')
  r=subprocess.run(['curl','-fsS','http://127.0.0.1:3000/docs/api'],capture_output=True)
  assert r.returncode==0 and b'Build with your inventory.' in r.stdout
 except BaseException:
  install(release/'previous-service.conf'); raise
 (release/'activation.json').write_text(json.dumps({'active':str(front),'previous':str(base),'build_id':(front/'.next/BUILD_ID').read_text().strip(),'zip_sha256':manifest['zip_sha256']},indent=2))
 print((release/'activation.json').read_text())

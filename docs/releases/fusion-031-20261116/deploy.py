import hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
base=Path('/home/ubuntu/findez-world-json-20261116/frontend')
release=Path('/home/ubuntu/findez-fusion-031-20261116');front=release/'frontend'
backend=Path('/home/ubuntu/findez/backend/app/services/cad/search.py')
manifest=json.loads(Path('/home/ubuntu/findez-fusion-031-manifest.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def active():return subprocess.check_output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'],text=True).strip()
def hashes(root):return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*') if p.is_file()}
def atomic(src,dst):
 temp=dst.with_name(dst.name+'.fusion-tmp');shutil.copy2(src,temp);os.replace(temp,dst)
mode=sys.argv[1]
if mode=='prepare':
 assert active()==str(base),'Active release changed'
 assert sha(backend)==manifest['backend_old'],'Backend changed'
 assert sha(base/'public/downloads/findez-fusion-workspace.zip')==manifest['zip_old']
 assert not front.exists(),'Candidate exists'
 # This is only the disposable build output of our first, never-activated 0.3.0 candidate.
 unused=Path('/home/ubuntu/findez-fusion-ai-20261115/frontend/.next')
 assert not active().startswith(str(unused.parent))
 if unused.exists():shutil.rmtree(unused)
 before=hashes(base)
 shutil.copytree(base,front,ignore=shutil.ignore_patterns('.next','node_modules','public','.git','coverage','*.tsbuildinfo'))
 os.symlink(str((base/'node_modules').resolve()),front/'node_modules')
 shutil.copytree(base/'public',front/'public',copy_function=os.link)
 cache=base/'.next/cache/webpack'
 if cache.exists():
  (front/'.next/cache').mkdir(parents=True,exist_ok=True);shutil.move(str(cache),str(front/'.next/cache/webpack'))
 patch='/home/ubuntu/findez-fusion-031-web.patch'
 subprocess.run(['patch','--dry-run','-p1','-i',patch],cwd=release,check=True)
 subprocess.run(['patch','--no-backup-if-mismatch','-p1','-i',patch],cwd=release,check=True)
 after=hashes(front);changed=sorted(k for k in before if before[k]!=after[k])
 assert changed==sorted(manifest['files']),changed
 zipfile=Path('/home/ubuntu/findez-fusion-031-workspace.zip');assert sha(zipfile)==manifest['zip_new']
 atomic(zipfile,front/'public/downloads/findez-fusion-workspace.zip')
 shutil.copy2(backend,release/'previous-search.py')
 (release/'receipt.json').write_text(json.dumps({'base':str(base),'before':before,**manifest},indent=2))
 print('Scoped production-source candidate prepared.')
elif mode=='activate':
 assert active()==str(base),'Active release changed'
 receipt=json.loads((release/'receipt.json').read_text())
 assert hashes(base)==receipt['before'],'Production source changed'
 assert sha(backend)==manifest['backend_old'],'Backend changed'
 assert sha(front/'public/downloads/findez-fusion-workspace.zip')==manifest['zip_new']
 candidate=Path('/home/ubuntu/findez-fusion-031-search.py');assert sha(candidate)==manifest['backend_new']
 assert (front/'.next/BUILD_ID').is_file(),'Missing build'
 for p in (base/'.next/static').rglob('*'):
  if p.is_file():
   dest=front/'.next/static'/p.relative_to(base/'.next/static')
   if not dest.exists():dest.parent.mkdir(parents=True,exist_ok=True);os.link(p,dest)
 override=sorted(Path('/etc/systemd/system/findez-web.service.d').glob('*.conf'))[-1]
 previous=override.read_text();assert previous.count('WorkingDirectory='+str(base))==1,'Effective override changed'
 (release/'previous-service.conf').write_text(previous)
 (release/'service.conf').write_text(previous.replace('WorkingDirectory='+str(base),'WorkingDirectory='+str(front)))
 def install(p):
  subprocess.run(['sudo','install','-m','644',str(p),str(override)],check=True)
  subprocess.run(['sudo','systemctl','daemon-reload'],check=True)
  subprocess.run(['sudo','systemctl','restart','findez-web'],check=True)
 try:
  atomic(candidate,backend);subprocess.run(['sudo','systemctl','restart','findez'],check=True)
  for _ in range(30):
   if subprocess.run(['curl','-fsS','http://127.0.0.1:8000/health'],capture_output=True).returncode==0:break
   time.sleep(1)
  else:raise RuntimeError('Backend health failed')
  install(release/'service.conf')
  for _ in range(30):
   r=subprocess.run(['curl','-fsS','http://127.0.0.1:3000/docs/cad'],capture_output=True)
   if r.returncode==0 and b'Version 0.3.1' in r.stdout:break
   time.sleep(1)
  else:raise RuntimeError('CAD docs health failed')
  assert subprocess.run(['curl','-fsS','http://127.0.0.1:3000/docs/api'],capture_output=True).returncode==0
 except BaseException:
  atomic(release/'previous-search.py',backend);subprocess.run(['sudo','systemctl','restart','findez'],check=True)
  install(release/'previous-service.conf');raise
 result={'active':str(front),'previous':str(base),'build_id':(front/'.next/BUILD_ID').read_text().strip(),'zip_sha256':manifest['zip_new'],'override':str(override)}
 (release/'activation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))

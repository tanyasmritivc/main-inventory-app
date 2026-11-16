import hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
base=Path('/home/ubuntu/findez-world-buttons-20261116/frontend')
release=Path('/home/ubuntu/findez-cad-labels-20261116');front=release/'frontend'
changes={'src/components/marketing-dark/cad-public-content.tsx':('findez-fusion-preview','findez-fusion-workspace'),'src/components/marketing-dark/cad-public-runtime.js':('findez-fusion-preview','findez-fusion-workspace'),'src/components/site/cad-docs-navigation.tsx':('zip template 0.2.1 0.1.0 candidate','zip template 0.3.1 0.1.0 candidate')}
def active():return subprocess.check_output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'],text=True).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def hashes(root):return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*') if p.is_file()}
if sys.argv[1]=='prepare':
 assert active()==str(base),'Active release changed'
 assert not front.exists()
 before=hashes(base)
 cache=Path('/home/ubuntu/findez-fusion-031-20261116/frontend/.next/cache')
 assert active()!=str(cache.parent.parent)
 if cache.exists():shutil.rmtree(cache)
 shutil.copytree(base,front,ignore=shutil.ignore_patterns('.next','node_modules','public','.git','coverage','*.tsbuildinfo'))
 os.symlink(str((base/'node_modules').resolve()),front/'node_modules')
 shutil.copytree(base/'public',front/'public',copy_function=os.link)
 for name,(old,new) in changes.items():
  p=front/name;s=p.read_text();assert s.count(old)==1,name;p.write_text(s.replace(old,new))
 after=hashes(front);assert sorted(k for k in before if before[k]!=after[k])==sorted(changes)
 (release/'receipt.json').write_text(json.dumps({'before':before,'base':str(base),'zip_sha256':sha(base/'public/downloads/findez-fusion-workspace.zip')},indent=2))
 print('Prepared three text substitutions; ZIP unchanged.')
else:
 assert sys.argv[1]=='activate'
 assert active()==str(base),'Active release changed'
 receipt=json.loads((release/'receipt.json').read_text());assert hashes(base)==receipt['before'],'Source changed'
 assert (front/'.next/BUILD_ID').is_file()
 assert sha(front/'public/downloads/findez-fusion-workspace.zip')==receipt['zip_sha256']
 for p in (base/'.next/static').rglob('*'):
  if p.is_file():
   dest=front/'.next/static'/p.relative_to(base/'.next/static')
   if not dest.exists():dest.parent.mkdir(parents=True,exist_ok=True);os.link(p,dest)
 override=sorted(Path('/etc/systemd/system/findez-web.service.d').glob('*.conf'))[-1]
 previous=override.read_text();assert previous.count('WorkingDirectory='+str(base))==1
 (release/'previous-service.conf').write_text(previous)
 (release/'service.conf').write_text(previous.replace('WorkingDirectory='+str(base),'WorkingDirectory='+str(front)))
 def install(path):
  subprocess.run(['sudo','install','-m','644',str(path),str(override)],check=True)
  subprocess.run(['sudo','systemctl','daemon-reload'],check=True)
  subprocess.run(['sudo','systemctl','restart','findez-web'],check=True)
 try:
  install(release/'service.conf')
  for _ in range(30):
   r=subprocess.run(['curl','-fsS','http://127.0.0.1:3000/cad-intelligence'],capture_output=True)
   if r.returncode==0 and b'findez-fusion-preview' not in r.stdout and b'findez-fusion-workspace' in r.stdout:break
   time.sleep(1)
  else:raise RuntimeError('Public CAD health check failed')
  for route in ('/docs/cad','/docs/api'):
   assert subprocess.run(['curl','-fsS','http://127.0.0.1:3000'+route],capture_output=True).returncode==0
 except BaseException:
  install(release/'previous-service.conf');raise
 result={'active':str(front),'previous':str(base),'build_id':(front/'.next/BUILD_ID').read_text().strip(),'zip_sha256':receipt['zip_sha256'],'changed':list(changes)}
 (release/'activation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))

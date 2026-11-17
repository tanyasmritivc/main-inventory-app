"""Web/docs/ZIP-only hotfix, preserving current production source and backend."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess as sp,sys,time,urllib.request
ROOT=Path('/home/ubuntu/findez-fusion-051-20261117');FRONT=ROOT/'frontend'
BASE=Path('/home/ubuntu/findez-profile-card-20261117/frontend')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def hashes(root):return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*') if p.is_file()}
def active():return sp.check_output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'],text=True).strip()
def run(args,**kw):return sp.run(args,check=True,**kw)
def get(path):
 with urllib.request.urlopen('http://127.0.0.1:3000'+path,timeout=20) as response:return response.read()
files=json.loads((ROOT/'files.json').read_text())
if sys.argv[1]=='stage':
 assert active()==str(BASE),'Production release changed; rebase candidate'
 assert not FRONT.exists()
 before=hashes(BASE)
 shutil.copytree(BASE,FRONT,ignore=shutil.ignore_patterns('.next','node_modules','public','.git','coverage','*.tsbuildinfo'),symlinks=True)
 os.symlink((BASE/'node_modules').resolve(),FRONT/'node_modules')
 shutil.copytree(BASE/'public',FRONT/'public',copy_function=os.link)
 zip_path=FRONT/'public/downloads/findez-fusion-workspace.zip'
 zip_path.unlink();shutil.copy2(BASE/'public/downloads/findez-fusion-workspace.zip',zip_path)
 run(['git','apply','--check',str(ROOT/'changes.patch')],cwd=ROOT)
 run(['git','apply',str(ROOT/'changes.patch')],cwd=ROOT)
 after=hashes(FRONT)
 assert {k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)}=={p.removeprefix('frontend/') for p in files if p.startswith('frontend/src/')}
 assert hashes(BASE)==before
 manifest={p:sha(ROOT/p) for p in files}
 (ROOT/'receipt.json').write_text(json.dumps({'base':str(BASE),'before':before,'after':after,'manifest':manifest},indent=2))
 cache=Path('/dev/shm/findez-fusion-051-cache');cache.mkdir(exist_ok=False)
 (FRONT/'.next').mkdir();os.symlink(cache,FRONT/'.next/cache')
 run(['npm','run','build','--','--webpack'],cwd=FRONT)
 print('Built', (FRONT/'.next/BUILD_ID').read_text().strip())
elif sys.argv[1]=='activate':
 receipt=json.loads((ROOT/'receipt.json').read_text())
 assert active()==str(BASE) and hashes(BASE)==receipt['before']
 assert hashes(FRONT)==receipt['after']
 for name,digest in receipt['manifest'].items():assert sha(ROOT/name)==digest
 assert (FRONT/'.next/BUILD_ID').is_file()
 for p in (BASE/'.next/static').rglob('*'):
  if p.is_file():
   target=FRONT/'.next/static'/p.relative_to(BASE/'.next/static')
   if target.exists():assert sha(target)==sha(p)
   else:target.parent.mkdir(parents=True,exist_ok=True);os.link(p,target)
 for p in (FRONT/'.next/static').rglob('*'):
  if p.is_dir():p.chmod(0o755)
 directory=Path('/etc/systemd/system/findez-web.service.d')
 count=max([len(p.name)-len(p.name.lstrip('z')) for p in directory.glob('*.conf')]+[0])+1
 override=directory/('z'*count+'-fusion-051.conf');assert not override.exists()
 try:
  override.write_text('[Service]\nWorkingDirectory='+str(FRONT)+'\n')
  run(['systemctl','daemon-reload']);run(['systemctl','restart','findez-web'])
  for n in range(30):
   try:html=get('/docs/cad').decode();break
   except Exception:
    if n==29:raise
    time.sleep(1)
  assert '0.5.1' in html and 'Creating a purchase plan fails' in html
  assert hashlib.sha256(get('/downloads/findez-fusion-workspace.zip?v=0.5.1')).hexdigest()==receipt['manifest']['frontend/public/downloads/findez-fusion-workspace.zip']
  for path in ['/','/cad','/cad-intelligence','/docs/api','/cad/fusion/connect']:get(path)
 except Exception:
  override.unlink(missing_ok=True);run(['systemctl','daemon-reload']);run(['systemctl','restart','findez-web']);raise
 (ROOT/'activation.json').write_text(json.dumps({'base':str(BASE),'active':str(FRONT),'build':(FRONT/'.next/BUILD_ID').read_text().strip(),'dropin':str(override),'checks':'passed'},indent=2))
 print('Published 0.5.1 docs and matching ZIP; API and database unchanged.')
else:raise ValueError('Use stage or activate')

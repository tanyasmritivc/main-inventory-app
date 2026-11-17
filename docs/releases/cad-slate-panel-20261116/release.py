"""Guarded, web-only CAD documentation release. Run stage/build, then activate."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess as sp,sys,tarfile,time,urllib.request
root=Path('/home/ubuntu/findez-cad-slate-20261116');front=root/'frontend'
def output(a):return sp.check_output(a,text=True).strip()
def run(a,**kw):return sp.run(a,check=True,**kw)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot(p):return {str(f.relative_to(p)):sha(f) for f in (p/'src').rglob('*') if f.is_file()}
def get(url):
 with urllib.request.urlopen(url,timeout=15) as r:return r.read()
manifest=json.loads((root/'manifest.json').read_text())
if sys.argv[1]=='stage':
 active=Path(output(['systemctl','show','findez-web','-p','WorkingDirectory','--value']))
 assert str(active)=='/home/ubuntu/findez-cad-docs-hub-final-20261116/frontend','Production changed; rebase first'
 assert not front.exists()
 for name,h in manifest.items():assert sha(active/name)==h['before'],name
 shutil.copytree(active,front,ignore=shutil.ignore_patterns('node_modules','.next','public','.git'),symlinks=True)
 os.symlink((active/'node_modules').resolve(),front/'node_modules')
 shutil.copytree(active/'public',front/'public',copy_function=os.link)
 for name in manifest:
  if name.startswith('public/'):(front/name).unlink() # break candidate hardlink before replacing ZIP
 with tarfile.open(root/'overlay.tgz') as t:t.extractall(front,filter='data')
 for name,h in manifest.items():assert sha(active/name)==h['before'], 'Live source mutated: '+name
 for name,h in manifest.items():assert sha(front/name)==h['after'],name
 before=snapshot(active);after=snapshot(front)
 assert {n for n in before.keys()|after.keys() if before.get(n)!=after.get(n)}=={n for n in manifest if n.startswith("src/")}
 (root/'receipt.json').write_text(json.dumps({'base':str(active),'before':before,'after':after},indent=2))
 cache=Path('/dev/shm/findez-cad-slate-cache');cache.mkdir(exist_ok=False)
 (front/'.next').mkdir(exist_ok=True);os.symlink(cache,front/'.next/cache')
 print('Staged 0.4.1 package and consistent download links; behavior unchanged',flush=True)
 run(['npm','run','build','--','--webpack'],cwd=front)
 print('Build:',(front/'.next/BUILD_ID').read_text().strip())
elif sys.argv[1]=='activate':
 receipt=json.loads((root/'receipt.json').read_text());active=Path(receipt['base'])
 assert output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'])==str(active)
 assert snapshot(active)==receipt['before'];assert snapshot(front)==receipt['after']
 for name,h in manifest.items():
  assert sha(active/name)==h['before'],name
  assert sha(front/name)==h['after'],name
 assert (front/'.next/BUILD_ID').is_file()
 for p in (active/'.next/static').rglob('*'):
  if p.is_file():
   q=front/'.next/static'/p.relative_to(active/'.next/static')
   if q.exists():assert sha(q)==sha(p)
   else:q.parent.mkdir(parents=True,exist_ok=True);os.link(p,q)
 for p in (front/'.next/static').rglob('*'):
  if p.is_dir():p.chmod(0o755)
 directory=Path('/etc/systemd/system/findez-web.service.d')
 count=max([len(p.name)-len(p.name.lstrip('z')) for p in directory.glob('*.conf')]+[0])+1
 conf=directory/('z'*count+'-cad-slate.conf');assert not conf.exists()
 conf.write_text('[Service]\nWorkingDirectory='+str(front)+'\n')
 try:
  run(['systemctl','daemon-reload']);run(['systemctl','restart','findez-web'])
  for i in range(30):
   try:html=get('http://127.0.0.1:3000/docs/cad').decode();break
   except Exception:
    if i==29:raise
    time.sleep(1)
  for label in ['CAD tools and guides','Create your first design','Generation status and next step','Work in Fusion']:assert label in html,label
  for path in ['/','/cad-intelligence','/docs/api','/docs/connections','/cad','/cad/fusion/connect']:get('http://127.0.0.1:3000'+path)
  digest=hashlib.sha256(get('http://127.0.0.1:3000/downloads/findez-fusion-workspace.zip?v=0.4.1')).hexdigest()
  assert digest=='892adf048de38420f991a0355958d70c905be0ab3bb8f7df0b5a7b8711563284'
 except Exception:
  conf.unlink();run(['systemctl','daemon-reload']);run(['systemctl','restart','findez-web']);raise
 (root/'activation.json').write_text(json.dumps({'base':str(active),'active':str(front),'build':(front/'.next/BUILD_ID').read_text().strip(),'dropin':str(conf),'download_sha256':digest,'routes':'passed'},indent=2))
 print('Activated; route checks and 0.4.1 ZIP verified')
else:raise ValueError('Use stage or activate')

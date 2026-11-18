from pathlib import Path
import json,hashlib,subprocess as sp,shutil,os,time,urllib.request
root=Path('/home/ubuntu/findez-chat-recovery-20261118')
api=Path('/home/ubuntu/findez/backend')
manifest=json.loads((root/'manifest.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def hashes():return {str(p.relative_to(api)):sha(p) for p in (api/'app').rglob('*.py')}
before=hashes()
for name,rec in manifest.items():
 assert sha(api/name)==rec['before'], 'Live source drift: '+name
 assert sha(root/'patch'/name)==rec['after'], 'Candidate source drift: '+name
 assert not (root/'rollback'/name).exists(), 'Release already attempted'
for name in manifest:
 backup=root/'rollback'/name;backup.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2(api/name,backup)
def healthy():
 for path in ['/health','/health/db']:
  with urllib.request.urlopen('http://127.0.0.1:8000'+path,timeout=10) as r:assert r.status==200
try:
 for name in manifest:
  tmp=(api/name).with_suffix('.py.candidate');shutil.copy2(root/'patch'/name,tmp);os.replace(tmp,api/name)
 after=hashes()
 assert {k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)}==set(manifest)
 sp.run(['systemctl','restart','findez'],check=True)
 for i in range(40):
  try:healthy();break
  except Exception:
   if i==39:raise
   time.sleep(1)
except Exception:
 for name in manifest:shutil.copy2(root/'rollback'/name,api/name)
 sp.run(['systemctl','restart','findez'],check=True)
 raise
receipt={'api':'/home/ubuntu/findez/backend','changed_files':manifest,'preserved_python_files':len(before)-len(manifest),'health':'passed','database_health':'passed','web_changed':False,'schema_changed':False,'published_at_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
(root/'activation.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))

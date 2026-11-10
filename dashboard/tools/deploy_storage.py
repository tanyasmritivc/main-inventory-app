"""Activate the reviewed storage dashboard release. Run from its staging directory."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
import urllib.request

stage=Path(__file__).resolve().parent
old=Path('/home/ubuntu/findez-dashboard/releases/20261018-v1')
release=Path('/home/ubuntu/findez-dashboard/releases/20261109-storage')
expected={
 'collectors.py':'c3c7ebd122c954742fa45f1adecb77000a94b9eac0bad352fde3c77a54274811',
 'main.py':'082fcf3db8fae4b968619ec7cdcbe1d207d74c279b8a7eaece22117c7a193aca',
 'store.py':'f03ce3a281f267425452044150af773e4fcb4b0f928f4ef17a80818b9f4e0b48',
}
for name,digest in expected.items():
 assert hashlib.sha256((old/name).read_bytes()).hexdigest()==digest, 'Live dashboard source changed'
current=subprocess.check_output(['systemctl','show','findez-dashboard','-p','WorkingDirectory','--value'],text=True).strip()
assert current==str(old), 'Unexpected active dashboard release'
assert not release.exists(), 'Release already exists'
release.mkdir()
for name in ['collectors.py','main.py','store.py','storage_monitor.py','storage_cleanup.py']:
 source=stage/'service'/name
 compile(source.read_text(),str(source),'exec')
 shutil.copy2(source,release/name)
subprocess.run(['systemd-analyze','verify',str(stage/'systemd/findez-storage-cleanup.service'),str(stage/'systemd/findez-storage-cleanup.timer')],check=True)
# Dry run must succeed before any automatic cleanup is enabled.
subprocess.run(['/usr/bin/python3',str(release/'storage_cleanup.py')],check=True)
for name in ['findez-storage-cleanup.service','findez-storage-cleanup.timer']:
 subprocess.run(['sudo','install','-m','644',str(stage/'systemd'/name),'/etc/systemd/system/'+name],check=True)
override=stage/'storage-release.conf'
override.write_text('[Service]\nWorkingDirectory='+str(release)+'\n')
subprocess.run(['sudo','mkdir','-p','/etc/systemd/system/findez-dashboard.service.d'],check=True)
subprocess.run(['sudo','install','-m','644',str(override),'/etc/systemd/system/findez-dashboard.service.d/storage-release.conf'],check=True)
subprocess.run(['sudo','systemctl','daemon-reload'],check=True)
subprocess.run(['sudo','systemctl','start','findez-storage-cleanup.service'],check=True)
subprocess.run(['sudo','systemctl','enable','--now','findez-storage-cleanup.timer'],check=True)
subprocess.run(['sudo','systemctl','restart','findez-dashboard.service'],check=True)
for attempt in range(30):
 try:
  with urllib.request.urlopen('http://127.0.0.1:8031/dashboard/v1/health',timeout=2) as response:
   assert json.load(response)['status']=='ok'
  break
 except Exception:
  if attempt==29: raise
  time.sleep(.5)
receipt=json.loads(Path('/home/ubuntu/findez-dashboard-data/storage-cleanup.json').read_text())
assert receipt['status']=='ok' and not receipt['dry_run']
assert subprocess.check_output(['systemctl','is-active','findez-storage-cleanup.timer'],text=True).strip()=='active'
result=dict(release=str(release),cleanup=receipt,dashboard_healthy=True,customer_services_not_restarted=True)
(stage/'deployment.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))

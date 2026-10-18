"""Run on the existing FindEZ VM after uploading the reviewed dashboard service."""
import hashlib
import json
from pathlib import Path
import subprocess
import time
import urllib.request

root = Path('/home/ubuntu/findez-dashboard')
release = root / 'releases/20261018-v1'
data = Path('/home/ubuntu/findez-dashboard-data')
data.mkdir(mode=0o700, exist_ok=True)
unit = Path('/etc/systemd/system/findez-dashboard.service')
assert release.is_dir()
if unit.exists():
    assert (root/'findez-dashboard.service').exists()
    assert unit.read_text() == (root/'findez-dashboard.service').read_text(), 'Unexpected existing dashboard service'
backend_hashes = {}
for path in (Path('/home/ubuntu/findez/.env'), Path('/home/ubuntu/findez/backend/app/main.py'), Path('/home/ubuntu/findez/backend/app/api/router.py')):
    backend_hashes[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
owner_id = subprocess.check_output(['docker','exec','supabase-db','psql','-U','postgres','-d','postgres','-At','-c',
    "SELECT id FROM auth.users WHERE lower(email)='tanyasmritivictorcharles@gmail.com' AND email_confirmed_at IS NOT NULL"], text=True).strip()
import uuid
uuid.UUID(owner_id)
(data/'owner.json').write_text(json.dumps({'user_id':owner_id}))
(data/'owner.json').chmod(0o600)
definition = f'''[Unit]
Description=FindEZ private founder dashboard
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory={release}
EnvironmentFile=/home/ubuntu/findez/.env
Environment=DASHBOARD_OWNER_FILE={data}/owner.json
Environment=DASHBOARD_DB={data}/dashboard.sqlite
ExecStart=/home/ubuntu/findez/.venv/bin/uvicorn main:production --factory --host 127.0.0.1 --port 8031 --no-access-log
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths={data}
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

[Install]
WantedBy=multi-user.target
'''
prepared = root/'findez-dashboard.service'
prepared.write_text(definition)
subprocess.run(['sudo','install','-m','644',str(prepared),str(unit)],check=True)
subprocess.run(['sudo','systemctl','daemon-reload'],check=True)
subprocess.run(['sudo','systemctl','enable','--now','findez-dashboard'],check=True)
for attempt in range(20):
    try:
        with urllib.request.urlopen('http://127.0.0.1:8031/dashboard/v1/health',timeout=2) as r:
            assert json.load(r)['status']=='ok'
        break
    except Exception:
        if attempt==19: raise
        time.sleep(.3)
request=urllib.request.Request('http://127.0.0.1:8031/dashboard/v1/snapshot')
try:
    urllib.request.urlopen(request,timeout=3)
    raise AssertionError('Unauthenticated snapshot was exposed')
except urllib.error.HTTPError as error:
    assert error.code==401
for path,digest in backend_hashes.items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest
receipt={'service':'findez-dashboard','release':str(release),'data':str(data),'api':'https://findez.ai/api/founder/v1',
         'founder_only':True,'unauthenticated_snapshot_status':401,'customer_backend_source_and_environment_unchanged':True,
         'customer_services_not_restarted':True,'database_schema_unchanged':True,'proxy_configuration_unchanged':True}
(root/'deployment.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))

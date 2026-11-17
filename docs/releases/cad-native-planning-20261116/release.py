"""Guarded self-hosted candidate. Stage/build first; activate only after approval."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess as sp
import sys
import tarfile
import time
import urllib.request

ROOT=Path('/home/ubuntu/findez-cad-native-planning-20261116')
FRONT=ROOT/'frontend'
BACK=ROOT/'backend'
LIVE_BACK=Path('/home/ubuntu/findez/backend')
BASE='/home/ubuntu/findez-cad-purchasing-20261116/frontend'

def output(args): return sp.check_output(args,text=True).strip()
def run(args,**kwargs): return sp.run(args,check=True,**kwargs)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
def snapshot(path): return {str(p.relative_to(path)):sha(p) for p in path.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
def get(url):
    with urllib.request.urlopen(url,timeout=15) as response: return response.read()

files=json.loads((ROOT/'files.json').read_text())
if sys.argv[1]=='stage':
    active=Path(output(['systemctl','show','findez-web','-p','WorkingDirectory','--value']))
    assert str(active)==BASE, 'Refresh the candidate against the new production source'
    assert not FRONT.exists() and not BACK.exists()
    shutil.copytree(active,FRONT,ignore=shutil.ignore_patterns('node_modules','.next','public','.git'),symlinks=True)
    os.symlink((active/'node_modules').resolve(),FRONT/'node_modules')
    shutil.copytree(active/'public',FRONT/'public',copy_function=os.link)
    shutil.copytree(LIVE_BACK/'app',BACK/'app',ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
    before={'frontend':snapshot(active/'src'),'backend':snapshot(LIVE_BACK/'app')}
    manifest={name:{'before':sha((active/name.removeprefix('frontend/')) if name.startswith('frontend/') else LIVE_BACK/name.removeprefix('backend/'))} for name in files}
    # Do not let patching a candidate hardlink alter the live download.
    (FRONT/'public/downloads/findez-fusion-workspace.zip').unlink()
    shutil.copy2(active/'public/downloads/findez-fusion-workspace.zip',FRONT/'public/downloads/findez-fusion-workspace.zip')
    run(['git','apply','--check',str(ROOT/'changes.patch')],cwd=ROOT)
    run(['git','apply',str(ROOT/'changes.patch')],cwd=ROOT)
    with tarfile.open(ROOT/'new-files.tgz') as archive:
        for member in archive.getmembers():
            assert member.name in files and not (ROOT/member.name).exists(),member.name
        archive.extractall(ROOT,filter='data')
    after={'frontend':snapshot(FRONT/'src'),'backend':snapshot(BACK/'app')}
    for area,prefix in [('frontend','frontend/src/'),('backend','backend/app/')]:
        changed={prefix+n for n in before[area].keys()|after[area].keys() if before[area].get(n)!=after[area].get(n)}
        assert changed=={name for name in files if name.startswith(prefix)},changed
    for name in files: manifest[name]['after']=sha(ROOT/name)
    assert snapshot(active/'src')==before['frontend'] and snapshot(LIVE_BACK/'app')==before['backend']
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    (ROOT/'receipt.json').write_text(json.dumps({'base':str(active),'before':before,'after':after},indent=2))
    cache=Path('/dev/shm/findez-cad-native-planning-cache');cache.mkdir(exist_ok=False)
    (FRONT/'.next').mkdir(exist_ok=True);os.symlink(cache,FRONT/'.next/cache')
    run(['npm','run','build','--','--webpack'],cwd=FRONT)
    print('Candidate production build:',(FRONT/'.next/BUILD_ID').read_text().strip(),flush=True)
elif sys.argv[1]=='activate':
    # A separately approved migration must already be installed before activation.
    receipt=json.loads((ROOT/'receipt.json').read_text()); manifest=json.loads((ROOT/'manifest.json').read_text())
    active=Path(receipt['base'])
    assert output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'])==str(active)
    assert snapshot(active/'src')==receipt['before']['frontend']
    assert snapshot(LIVE_BACK/'app')==receipt['before']['backend']
    assert snapshot(FRONT/'src')==receipt['after']['frontend']
    assert snapshot(BACK/'app')==receipt['after']['backend']
    for name,value in manifest.items(): assert sha(ROOT/name)==value['after'],name
    assert output(['docker','exec','supabase-db','psql','-X','-U','postgres','-d','postgres','-Atq','-c',"SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cad_device_grants' AND column_name='allow_purchasing')"])=='t'
    backup=ROOT/'backend-before'; backup.mkdir(exist_ok=False)
    backend_files=[name.removeprefix('backend/') for name in files if name.startswith('backend/')]
    for name in backend_files:
        if (LIVE_BACK/name).exists():
            (backup/name).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(LIVE_BACK/name,backup/name)
    for p in (active/'.next/static').rglob('*'):
        if p.is_file():
            target=FRONT/'.next/static'/p.relative_to(active/'.next/static')
            if target.exists():assert sha(p)==sha(target)
            else:target.parent.mkdir(parents=True,exist_ok=True);os.link(p,target)
    for p in (FRONT/'.next/static').rglob('*'):
        if p.is_dir():p.chmod(0o755)
    directory=Path('/etc/systemd/system/findez-web.service.d')
    count=max([len(p.name)-len(p.name.lstrip('z')) for p in directory.glob('*.conf')]+[0])+1
    web_conf=directory/('z'*count+'-cad-native-planning.conf')
    api_conf=Path('/etc/systemd/system/findez.service.d/zzzzzz-cad-native-planning.conf')
    assert not web_conf.exists() and not api_conf.exists()
    try:
        for name in backend_files:
            (LIVE_BACK/name).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(BACK/name,LIVE_BACK/name)
        api_conf.parent.mkdir(parents=True,exist_ok=True)
        api_conf.write_text('[Service]\nEnvironment=CAD_NATIVE_PURCHASING_ENABLED=true\n')
        web_conf.write_text('[Service]\nWorkingDirectory='+str(FRONT)+'\n')
        run(['systemctl','daemon-reload']);run(['systemctl','restart','findez'])
        for n in range(30):
            try:get('https://findez.openstack.ftctools.com/health/db');break
            except Exception:
                if n==29:raise
                time.sleep(1)
        run(['systemctl','restart','findez-web'])
        for n in range(30):
            try:html=get('http://127.0.0.1:3000/docs/cad').decode();break
            except Exception:
                if n==29:raise
                time.sleep(1)
        assert 'Plan several projects against shared stock' in html
        for path in ['/','/cad-intelligence','/docs/api','/docs/connections','/cad','/cad/fusion/connect']:get('http://127.0.0.1:3000'+path)
        assert hashlib.sha256(get('http://127.0.0.1:3000/downloads/findez-fusion-workspace.zip?v=0.5.0')).hexdigest()==manifest['frontend/public/downloads/findez-fusion-workspace.zip']['after']
    except Exception:
        for name in backend_files:
            if (backup/name).exists():shutil.copy2(backup/name,LIVE_BACK/name)
            elif (LIVE_BACK/name).exists():(LIVE_BACK/name).unlink()
        for conf in [web_conf,api_conf]:
            if conf.exists():conf.unlink()
        run(['systemctl','daemon-reload']);run(['systemctl','restart','findez']);run(['systemctl','restart','findez-web']);raise
    (ROOT/'activation.json').write_text(json.dumps({'active':str(FRONT),'build':(FRONT/'.next/BUILD_ID').read_text().strip(),'web_dropin':str(web_conf),'api_dropin':str(api_conf),'checks':'passed'},indent=2))
    print('Activated candidate and verified documentation, downloads and routes.')
else:raise ValueError('Use stage or activate')

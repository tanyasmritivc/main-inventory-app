"""Prepare the additive web gateway from the current running frontend."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

release=Path('/home/ubuntu/findez-web-releases/dashboard-gateway-20261018')
live=Path(subprocess.check_output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'],text=True).strip())
candidate=release/'frontend'
assert not candidate.exists()
release.mkdir(exist_ok=True)
def hashes(root):
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*')
            if p.is_file() and not any(x in {'node_modules','.next','coverage'} for x in p.relative_to(root).parts)}
baseline=hashes(live)
(release/'baseline.json').write_text(json.dumps(baseline))
(release/'active.json').write_text(json.dumps({'directory':str(live),'build':(live/'.next/BUILD_ID').read_text().strip()}))
shutil.copytree(live,candidate,symlinks=True,ignore=shutil.ignore_patterns('node_modules','.next','coverage'))
(candidate/'node_modules').symlink_to((live/'node_modules').resolve())
shutil.copytree(live/'.next/cache',candidate/'.next/cache',dirs_exist_ok=True)
with tarfile.open('/home/ubuntu/findez-dashboard/findez-dashboard-gateway.tar') as archive:
    archive.extractall(candidate,filter='data')
prepared=hashes(candidate)
assert set(prepared)-set(baseline)=={'src/app/api/founder/[...path]/route.ts'}
assert all(prepared[n]==v for n,v in baseline.items())
with (release/'build.log').open('w') as out:
    subprocess.run(['npm','run','build','--','--webpack'],cwd=candidate,stdout=out,stderr=subprocess.STDOUT,check=True)
print(json.dumps({'build':(candidate/'.next/BUILD_ID').read_text().strip(),'original_files_preserved':len(baseline),'gateway_added':True}))

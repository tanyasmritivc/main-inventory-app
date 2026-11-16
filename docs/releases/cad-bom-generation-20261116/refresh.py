"""Carry newer concurrent production changes into the inactive web candidate."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

root = Path('/home/ubuntu/findez-cad-bom-generation-20261116')
front = root / 'frontend'
manifest = json.loads((root / 'manifest.json').read_text())['frontend']
active = Path(subprocess.check_output(['systemctl', 'show', 'findez-web', '-p', 'WorkingDirectory', '--value'], text=True).strip())
assert active != front
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
for name, expected in manifest.items():
    assert sha(active / name) == expected['before'], 'Overlapping production change: ' + name
    assert sha(front / name) == expected['after'], 'Candidate changed: ' + name
assert sha(active / 'package-lock.json') == sha(front / 'package-lock.json'), 'Dependency change needs review'
excluded = {'.next', 'node_modules', '.git', 'coverage'}
def files(base):
    import os
    for directory, dirs, names in os.walk(base):
        dirs[:] = [name for name in dirs if name not in excluded]
        for name in names:
            path = Path(directory) / name
            if not name.endswith('.tsbuildinfo'):
                yield str(path.relative_to(base))
latest = set(files(active))
for name in latest:
    if name not in manifest and sha(front / name) != sha(active / name):
        target = front / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists(): target.unlink()
        shutil.copy2(active / name, target)
for name in set(files(front)) - latest - set(manifest):
    (front / name).unlink()
assert all(sha(active / name) == sha(front / name) for name in latest if name not in manifest)
receipt = json.loads((root / 'preparation.json').read_text())
receipt['base'] = str(active)
receipt['before']['frontend'] = {str(p.relative_to(active / 'src')): sha(p) for p in (active / 'src').rglob('*') if p.is_file()}
(root / 'preparation.json').write_text(json.dumps(receipt, indent=2))
print('Preserved latest unrelated production files from ' + str(active) + '. Candidate is still inactive.')

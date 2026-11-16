"""Prepare an inactive candidate from current production. Does not activate it."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

root = Path('/home/ubuntu/findez-cad-bom-generation-20261116')
manifest = json.loads((root / 'manifest.json').read_text())
active = Path(subprocess.check_output(['systemctl', 'show', 'findez-web', '-p', 'WorkingDirectory', '--value'], text=True).strip())
backend = Path('/home/ubuntu/findez/backend')
front = root / 'frontend'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

def hashes(path):
    return {str(p.relative_to(path)): sha(p) for p in path.rglob('*') if p.is_file() and '__pycache__' not in p.parts}

assert not front.exists(), 'Candidate already exists; inspect before replacing it.'
for area, base in [('frontend', active), ('backend', backend)]:
    for name, expected in manifest[area].items():
        assert sha(base / name) == expected['before'], 'Source changed: ' + area + '/' + name
cache = Path('/home/ubuntu/findez-cad-page-20261116/frontend/.next/cache')
assert cache.parent.parent != active
if cache.exists():
    shutil.rmtree(cache)  # Rebuildable cache of our inactive prior CAD release only.
before = {'frontend': hashes(active / 'src'), 'backend': hashes(backend / 'app')}
shutil.copytree(active, front, ignore=shutil.ignore_patterns('.next', 'node_modules', 'public', '.git', 'coverage', '*.tsbuildinfo'))
os.symlink(str((active / 'node_modules').resolve()), front / 'node_modules')
shutil.copytree(active / 'public', front / 'public', copy_function=os.link)
shutil.copytree(backend / 'app', root / 'backend/app', ignore=shutil.ignore_patterns('__pycache__'))
with tarfile.open(root / 'overlay.tgz') as archive:
    for entry in archive.getmembers():
        area, name = entry.name.split('/', 1)
        assert name in manifest[area] and entry.isfile()
        dest = root / area / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists():
            dest.unlink()  # Break the public-file hardlink before replacing it.
        dest.write_bytes(archive.extractfile(entry).read())
        assert sha(dest) == manifest[area][name]['after']
for area, directory in [('frontend', 'src'), ('backend', 'app')]:
    after = hashes(root / area / directory)
    allowed = {name.removeprefix(directory + '/') for name in manifest[area] if name.startswith(directory + '/')}
    assert all(after.get(name) == digest for name, digest in before[area].items() if name not in allowed)
    assert all(name in before[area] or name in allowed for name in after)
(root / 'preparation.json').write_text(json.dumps({'base': str(active), 'before': before, 'production_modified': False}, indent=2))
print(json.dumps({'candidate': str(root), 'base': str(active), 'web_overlay_files': len(manifest['frontend']), 'backend_overlay_files': len(manifest['backend']), 'activated': False}))

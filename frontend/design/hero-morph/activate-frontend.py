"""Activate the checked frontend without changing service, proxy or env config."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import urllib.request

release = Path('/home/ubuntu/findez-web-releases/hero-morph-20261018')
candidate = release / 'frontend'
live = Path('/home/ubuntu/findez-web-releases/invitation-handoff-20261017/frontend')
baseline = json.loads((release / 'baseline.json').read_text())
expected_build = 'ocvFkneLLa0EzDFA14ToX'
new_files = {
    'src/components/site/hero-morph.tsx',
    'src/components/site/hero-morph-engine.ts',
    'src/components/site/hero-morph.css',
    'src/components/site/legacy/landing-lab-before-hero-morph.tsx',
    'public/images/landing/hero-workbench.jpg',
}


def hashes(root):
    return {
        str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in root.rglob('*')
        if p.is_file() and not any(
            part in {'node_modules', '.next', 'coverage'}
            for part in p.relative_to(root).parts
        )
    }


def service_directory():
    return subprocess.check_output([
        'systemctl', 'show', 'findez-web', '-p', 'WorkingDirectory', '--value',
    ], text=True).strip()


assert service_directory() == str(live), 'Another frontend release became active'
assert hashes(live) == baseline, 'The live frontend changed after preparation'
prepared = hashes(candidate)
assert set(prepared) - set(baseline) == new_files
assert {n for n in baseline if prepared[n] != baseline[n]} == {
    'src/components/site/landing-lab.tsx',
}
assert (candidate / '.next/BUILD_ID').read_text().strip() == expected_build
prior_build = (live / '.next/BUILD_ID').read_text().strip()
config_paths = [
    Path('/etc/systemd/system/findez-web.service'),
    Path('/etc/systemd/system/findez-web.service.d/web-rebuild.conf'),
    Path('/etc/systemd/system/findez-web.service.d/network-online.conf'),
    Path('/home/ubuntu/findez/frontend/.env.production'),
]
config_hashes = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in config_paths}

# Stop only the private candidate listener before exchanging its directory.
listener = subprocess.run(['fuser', '-n', 'tcp', '3215'], capture_output=True, text=True)
if listener.returncode == 0:
    pids = [int(value) for value in listener.stdout.split()]
    assert len(pids) == 1
    pid = pids[0]
    assert Path(f'/proc/{pid}/cwd').resolve() == candidate
    assert b'next' in Path(f'/proc/{pid}/cmdline').read_bytes()
    os.kill(pid, signal.SIGTERM)
    for _ in range(30):
        if not Path(f'/proc/{pid}').exists():
            break
        time.sleep(.1)

libc = ctypes.CDLL(None, use_errno=True)
rename_exchange = libc.renameat2
rename_exchange.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]


def exchange():
    if rename_exchange(-100, os.fsencode(candidate), -100, os.fsencode(live), 2):
        raise OSError(ctypes.get_errno(), 'Atomic frontend directory exchange failed')


def restart():
    subprocess.run(['sudo', 'systemctl', 'restart', 'findez-web'], check=True, timeout=30)


exchange()
try:
    restart()
    for attempt in range(25):
        try:
            request = urllib.request.Request('http://127.0.0.1:3000/', headers={'Host': 'findez.ai'})
            with urllib.request.urlopen(request, timeout=2) as response:
                html = response.read().decode()
            assert 'fzh-stage' in html and 'Try FindEZ on the web' in html
            break
        except Exception:
            if attempt == 24:
                raise
            time.sleep(.3)
    assert (live / '.next/BUILD_ID').read_text().strip() == expected_build
    assert service_directory() == str(live)
    assert hashes(live) == prepared
    assert all(hashlib.sha256(p.read_bytes()).hexdigest() == value for p, value in config_hashes.items())
    assert (candidate / '.next/BUILD_ID').read_text().strip() == prior_build
except Exception:
    exchange()
    restart()
    raise

receipt = {
    'url': 'https://findez.ai/',
    'build_id': expected_build,
    'prior_build_id': prior_build,
    'active_frontend': str(live),
    'rollback_frontend': str(candidate),
    'original_source_files_preserved': len(baseline) - 1,
    'changed_existing_files': ['src/components/site/landing-lab.tsx'],
    'new_runtime_files': sorted(new_files),
    'environment_and_service_configuration_unchanged': True,
    'backend_mobile_database_untouched': True,
    'frontend_service_active': subprocess.check_output([
        'systemctl', 'is-active', 'findez-web',
    ], text=True).strip(),
}
(release / 'deployment.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt))

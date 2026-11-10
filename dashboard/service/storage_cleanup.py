"""Hourly, narrowly scoped cleanup of inactive website compiler caches.

No network credentials or customer storage access. Default execution is a dry run.
"""
import argparse
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import time

RELEASES = Path('/home/ubuntu/findez-web-releases')
RECEIPT = Path('/home/ubuntu/findez-dashboard-data/storage-cleanup.json')
CACHE_SUFFIX = Path('frontend/.next/cache/webpack')
MIN_AGE_SECONDS = 24 * 3600


def active_paths():
    # Protect configured production even while its process is restarting.
    configured = subprocess.check_output(
        ['systemctl', 'show', 'findez-web.service', '-p', 'WorkingDirectory', '--value'],
        text=True, timeout=10).strip()
    if not configured or not Path(configured).is_absolute():
        raise RuntimeError('Active release could not be identified')
    paths = {Path(configured).resolve()}
    for process in Path('/proc').iterdir():
        if process.name.isdigit():
            try:
                paths.add((process / 'cwd').resolve(strict=True))
            except (OSError, RuntimeError):
                continue
    return paths


def cache_details(path):
    size, latest = 0, path.lstat().st_mtime
    for folder, dirs, files in os.walk(path, followlinks=False):
        for name in dirs + files:
            entry = Path(folder) / name
            info = entry.lstat()
            latest = max(latest, info.st_mtime)
            if stat.S_ISREG(info.st_mode):
                size += info.st_blocks * 512
    return size, latest


def clean_caches(root, active, *, apply=False, current_time=None):
    root = Path(root)
    if root.is_symlink() or not root.is_dir() or root.resolve() != root:
        raise ValueError('Expected a real, absolute releases directory')
    current_time = time.time() if current_time is None else current_time
    report = dict(status='ok', at=datetime.now(timezone.utc).isoformat(),
                  removed_bytes=0, removed_caches=0, eligible_bytes=0,
                  skipped_active=0, skipped_recent=0, skipped_unsafe=0, errors=0,
                  dry_run=not apply)
    for release in sorted(root.iterdir()):
        if release.is_symlink() or not release.is_dir():
            continue
        if any(p == release or release in p.parents for p in active):
            report['skipped_active'] += 1
            continue
        cache = release / CACHE_SUFFIX
        if not cache.exists() and not cache.is_symlink():
            continue
        # Reject symlinks at every level. rmtree itself also does not follow
        # symlinks within a cache tree and uses fd-based traversal on Linux.
        if any(p.is_symlink() for p in [cache, *cache.parents] if p != root.parent) or cache.resolve() != cache:
            report['skipped_unsafe'] += 1
            continue
        try:
            size, latest = cache_details(cache)
            if current_time - latest < MIN_AGE_SECONDS:
                report['skipped_recent'] += 1
                continue
            report['eligible_bytes'] += size
            if apply:
                shutil.rmtree(cache)
                report['removed_bytes'] += size
                report['removed_caches'] += 1
        except OSError:
            report['errors'] += 1
    if report['errors']:
        report['status'] = 'failed'
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    with (RECEIPT.parent / 'storage-cleanup.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            if args.apply and not shutil.rmtree.avoids_symlink_attacks:
                raise RuntimeError('Safe directory deletion unavailable')
            report = clean_caches(RELEASES, active_paths(), apply=args.apply)
        except Exception:
            report = dict(status='failed', at=datetime.now(timezone.utc).isoformat(),
                          removed_bytes=0, removed_caches=0, errors=1, dry_run=not args.apply)
        if args.apply:
            temporary = RECEIPT.with_suffix('.tmp')
            temporary.write_text(json.dumps(report, indent=2) + '\n')
            temporary.chmod(0o600)
            temporary.replace(RECEIPT)
        print(json.dumps(report))
        if report['status'] != 'ok':
            raise SystemExit(1)


if __name__ == '__main__':
    main()

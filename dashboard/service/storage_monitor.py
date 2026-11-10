"""Read-only storage status and dashboard incident rules."""
from datetime import datetime, timezone
import json
from pathlib import Path

GIB = 1024 ** 3
CLEANUP_RECEIPT = Path('/home/ubuntu/findez-dashboard-data/storage-cleanup.json')


def storage_status(disk, receipt_path=CLEANUP_RECEIPT, at=None):
    at = at or datetime.now(timezone.utc)
    used_percent = (disk.total - disk.free) / disk.total * 100
    critical = used_percent >= 90 or disk.free <= 2 * GIB
    warning = critical or used_percent >= 80 or disk.free <= 5 * GIB
    cleanup = {'status': 'unavailable', 'at': None, 'removed_bytes': None, 'removed_caches': None}
    try:
        receipt = json.loads(Path(receipt_path).read_text())
        timestamp = datetime.fromisoformat(receipt['at'])
        age = (at - timestamp).total_seconds()
        cleanup.update(at=receipt['at'])
        if age < -60 or age > 2 * 3600:
            cleanup['status'] = 'stale'
        elif receipt['status'] != 'ok' or receipt.get('dry_run') is True:
            cleanup['status'] = 'failed'
        else:
            removed = int(receipt['removed_bytes'])
            count = int(receipt['removed_caches'])
            if removed < 0 or count < 0:
                raise ValueError('Invalid cleanup counters')
            cleanup.update(status='ok', removed_bytes=removed, removed_caches=count)
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return dict(total_bytes=disk.total, free_bytes=disk.free,
                used_percent=round(used_percent, 1),
                level='critical' if critical else 'warning' if warning else 'healthy',
                cleanup=cleanup)


def update_storage_incidents(store, status):
    level = status['level']
    detail = (f"Server storage is {status['used_percent']:.1f}% used with "
              f"{status['free_bytes']/GIB:.1f} GiB available. "
              "Warnings start at 80% used or 5 GiB free; critical at 90% used or 2 GiB free. "
              "Uploads and scanning can fail when the disk fills. Open Infrastructure for cleanup status.")
    store.incident('health:disk', 'Upload storage needs attention', detail,
                   'critical' if level == 'critical' else 'warning', level != 'healthy')
    store.incident('storage:capacity', 'Plan more server storage',
                   "Storage remains under pressure. Review the latest cleanup result in Infrastructure. "
                   "If free space stays low after cleanup, increase the server volume through the hosting provider. "
                   "This dashboard does not resize or purchase storage automatically.",
                   'critical' if level == 'critical' else 'warning', level != 'healthy')
    store.incident('storage:cleanup', 'Automatic cache cleanup needs attention',
                   "The hourly cleanup has no successful result within two hours. "
                   "Check Infrastructure for its last result. Customer photos and saved inventory are excluded from cleanup.",
                   'warning', status['cleanup']['status'] != 'ok')

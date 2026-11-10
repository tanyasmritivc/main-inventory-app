import asyncio
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
from types import SimpleNamespace
import sys
from unittest.mock import patch

import httpx
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from collectors import Sources
from storage_monitor import GIB, storage_status, update_storage_incidents
from storage_cleanup import clean_caches, CACHE_SUFFIX
from store import Store

NOW = datetime(2026, 11, 10, tzinfo=timezone.utc)


def receipt(tmp_path, **overrides):
    p = tmp_path / 'receipt.json'
    p.write_text(json.dumps(dict(at=NOW.isoformat(), status='ok', removed_bytes=0,
                                removed_caches=0, dry_run=False, **overrides)))
    return p


@pytest.mark.parametrize('total,free,level', [(100,21,'healthy'),(100,20,'warning'),(100,10,'critical'),(20,5,'warning'),(10,2,'critical')])
def test_warning_and_critical_boundaries(tmp_path,total,free,level):
    state = storage_status(SimpleNamespace(total=total*GIB,free=free*GIB),receipt(tmp_path),NOW)
    assert state['level'] == level
    assert state['cleanup']['status'] == 'ok'
    assert state['cleanup']['removed_bytes'] == 0


def test_cleanup_reports_missing_stale_failure_and_corruption_honestly(tmp_path):
    disk = SimpleNamespace(total=100*GIB,free=50*GIB)
    p = tmp_path/'receipt.json'
    assert storage_status(disk,p,NOW)['cleanup']['status']=='unavailable'
    for payload,expected in [
        ({'at':(NOW-timedelta(hours=3)).isoformat(),'status':'ok'},'stale'),
        ({'at':NOW.isoformat(),'status':'failed'},'failed'),
        ({'at':NOW.isoformat(),'status':'ok','removed_bytes':-1,'removed_caches':0},'unavailable'),
        ({'at':NOW.isoformat(),'status':'ok','removed_bytes':0,'removed_caches':0,'dry_run':True},'failed'),
    ]:
        p.write_text(json.dumps(payload))
        assert storage_status(disk,p,NOW)['cleanup']['status']==expected
    p.write_text('partial json')
    assert storage_status(disk,p,NOW)['cleanup']['removed_bytes'] is None


def test_incident_escalation_recovery_and_reopen_keep_current_details(tmp_path):
    store=Store(tmp_path/'db.sqlite')
    p=receipt(tmp_path)
    for free,severity in [(20,'warning'),(8,'critical')]:
        state=storage_status(SimpleNamespace(total=100*GIB,free=free*GIB),p,NOW)
        update_storage_incidents(store,state)
        issue=next(i for i in store.issues() if i['id']=='health:disk')
        assert issue['severity']==severity
        assert f'{free:.1f} GiB' in issue['description']
    update_storage_incidents(store,storage_status(SimpleNamespace(total=100*GIB,free=40*GIB),p,NOW))
    assert all(i['status']=='resolved' for i in store.issues())
    p.unlink()
    update_storage_incidents(store,storage_status(SimpleNamespace(total=100*GIB,free=40*GIB),p,NOW))
    assert next(i for i in store.issues() if i['id']=='storage:cleanup')['status']=='open'


def make_cache(root,name,age=48*3600):
    folder=root/name/CACHE_SUFFIX
    folder.mkdir(parents=True)
    (folder/'compiled.pack').write_bytes(b'build data'*1000)
    for p in [folder,folder/'compiled.pack']:
        os.utime(p,(NOW.timestamp()-age,)*2)
    return folder


def test_cleanup_only_deletes_old_inactive_compiler_caches(tmp_path):
    root=tmp_path.resolve()/'releases'; root.mkdir()
    old=make_cache(root,'old')
    active=make_cache(root,'active')
    recent=make_cache(root,'recent',age=60)
    artifacts=root/'old/frontend/.next/server';artifacts.mkdir();(artifacts/'page.js').write_text('keep release')
    customer=tmp_path/'photos';customer.mkdir();(customer/'photo.jpg').write_bytes(b'keep customer data')
    report=clean_caches(root,{root/'active/frontend'},current_time=NOW.timestamp())
    assert report['eligible_bytes']>0 and report['removed_caches']==0 and old.exists()
    report=clean_caches(root,{root/'active/frontend'},apply=True,current_time=NOW.timestamp())
    assert report['removed_caches']==1 and not old.exists()
    assert active.exists() and recent.exists() and artifacts.exists() and customer.exists()


def test_symlink_targets_and_ancestors_are_never_traversed(tmp_path):
    root=tmp_path.resolve()/'releases';root.mkdir()
    protected=tmp_path/'customer';protected.mkdir();(protected/'important').write_text('keep')
    (root/'linked-release').symlink_to(protected,target_is_directory=True)
    cache=make_cache(root,'linked-cache');(cache/'compiled.pack').unlink();cache.rmdir();cache.symlink_to(protected,target_is_directory=True)
    release=root/'linked-ancestor';release.mkdir();(release/'frontend').symlink_to(protected,target_is_directory=True)
    (protected/'.next/cache/webpack').mkdir(parents=True)
    report=clean_caches(root,set(),apply=True,current_time=NOW.timestamp())
    assert report['removed_caches']==0
    assert (protected/'important').read_text()=='keep'
    assert (protected/'.next/cache/webpack').exists()


def test_cleanup_failure_is_visible_and_does_not_claim_success(tmp_path):
    root=tmp_path.resolve()/'releases';root.mkdir();cache=make_cache(root,'old')
    with patch('storage_cleanup.shutil.rmtree',side_effect=PermissionError):
        report=clean_caches(root,set(),apply=True,current_time=NOW.timestamp())
    assert report['status']=='failed' and report['removed_caches']==0 and cache.exists()


def test_health_snapshot_contains_app_compatible_storage_metrics(tmp_path):
    async def run():
        async with httpx.AsyncClient(transport=httpx.MockTransport(lambda r:httpx.Response(200))) as client:
            source=Sources({'SUPABASE_URL':'https://example.test','SUPABASE_SERVICE_ROLE_KEY':'fake'},client)
            with patch('collectors.storage_status',return_value=storage_status(SimpleNamespace(total=100*GIB,free=40*GIB),receipt(tmp_path),NOW)),patch('collectors.shutil.disk_usage',return_value=SimpleNamespace(total=100*GIB,free=40*GIB)):
                result=await source.health()
            metrics={m['id']:m for m in result['metrics']}
            assert metrics['storage_cleanup']['value']=='On'
            assert metrics['storage_cleanup']['unit']=='count' # Existing app renders text without a unit suffix.
            assert metrics['disk_free']['value']==40
            assert metrics['storage_cleanup_removed']['value']==0
            assert result['storage']['level']=='healthy'
            assert all(c['id']!='upload_storage' for c in result['checks'])
    asyncio.run(run())

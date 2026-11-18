"""Run as a separate systemd worker: python -m app.services.enrichment.worker."""
import asyncio
import hashlib
import logging
import os
from .classification import infer
from .photos import suggest
from .download import download_photo

log = logging.getLogger(__name__)


async def process(job, db):
    from app.services.storage import upload_image
    rows = db.table('items').select('*').eq('item_id', job['item_id']).eq('inventory_id', job['inventory_id']).execute().data or []
    if not rows:
        return 'skipped', {}, None
    item = rows[0]
    if job['kind'] == 'classification':
        if item.get('inventory_role', 'unclassified') != 'unclassified':
            return 'skipped', {}, None
        return 'ready', await asyncio.to_thread(infer, job['identity']), None
    settings = db.table('app_inventory_intelligence_settings').select('images_enabled').eq('inventory_id', job['inventory_id']).execute().data or []
    if item.get('image_url') or (settings and not settings[0]['images_enabled']):
        return 'skipped', {}, None
    candidate = await suggest(job['identity'])
    if not candidate.get('image_url'):
        return 'no_match', candidate, None
    content = await asyncio.to_thread(download_photo, candidate['image_url'])
    digest = hashlib.sha256(content).hexdigest()
    # The same image on different product identities is not an exact match.
    peers = db.table('app_item_enrichment').select('identity,result').eq('inventory_id', job['inventory_id']).eq('kind', 'image').contains('result', {'image_sha256': digest}).limit(100).execute().data or []
    identity = candidate.get('identity') or {}
    def product_key(row):
        return tuple(str(row.get(k) or '').strip().casefold() for k in ('barcode', 'brand', 'part_number'))
    key = product_key(identity)
    if any(product_key((peer.get('result') or {}).get('identity') or {}) != key or not any(key) for peer in peers):
        return 'no_match', {'reason': 'This photo also appeared for another part. Upload a product photo or check the exact identifier.'}, None
    stored = await asyncio.to_thread(upload_image, user_id=item['user_id'], filename='product-review.jpg', content=content)
    return 'ready', {**candidate, 'source_image_url': candidate['image_url'], 'image_url': stored.url,
                     'storage_path': stored.path, 'image_sha256': digest}, stored.path


async def run_once():
    from app.services.supabase_client import get_supabase_raw
    from app.services.storage import delete_image
    db = get_supabase_raw()
    job = db.rpc('findez_enrichment_claim', {}).execute().data
    if not job:
        return False
    path = None
    try:
        status, result, path = await process(job, db)
    except Exception:
        log.warning('Enrichment processing failed for job %s', job['id'])
        status, result = 'failed', {'reason': 'This suggestion could not be prepared. You can retry it.'}
    try:
        saved = db.rpc('findez_enrichment_finish', {'p_id': job['id'], 'p_token': job['lease_token'], 'p_status': status, 'p_result': result}).execute().data
        # A stale lease may not replace a newer attempt. Its unattached image is disposable.
        if path and (not saved or not saved.get('saved') or saved.get('status') != 'ready'):
            await asyncio.to_thread(delete_image, path=path)
    except Exception:
        # Do not remove the image after an uncertain commit. Reconcile through
        # the durable job result; the same lease can safely be retried.
        log.warning('Enrichment completion receipt unavailable for job %s', job['id'])
    return True


async def cleanup_once():
    from app.services.supabase_client import get_supabase_raw
    from app.services.storage import delete_image, document_path_in_scope
    from app.services.deletion_cleanup import _references
    db = get_supabase_raw()
    rows = db.table('app_enrichment_image_cleanup').select('path').order('created_at').limit(50).execute().data or []
    if not rows: return
    images, _, _ = await asyncio.to_thread(_references, db)
    for row in rows:
        path = row['path']
        # Never follow arbitrary object paths or remove another record's photo.
        if path in images: continue
        from uuid import UUID
        owner = str(UUID(path.split('/')[0]))
        if not document_path_in_scope(path, owner + '/'):
            raise ValueError('Photo cleanup needs ownership review')
        await asyncio.to_thread(delete_image, path=path)
        db.table('app_enrichment_image_cleanup').delete().eq('path', path).execute()


async def cleanup_loop():
    while True:
        try:
            await cleanup_once()
        except Exception:
            log.warning('Photo cleanup is pending; durable receipts retained')
        await asyncio.sleep(300)


async def processing_loop():
    while True:
        try:
            worked = await run_once()
        except Exception:
            log.warning('Enrichment queue unavailable')
            worked = False
        await asyncio.sleep(1 if worked else 30)


async def main():
    if os.getenv('FINDEZ_ENRICHMENT_WORKER_ENABLED') != 'true':
        raise RuntimeError('Enable the worker only after migration 086 is verified.')
    from app.core.config import get_settings
    if not get_settings().findez_inventory_intelligence_enabled:
        raise RuntimeError('Enable inventory intelligence after migration verification.')
    concurrency = min(4, max(1, int(os.getenv('FINDEZ_ENRICHMENT_CONCURRENCY', '2'))))
    await asyncio.gather(cleanup_loop(), *(processing_loop() for _ in range(concurrency)))


if __name__ == '__main__':
    asyncio.run(main())

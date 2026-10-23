"""Durable inventory file cleanup. Only recorded, scoped, unreferenced files go."""
import asyncio
import logging
import re
from datetime import datetime, timezone
from urllib.parse import unquote, urlsplit
from app.core.config import get_settings
from app.services.supabase_client import get_supabase_raw
from app.services.storage import document_path_in_scope

logger = logging.getLogger(__name__)
PAGE = 500
MAX_REFERENCE_ROWS = 10000


def _image_path(url: str) -> str | None:
    return _bucket_path(url, get_settings().supabase_storage_bucket)


def _bucket_path(url: str, bucket: str) -> str | None:
    path = urlsplit(url).path
    for marker in (f'/storage/v1/object/public/{bucket}/', f'/storage/v1/object/sign/{bucket}/', f'/storage/v1/object/{bucket}/'):
        if marker in path:
            return unquote(path.split(marker, 1)[1])
    return None


def _strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from _strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from _strings(child)


def _references(client):
    images, documents, profiles = set(), set(), set()
    for table, fields, key in (
        ('items', 'image_url', 'item_id'), ('item_events', 'image_url', 'event_id'),
        ('capture_reviews', 'image_url,source_frame_url,scan_evidence', 'review_id'),
        ('messages', 'content', 'id'), ('documents', 'storage_path', 'document_id'),
        ('profiles', 'avatar_path', 'id'),
    ):
        offset = 0
        while True:
            rows = client.table(table).select(fields).order(key).range(offset, offset + PAGE - 1).execute().data
            if not isinstance(rows, list):
                raise ValueError('Reference lookup could not be confirmed')
            for row in rows:
                for value in _strings(row):
                    for url in re.findall(r'https?://[^\s"<>]+', value):
                        path = _image_path(url)
                        if path:
                            images.add(path)
                        doc = _bucket_path(url, 'documents')
                        profile = _bucket_path(url, 'profile-photos')
                        if doc:
                            documents.add(doc)
                        if profile:
                            profiles.add(profile)
                    if table == 'documents':
                        documents.add(value)
                    if table == 'profiles':
                        profiles.add(value)
            if len(rows) < PAGE:
                break
            offset += PAGE
            if offset >= MAX_REFERENCE_ROWS:
                raise ValueError('Reference scan needs maintenance review')
    return images, documents, profiles


def clean_inventory_files(inventory_id: str) -> bool:
    return _clean_files('app_inventory_deletions', 'inventory_id', inventory_id)


def clean_account_files(actor: str) -> bool:
    client = get_supabase_raw()
    try:
        if client.rpc('findez_finish_account_deletion', {'p_actor': actor}).execute().data is not True:
            return False
    except Exception:
        return False
    return _clean_files('app_account_deletions', 'actor_id', actor)


def _clean_files(table: str, key: str, record_id: str) -> bool:
    client = get_supabase_raw()
    try:
        rows = client.table(table).select('files,completed').eq(key, record_id).execute().data
        if not rows:
            return False
        if rows[0]['completed']:
            return True
        files = rows[0]['files']
        if table == 'app_account_deletions':
            # Identity is already absent. Re-list once more to catch orphaned or
            # in-flight uploads that finished between preparation and Auth removal.
            extra = []
            for bucket, prefix, kind in (
                (get_settings().supabase_storage_bucket, record_id, 'image'),
                ('documents', f'{record_id}/docs', 'document'),
                ('profile-photos', record_id, 'profile'),
            ):
                for offset in range(0, MAX_REFERENCE_ROWS, PAGE):
                    objects = client.storage.from_(bucket).list(prefix, {'limit': PAGE, 'offset': offset})
                    if not isinstance(objects, list):
                        raise ValueError('Storage listing could not be confirmed')
                    extra.extend({'kind': kind, 'path': f"{prefix}/{obj['name']}", 'owner': record_id} for obj in objects if obj.get('id'))
                    if len(objects) < PAGE:
                        break
                else:
                    raise ValueError('Storage cleanup needs maintenance review')
            files = files + extra
            client.table(table).update({'files': files}).eq(key, record_id).execute()
        images, documents, profiles = _references(client)
        seen = set()
        for file in files:
            owner = str(file.get('owner') or '')
            kind = file.get('kind')
            if kind not in ('image', 'document', 'profile'):
                raise ValueError('Unknown file kind')
            path = file.get('path') or _image_path(str(file.get('url') or ''))
            # External URLs are not FindEZ objects and are never fetched/deleted.
            if not path:
                continue
            if not owner or not document_path_in_scope(path, f'{owner}/'):
                raise ValueError('Stored file needs ownership review')
            references = documents if kind == 'document' else profiles if kind == 'profile' else images
            if path in references:
                continue  # Another record still owns a reference to this file.
            bucket = 'documents' if kind == 'document' else 'profile-photos' if kind == 'profile' else get_settings().supabase_storage_bucket
            if (bucket, path) in seen:
                continue
            seen.add((bucket, path))
            client.storage.from_(bucket).remove([path])
        client.table(table).update({
            'completed': True, 'completed_at': datetime.now(timezone.utc).isoformat(), 'files': [],
        }).eq(key, record_id).execute()
        return True
    except Exception:
        # Paths, content and customer identities must not appear in cleanup logs.
        logger.warning('Inventory file cleanup is pending; durable receipt retained')
        return False


async def retry_inventory_file_cleanup():
    while True:
        try:
            client = get_supabase_raw()
            rows = await asyncio.to_thread(lambda: client.table('app_inventory_deletions').select('inventory_id').eq('completed', False).order('created_at').limit(10).execute().data)
            for row in rows or []:
                await asyncio.to_thread(clean_inventory_files, row['inventory_id'])
            accounts = await asyncio.to_thread(lambda: client.table('app_account_deletions').select('actor_id').eq('completed', False).order('created_at').limit(10).execute().data)
            for row in accounts or []:
                await asyncio.to_thread(clean_account_files, row['actor_id'])
        except Exception:
            logger.warning('Inventory cleanup retry unavailable')
        await asyncio.sleep(60)

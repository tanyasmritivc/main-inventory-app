"""Read-only, live-gallery photo comparison for Ask.

Fingerprints identify duplicate/near-duplicate photographs, not product identity
or arbitrary new viewpoints. Only pixel features are cached; authorization,
item membership and gallery references are read again on every question.
"""
import asyncio
from collections import OrderedDict
from array import array
from dataclasses import dataclass
import hashlib
import io
import math
import threading
import time
from urllib.parse import unquote, urlsplit

from PIL import Image, ImageOps, ImageStat

from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin, get_supabase_raw
from app.services.resource_access import request_actor

MAX_PHOTOS = 1000
MAX_BYTES = 10 * 1024 * 1024
MAX_PIXELS = 25_000_000
SEARCH_SECONDS = 8
_CACHE = OrderedDict()
_LOCK = threading.Lock()
_WORKERS = threading.BoundedSemaphore(4)
CACHE_SECONDS = 300


@dataclass(frozen=True)
class Pixels:
    digest: str
    variants: tuple


def fingerprint(content: bytes) -> Pixels:
    if not content or len(content) > MAX_BYTES:
        raise ValueError('Image size is unsupported')
    with Image.open(io.BytesIO(content)) as source:
        if source.width * source.height > MAX_PIXELS:
            raise ValueError('Image dimensions are unsupported')
        image = ImageOps.exif_transpose(source).convert('RGB')
        # Exact means identical file bytes; transformations remain possible matches.
        image.thumbnail((256, 256), Image.Resampling.LANCZOS)
        digest = hashlib.sha256(content).hexdigest()
        variants = []
        for fraction in (1.0, .9, .8, .7):
            dx, dy = image.width * (1-fraction)/2, image.height * (1-fraction)/2
            crop = image.crop((round(dx), round(dy), round(image.width-dx), round(image.height-dy)))
            for turns in range(4):
                rotated = crop.rotate(90 * turns, expand=True)
                grey = rotated.convert('L').resize((16, 16), Image.Resampling.LANCZOS)
                values = tuple(grey.tobytes())
                mean = sum(values) / len(values)
                std = math.sqrt(sum((v-mean)**2 for v in values) / len(values))
                # Uniform backgrounds cannot establish a near-photo match.
                if std < 18:
                    continue
                normalized = array('f', ((v-mean)/std for v in values))
                color = tuple(ImageStat.Stat(rotated).mean)
                variants.append((rotated.width / rotated.height, normalized, color))
        return Pixels(digest, tuple(variants))


def compare(left: Pixels, right: Pixels) -> str | None:
    if left.digest == right.digest:
        return 'same saved photo'
    for ar, values, color in left.variants:
        for br, other, other_color in right.variants:
            if abs(math.log(ar/br)) > .035:
                continue
            if max(abs(a-b) for a,b in zip(color,other_color)) > 24:
                continue
            error = sum(abs(a-b) for a,b in zip(values,other)) / len(values)
            if error < .13:
                return 'possible saved-photo match'
    return None


def storage_path(url: object) -> str | None:
    if not isinstance(url, str):
        return None
    settings = get_settings()
    try:
        parsed = urlsplit(url)
    except ValueError:
        return None
    origins = {urlsplit(str(base)).netloc for base in (settings.supabase_url, settings.supabase_public_url) if base}
    if parsed.scheme not in ('http','https') or parsed.netloc not in origins or parsed.username or parsed.password:
        return None
    for mode in ('public', 'authenticated', 'sign'):
        prefix = f'/storage/v1/object/{mode}/{settings.supabase_storage_bucket}/'
        if parsed.path.startswith(prefix):
            path = unquote(parsed.path[len(prefix):])
            from app.api.routes.private_images import safe_image_path
            try:
                return safe_image_path(path)
            except Exception:
                return None
    return None


def references(inventory: list[dict]) -> list[tuple[str,str]]:
    """Current primary plus later-added gallery photos; never query foreign IDs."""
    ids = sorted({str(item['item_id']) for item in inventory if item.get('item_id')})
    refs = set()
    for offset in range(0,len(ids),100):
        # Re-read primary URLs and existence too, including the final race check.
        items = (get_supabase_admin().table('items').select('item_id,image_url')
            .in_('item_id',ids[offset:offset+100]).execute().data or [])
        live_ids = {str(item['item_id']) for item in items}
        for item in items:
            if path := storage_path(item.get('image_url')):
                refs.add((str(item['item_id']),path))
        if not live_ids:
            continue
        page = 0
        while True:
            rows = (get_supabase_admin().table('item_events').select('item_id,image_url')
                .in_('item_id',sorted(live_ids)).eq('event_type','photo')
                .order('event_id').range(page,page+999).execute().data or [])
            for row in rows:
                item_id = str(row.get('item_id') or '')
                if item_id in live_ids and (path := storage_path(row.get('image_url'))):
                    refs.add((item_id,path))
            if len(rows) < 1000:
                break
            page += 1000
    return sorted(refs)


def _authorized(actor_id: str, path: str) -> bool:
    return get_supabase_raw().rpc('findez_can_read_item_image', {
        'p_actor':actor_id,'p_path':path}).execute().data is True


def _load(actor_id: str, path: str) -> Pixels | None:
    # Global worker bound survives asyncio timeout/cancellation of a thread.
    if not _WORKERS.acquire(blocking=False):
        return None
    try:
        if not _authorized(actor_id,path):
            return None
        key = (str(get_settings().supabase_url),get_settings().supabase_storage_bucket,path)
        with _LOCK:
            entry = _CACHE.get(key)
            if entry and time.monotonic()-entry[0] < CACHE_SECONDS:
                _CACHE.move_to_end(key)
                return entry[1]
        content = get_supabase_raw().storage.from_(get_settings().supabase_storage_bucket).download(path)
        pixels = fingerprint(content)
        with _LOCK:
            _CACHE[key] = (time.monotonic(),pixels)
            _CACHE.move_to_end(key)
            while len(_CACHE)>2048:
                _CACHE.popitem(last=False)
        return pixels
    except Exception:
        # Coverage is explicitly incomplete; never turn a failed read into absence.
        return None
    finally:
        _WORKERS.release()


async def search_saved_photos(*, user_id: str, image_bytes: bytes, inventory: list[dict]) -> dict:
    result = {'matches': [], 'photos_checked':0, 'photos_available':0, 'complete':False,
        'method':'Same or near-duplicate saved photographs; not recognition across arbitrary viewpoints.'}
    actor = request_actor.get()
    actor_id = actor.actor_id if actor else user_id
    try:
        refs = await asyncio.to_thread(references,inventory)
        by_path = {}
        for item_id,path in refs:
            by_path.setdefault(path,[]).append(item_id)
        result['photos_available'] = len(by_path)
        if not by_path:
            result['complete'] = True
            return result
        query = await asyncio.to_thread(fingerprint,image_bytes)
        paths = iter(list(by_path)[:MAX_PHOTOS])
        candidates = []
        async def worker():
            for path in paths:
                pixels = await asyncio.to_thread(_load,actor_id,path)
                if pixels is None:
                    continue
                result['photos_checked'] += 1
                basis = await asyncio.to_thread(compare,query,pixels)
                if basis:
                    candidates.extend((item_id,path,basis) for item_id in by_path[path])
        tasks = [asyncio.create_task(worker()) for _ in range(4)]
        try:
            await asyncio.wait_for(asyncio.gather(*tasks),timeout=SEARCH_SECONDS)
        except TimeoutError:
            pass
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks,return_exceptions=True)
        result['complete'] = result['photos_checked'] == result['photos_available']
        if candidates:
            # Deletion/replacement during comparison must not return a stale photo.
            live = set(await asyncio.to_thread(references,inventory))
            best = {}
            for item_id,path,basis in candidates:
                if (item_id,path) not in live or not await asyncio.to_thread(_authorized,actor_id,path):
                    continue
                if item_id not in best or basis == 'same saved photo':
                    best[item_id] = basis
            result['matches'] = [{'item_id':key,'match_basis':value} for key,value in best.items()]
    except asyncio.CancelledError:
        raise
    except Exception:
        result['complete'] = False
    return result

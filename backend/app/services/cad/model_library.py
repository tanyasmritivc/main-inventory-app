"""Read an operator-published CAD library. The directory is never client writable."""
import base64
import hashlib
import io
import os
from pathlib import Path
from typing import Annotated, Literal
from uuid import UUID

from fastapi import HTTPException
from PIL import Image
from pydantic import Field, HttpUrl, ValidationError, field_validator

from .snapshot import Model
from app.services.supabase_client import get_supabase_raw

Digest = Annotated[str, Field(pattern=r'^[0-9a-f]{64}$')]
Label = Annotated[str, Field(min_length=1, max_length=200)]


class Record(Model):
    catalog_id: UUID
    manufacturer: Label
    part_number: Label
    specifications: dict[str, str] = Field(max_length=32)
    source_url: HttpUrl
    source: Literal['manufacturer', 'third_party']
    revision: Label
    units: Literal['mm', 'cm', 'in', 'm']
    redistribution_approved: Literal[True]
    redistribution_evidence: Label
    reviewed_by: Label
    step_sha256: Digest
    preview_sha256: Digest

    @field_validator('source_url')
    @classmethod
    def public_source(cls, url):
        if url.scheme != 'https' or url.username or url.password or url.query or url.fragment:
            raise ValueError('Use the public HTTPS product or model page.')
        return url


def configured():
    root = os.environ.get('FINDEZ_CAD_MODEL_LIBRARY')
    return bool(root and Path(root).is_dir())


def read_bounded(path, limit):
    with path.open('rb') as source:
        data = source.read(limit + 1)
    if not data or len(data) > limit:
        raise ValueError('Invalid asset size.')
    return data


def lookup(catalog_id):
    root = os.environ.get('FINDEZ_CAD_MODEL_LIBRARY')
    if not root:
        return None
    if not Path(root).is_dir():
        raise HTTPException(503, 'The configured catalog directory is unavailable.')
    folder = Path(root) / str(UUID(str(catalog_id)))
    try:
        raw = read_bounded(folder / 'manifest.json', 32768)
    except FileNotFoundError:
        return None
    except (OSError, ValueError):
        raise HTTPException(503, 'The catalog manifest is unavailable.') from None
    try:
        record = Record.model_validate_json(raw)
    except ValidationError:
        raise HTTPException(503, 'This catalog model needs publisher review.') from None
    if str(record.catalog_id) != str(catalog_id):
        raise HTTPException(503, 'This catalog model needs publisher review.')
    rows = (get_supabase_raw().table('parts_catalog').select('brand,part_number,specifications')
            .eq('verification_status', 'verified').eq('catalog_id', str(catalog_id)).limit(1).execute().data)
    if not rows:
        return None
    row = rows[0]
    if (record.manufacturer != row.get('brand') or record.part_number != row.get('part_number')
            or record.specifications != {k:str(v) for k,v in (row.get('specifications') or {}).items()}):
        return None
    return folder, record, hashlib.sha256(raw).hexdigest()


def verified_asset(folder, digest, extension, limit):
    try:
        data = read_bounded(folder / (digest + extension), limit)
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError()
        return data
    except (OSError, ValueError):
        raise HTTPException(503, 'The catalog asset failed its integrity check.') from None


def preview(catalog_id):
    entry = lookup(catalog_id)
    if entry is None:
        return {'model': None}
    folder, record, revision_id = entry
    data = verified_asset(folder, record.preview_sha256, '.png', 512 * 1024)
    try:
        with Image.open(io.BytesIO(data), formats=['PNG']) as image:
            if max(image.size) > 1024 or getattr(image, 'n_frames', 1) != 1:
                raise ValueError()
            # Serve only decoded pixels, stripping embedded metadata and extra bytes.
            pixels = image.convert('RGB')
            pixels.thumbnail((480, 480))
            encoded = io.BytesIO()
            pixels.save(encoded, format='PNG')
    except (ValueError, OSError, Image.DecompressionBombError):
        raise HTTPException(503, 'The catalog preview needs publisher review.') from None
    return {'model': {**record.model_dump(mode='json', exclude={'redistribution_evidence','redistribution_approved','reviewed_by','preview_sha256'}),
                      'revision_id':revision_id, 'preview_png': base64.b64encode(encoded.getvalue()).decode('ascii')}}


def download(catalog_id, revision_id, digest):
    entry = lookup(catalog_id)
    if entry is None or entry[2] != revision_id or entry[1].step_sha256 != digest:
        raise HTTPException(409, 'The selected catalog version changed. Review its preview again.')
    data = verified_asset(entry[0], digest, '.step', 100 * 1024 * 1024)
    if not data.lstrip().startswith(b'ISO-10303-21;') or not data.rstrip().endswith(b'END-ISO-10303-21;'):
        raise HTTPException(503, 'The catalog STEP needs publisher review.')
    return data

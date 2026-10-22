"""Explicit, bounded chat evidence. References are reauthorized on every turn."""
from io import BytesIO
from typing import Annotated, Literal
from uuid import UUID
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field, TypeAdapter
from app.services import world_chat as world
from app.services.supabase_client import get_supabase_admin

MAX_BYTES = 10 * 1024 * 1024
MAX_TEXT = 24000
MAX_TOTAL_TEXT = 48000

class Reference(BaseModel):
    model_config = ConfigDict(extra='forbid')
    kind: Literal['space', 'item', 'project', 'document']
    inventory_id: UUID
    resource_id: UUID

class FileSource(BaseModel):
    model_config = ConfigDict(extra='forbid')
    kind: Literal['file']
    name: str = Field(min_length=1, max_length=200)
    text: str = Field(min_length=1, max_length=MAX_TEXT)
    truncated: bool = False

Source = Annotated[Reference | FileSource, Field(discriminator='kind')]
SourceList = Annotated[list[Source], Field(max_length=8)]
source_adapter = TypeAdapter(SourceList)

# Column allowlists prevent signed URLs, storage paths or unrelated metadata
# from being sent to the model or the context directory.
KINDS = {
    'space': ('spaces', 'space_id', 'user_id', 'name', 'space_id,name'),
    'item': ('items', 'item_id', 'user_id', 'name', 'item_id,name,quantity,category,location,notes'),
    'project': ('project_kits', 'id', 'owner_user_id', 'name', 'id,name,location'),
    'document': ('documents', 'document_id', 'user_id', 'filename', 'document_id,filename,mime_type,size_bytes'),
}

def search(actor, key, inventory_id, kind, query='', offset=0):
    if kind not in KINDS:
        raise HTTPException(422, 'Choose Spaces, items, projects or documents.')
    table, pk, owner, label, columns = KINDS[kind]
    with world.in_inventory(actor, key, inventory_id) as inv:
        q = get_supabase_admin().table(table).select(columns).eq(owner, inv['owner_user_id'])
        if query.strip():
            # SQL wildcard characters are literal user search text.
            term = query.strip().replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
            q = q.ilike(label, '%' + term + '%')
        rows = q.order(label).order(pk).range(offset, offset + 30).execute().data or []
        return {'sources': [{'kind': kind, 'inventory_id': inventory_id,
            'resource_id': str(row[pk]), 'name': row.get(label) or 'Untitled',
            'inventory_name': inv['name']} for row in rows[:30]],
            'next_offset': offset + 30 if len(rows) > 30 else None}

def extract(filename, content):
    name = filename.replace('\\', '/').split('/')[-1][:200]
    if not content or len(content) > MAX_BYTES:
        raise HTTPException(413, 'Choose a nonempty file smaller than 10 MB.')
    ext = name.rsplit('.', 1)[-1].lower()
    truncated = False
    try:
        if ext in ('txt', 'md'):
            text = content.decode('utf-8-sig')
            if '\x00' in text:
                raise ValueError('binary')
            truncated = len(text) > MAX_TEXT
            text = text[:MAX_TEXT]
        elif ext == 'pdf' and content.startswith(b'%PDF-'):
            from pypdf import PdfReader
            reader = PdfReader(BytesIO(content))
            if reader.is_encrypted:
                raise ValueError('encrypted')
            parts, count = [], 0
            pages = len(reader.pages)
            for index in range(min(pages, 50)):
                page = reader.pages[index]
                # Bound expanded page streams before text extraction.
                stream = page.get_contents()
                if stream and len(stream.get_data()) > 5 * 1024 * 1024:
                    raise ValueError('complex page')
                value = page.extract_text() or ''
                remaining = MAX_TEXT - count
                parts.append(value[:remaining])
                count += len(parts[-1]) + 1
                if count >= MAX_TEXT:
                    truncated = len(value) > remaining or index + 1 < pages
                    break
            else:
                truncated = pages > 50
            text = '\n'.join(parts)[:MAX_TEXT]
        else:
            raise HTTPException(422, 'Choose PDF, TXT or Markdown. Use Import inventory for CSV or Excel.')
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(422, 'This file could not be read. Try a text-based PDF, TXT or Markdown file.') from None
    text = text.replace('\x00', ' ').strip()
    if not text:
        raise HTTPException(422, 'No readable text was found. For scanned pages, attach a photo instead.')
    return FileSource(kind='file', name=name or 'Attachment', text=text, truncated=truncated).model_dump()

def resolve(actor, key, sources):
    if len(sources) > 8 or sum(s.kind == 'file' for s in sources) > 4:
        raise HTTPException(422, 'Use up to 8 sources, including up to 4 files.')
    evidence, total = [], 0
    for source in sources:
        if source.kind == 'file':
            value = source.model_dump()
        else:
            table, pk, owner, label, columns = KINDS[source.kind]
            with world.in_inventory(actor, key, str(source.inventory_id)) as inv:
                client = get_supabase_admin()
                selected = columns + (',storage_path' if source.kind == 'document' else '')
                rows = client.table(table).select(selected).eq(owner, inv['owner_user_id']).eq(pk, str(source.resource_id)).limit(1).execute().data or []
                if not rows:
                    raise HTTPException(404, 'A selected source is no longer available. Remove it and try again.')
                row = rows[0]
                value = {'kind': source.kind, 'inventory_id': str(source.inventory_id),
                         'resource_id': str(source.resource_id), 'name': row.get(label) or 'Untitled', 'facts': row}
                if source.kind == 'project':
                    lines = client.table('project_kit_items').select('name,required_quantity,brand,part_number').eq('kit_id', str(source.resource_id)).limit(51).execute().data or []
                    value['requirements'] = lines[:50]
                    value['truncated'] = len(lines) > 50
                if source.kind == 'document':
                    from app.services.storage import document_path_in_scope
                    path = row.pop('storage_path', '')
                    if not document_path_in_scope(path, inv['owner_user_id'] + '/'):
                        raise HTTPException(404, 'This document is unavailable.')
                    if row.get('size_bytes') is None or row['size_bytes'] > MAX_BYTES:
                        raise HTTPException(413, 'Choose a document smaller than 10 MB.')
                    raw = client.storage.from_('documents').download(path)
                    file = extract(row['filename'], raw)
                    value.update(text=file['text'], truncated=file['truncated'])
        total += len(value.get('text', ''))
        if total > MAX_TOTAL_TEXT:
            raise HTTPException(422, 'The selected files are too long together. Remove a file and try again.')
        evidence.append(value)
    return evidence

"""Read-only Onshape v16 adapter. Never follows provider-supplied resource URLs."""
import hashlib
import asyncio
import json
import re
from typing import Literal
from uuid import uuid4

import httpx
from fastapi import HTTPException
from pydantic import Field

from .snapshot import Model, Document, MAX_SNAPSHOT_BYTES
from .tabular import TabularSnapshot, TabularRevision, Line

API = 'https://cad.onshape.com/api/v16'
ID = r'^[a-f0-9]{24}$'


class Assembly(Model):
    document_id: str = Field(pattern=ID)
    element_id: str = Field(pattern=ID)
    wvm: Literal['w', 'v', 'm'] = 'w'
    wvm_id: str = Field(pattern=ID)
    configuration: str = Field(default='', max_length=4096)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


async def request_json(client, method, url, **kwargs):
    try:
        async with asyncio.timeout(30):
            return await _request_json(client, method, url, **kwargs)
    except TimeoutError:
        raise HTTPException(504, 'Onshape took too long to respond. Try again later.') from None


async def _request_json(client, method, url, **kwargs):
    """Bound both wire bytes and duration; redirects cannot leak bearer tokens."""
    try:
        async with client.stream(method, url, **kwargs) as response:
            if response.status_code == 429:
                delay = response.headers.get('retry-after', '60')
                delay = str(min(3600, max(1, int(delay)))) if delay.isdigit() else '60'
                raise HTTPException(429, 'Onshape is limiting requests. Wait before checking again.', headers={'Retry-After': delay})
            if response.status_code in (401, 403):
                raise HTTPException(403, 'Reconnect Onshape and check that you can access this assembly.')
            if response.status_code == 404:
                raise HTTPException(404, 'Onshape could not find this assembly or its BOM.')
            if response.status_code != 200:
                raise HTTPException(502, 'Onshape could not complete the request. Try again later.')
            raw = bytearray()
            async for chunk in response.aiter_bytes(chunk_size=65536):
                raw.extend(chunk)
                if len(raw) > MAX_SNAPSHOT_BYTES:
                    raise HTTPException(413, 'This Onshape response exceeds the 5 MiB limit.')
            data = json.loads(raw)
            if not isinstance(data, dict):
                raise ValueError()
            return data
    except (httpx.HTTPError, ValueError, RecursionError):
        raise HTTPException(502, 'Onshape returned an unreadable response. Try again later.') from None


def scalar(value):
    if isinstance(value, dict) and set(value) == {'value'}:
        value = value['value']
    if value is None:
        return ''
    if type(value) not in (str, int, float) or len(str(value)) > 512:
        raise ValueError('Unsupported BOM property value.')
    return str(value).strip()


def normalize(data, assembly: Assembly, microversion: str):
    """Use flattened totals once, ignoring separate topLevelAssemblyRow metadata."""
    headers, rows = data.get('headers'), data.get('rows')
    if not isinstance(headers, list) or not isinstance(rows, list) or not 1 <= len(rows) <= 5000:
        raise ValueError('Onshape must return 1 to 5,000 BOM rows.')
    columns = {}
    aliases = {'name': 'name', 'quantity': 'quantity', 'partnumber': 'part_number', 'manufacturer': 'manufacturer'}
    for header in headers:
        # propertyName is the stable semantic name; never infer from Description/Material.
        label = re.sub(r'[^a-z0-9]', '', str(header.get('propertyName') or header.get('name') or '').lower())
        field = aliases.get(label)
        if field:
            if field in columns:
                raise ValueError('The Onshape BOM contains ambiguous property columns.')
            columns[field] = header['id']
    if not {'name', 'quantity'} <= columns.keys():
        raise ValueError('The Onshape BOM needs Name and Quantity columns. Use CSV mapping for custom column names.')
    lines, seen = [], set()
    for row in rows:
        if row.get('indentLevel', 0) not in (0, 1):
            raise ValueError('Expected flattened BOM totals, not nested assembly rows.')
        values = row.get('headerIdToValue', {})
        fields = {k: scalar(values.get(v)) for k, v in columns.items()}
        if not fields['name'] or not re.fullmatch(r'[0-9]+(?:\.0+)?', fields['quantity']):
            raise ValueError('Every BOM row needs a name and a positive whole-unit quantity.')
        quantity = int(fields['quantity'].split('.')[0])
        source = row.get('itemSource') or {}
        identity = {k: source.get(k, '') for k in ('documentId', 'elementId', 'partId', 'nonGeometricItemId', 'configuration', 'fullConfiguration')}
        if not (identity['partId'] or identity['nonGeometricItemId']):
            # A purchased subassembly can legitimately be a single BOM requirement.
            identity['rowId'] = row.get('rowId', '')
        key = digest(identity)
        if key in seen or not any(identity.values()):
            raise ValueError('BOM source identities are missing or duplicated. Review the export in Onshape.')
        seen.add(key)
        lines.append(Line(key=key, name=fields['name'], required=quantity,
                          part_number=fields.get('part_number', ''), manufacturer=fields.get('manufacturer', ''),
                          part_number_is_default=not bool(fields.get('part_number')), procurement_policy='purchase',
                          source_document=assembly.document_id, source_token=json.dumps(identity, sort_keys=True),
                          configuration=digest(assembly.configuration)))
    return TabularSnapshot(provider='onshape', extraction_id=str(uuid4()),
        document=Document(external_id=assembly.document_id, name=scalar(data.get('name')) or 'Onshape assembly'),
        revision=TabularRevision(kind='onshape_microversion', id=microversion, configuration=assembly.configuration[:512]),
        completeness='partial', lines=lines,
        warnings=['Onshape flattened BOM totals respect its subassembly BOM settings and exclusions. Verify purchased versus fabricated parts before ordering.'])


async def extract(assembly: Assembly, token: str):
    async with httpx.AsyncClient(timeout=30, follow_redirects=False, headers={'Authorization': f'Bearer {token}'}) as client:
        mid = assembly.wvm_id
        if assembly.wvm != 'm':
            revision = await request_json(client, 'GET', f'{API}/documents/d/{assembly.document_id}/{assembly.wvm}/{assembly.wvm_id}/currentmicroversion')
            mid = revision.get('id', '')
        if not re.fullmatch(ID, mid):
            raise HTTPException(502, 'Onshape did not identify the assembly revision.')
        data = await request_json(client, 'GET', f'{API}/assemblies/d/{assembly.document_id}/m/{mid}/e/{assembly.element_id}/bom',
            params={'configuration': assembly.configuration, 'indented': 'false', 'generateIfAbsent': 'true',
                    'includeExcluded': 'false', 'onlyVisibleColumns': 'false', 'includeTopLevelAssemblyRow': 'false',
                    'includeItemMicroversions': 'true', 'respectSubassemblyBomBehavior': 'true', 'thumbnail': 'false'})
    try:
        return normalize(data, assembly, mid)
    except (ValueError, KeyError, TypeError, AttributeError):
        raise HTTPException(422, 'This BOM could not be safely counted. Check Name, Quantity and flattened BOM settings, or use CSV column mapping.') from None

"""Authenticated, reviewed imports. Provider adapters share one write boundary."""
import hashlib
import logging
from datetime import datetime, timezone, timedelta
from typing import Literal
from uuid import UUID, NAMESPACE_URL, uuid5

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import Response
from starlette.concurrency import run_in_threadpool
from pydantic import BaseModel, ConfigDict, Field, StrictInt
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.core.config import get_settings
from app.services.usage_service import FREE_LIMITS, PRO_LIMITS, resolve_effective_plan
from app.services.limits import TEAM_PLAN_LIMITS
from app.api.routes.imports import _resolve_import_target
from app.services.connector_tables import FIELDS, parse_source, review_table, match_bom, shortage_csv, safe_filename
from app.services.inventory_scope import current_inventory
from app.services.items_repo import list_items, invalidate_inventory_cache
from app.services.supabase_client import get_supabase_raw, get_supabase_admin
from app.services.spreadsheet_import import MAX_IMPORT_BYTES
from app.services.limits import check_item_limit
from app.services.project_kits_service import _list_reservations

router = APIRouter(tags=['connectors'])
logger = logging.getLogger(__name__)


class MappingRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    revision: int = Field(ge=0)
    sheet: int = Field(ge=0, le=19)
    columns: dict[str, StrictInt]
    category: str = Field(default='Supplies', min_length=1, max_length=100)
    quantity: int = Field(default=1, ge=0, le=100000)


class CommitRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    revision: int = Field(ge=0)
    decisions: dict[str, Literal['create', 'skip', 'create_duplicate']] = Field(max_length=5000)
    retry_failed: bool = False


def _import_quota(actor):
    # Limits come from the server's existing plan model, never from the client.
    if get_settings().pilot_mode:
        return {}
    plan, team = resolve_effective_plan(actor)
    if team:
        return {'team_id': team, 'limit': TEAM_PLAN_LIMITS['imports_per_period']}
    limits = PRO_LIMITS if plan in ('pro', 'team_member') else FREE_LIMITS
    return {'limit': limits['spreadsheet_import']}


def _session(session_id, actor, *, include_tables=False):
    rows = get_supabase_raw().table('connector_import_sessions').select('*' if include_tables else 'id,actor_id,owner_id,inventory_id,share_id,location,filename,kind,review,mapping,decisions,receipts,revision,status,expires_at').eq('id', str(session_id)).eq('actor_id', actor).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, 'Import not found.')
    s = rows[0]
    scope = current_inventory.get()
    if scope and scope.inventory_id != s['inventory_id']:
        raise HTTPException(404, 'Import not found in this inventory.')
    authorized = get_supabase_raw().rpc('findez_connector_authorized', {'p_session': s['id'], 'p_actor': actor}).execute().data
    if authorized is not True:
        raise HTTPException(403, 'You no longer have access to this import destination.')
    return s


def _locations(s):
    query = get_supabase_admin().table('spaces').select('id,name,inventory_id').eq('inventory_id', s['inventory_id'])
    if s.get('share_id'):
        query = query.eq('name', s['location'])
    return query.order('id').limit(1000).execute().data or []


def _inventory(s):
    invalidate_inventory_cache(s['owner_id'])
    return [i for i in list_items(user_id=s['owner_id']) if i.get('inventory_id') == s['inventory_id']
            and (not s.get('share_id') or i.get('location') == s['location'])]


def _public(s, *, include_tables=False, include_rows=True):
    receipts = s.get('receipts') or {}
    counts = {status: sum(r.get('status') == status for r in receipts.values()) for status in ('imported', 'skipped', 'failed')}
    rows = s.get('review') or []
    result = {k: s.get(k) for k in ('id', 'filename', 'kind', 'location', 'revision', 'status', 'mapping', 'decisions')}
    if include_rows:
        result['rows'] = rows
    result.update(receipts=receipts, counts={**counts, 'total': len(rows),
                  'pending': len(rows)-len(receipts), 'duplicates': sum(bool(r['duplicates'] or r['duplicate_rows']) for r in rows)})
    if include_tables:
        result['sheets'] = [{ 'name': t['name'], 'headers': t['headers'], 'row_count': len(t['rows']),
                            'sample': t['rows'][:5], 'suggested_mapping': t['suggested_mapping'], 'warnings': t['warnings']}
                           for t in s['tables']]
        result['fields'] = list(FIELDS) + (['exclude'] if s['kind'] == 'bom' else [])
    return result


@router.get('/connectors')
def connector_status(user: AuthenticatedUser = Depends(get_current_user)):
    return {'connectors': [
        {'id': 'spreadsheet', 'name': 'CSV & Excel', 'status': 'available', 'action': 'upload'},
        {'id': 'bom', 'name': 'KiCad / Fusion BOM', 'status': 'available', 'action': 'upload'},
    ]}


@router.post('/connectors/imports')
@limiter.limit('5/minute')
async def upload_source(request: Request, file: UploadFile = File(...), location: str = Form(...),
                        kind: Literal['inventory', 'bom'] = Form('inventory'), share_id: str | None = Form(None),
                        user: AuthenticatedUser = Depends(get_current_user)):
    owner, location = _resolve_import_target(requesting_user_id=user.user_id, location=location, share_id=share_id)
    scope = current_inventory.get()
    if scope:
        if not scope.can_edit:
            raise HTTPException(403, 'You have view-only access to this inventory.')
        owner = scope.owner_id
    places = get_supabase_admin().table('spaces').select('id,name,inventory_id,user_id').eq('user_id', owner).eq('name', location).limit(2).execute().data or []
    if len(places) != 1 or not places[0].get('inventory_id'):
        raise HTTPException(422, 'Select an existing Space in a single inventory before importing.')
    inv = places[0]['inventory_id']
    raw = await file.read(MAX_IMPORT_BYTES + 1)
    filename = safe_filename(file.filename or '')
    try:
        tables = await run_in_threadpool(parse_source, raw, filename, file.content_type)
    except ValueError as exc:
        raise HTTPException(413 if len(raw) > MAX_IMPORT_BYTES else 422, str(exc)) from exc
    digest = hashlib.sha256(raw).hexdigest()
    identity = f'findez:import:{user.user_id}:{inv}:{location}:{share_id}:{kind}:{digest}'
    session_id = str(uuid5(NAMESPACE_URL, identity))
    client = get_supabase_raw()
    existing = client.table('connector_import_sessions').select('id,decisions,expires_at,revision').eq('id', session_id).eq('actor_id', user.user_id).execute().data
    if existing and existing[0]['decisions'] is None and datetime.fromisoformat(existing[0]['expires_at'].replace('Z', '+00:00')) < datetime.now(timezone.utc):
        # A new upload renews only an uncommitted draft. Old previews become stale.
        client.table('connector_import_sessions').update({
            'review': [], 'mapping': {}, 'status': 'draft', 'revision': existing[0]['revision'] + 1,
            'expires_at': (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
        }).eq('id', session_id).eq('actor_id', user.user_id).eq('revision', existing[0]['revision']).is_('decisions', 'null').execute()
    if not existing:
        payload = {'id': session_id, 'actor_id': user.user_id, 'owner_id': owner, 'inventory_id': inv,
                   'share_id': share_id, 'location': location, 'filename': filename, 'source_hash': digest, 'kind': kind, 'tables': tables}
        try:
            client.table('connector_import_sessions').insert(payload).execute()
        except Exception:
            # Reconcile a duplicate/lost response; never replace an existing session.
            if not client.table('connector_import_sessions').select('id').eq('id', session_id).eq('actor_id', user.user_id).execute().data:
                raise HTTPException(503, 'The file could not be retained. Please retry.')
    return _public(_session(session_id, user.user_id, include_tables=True), include_tables=True)


@router.get('/connectors/imports/{session_id}')
def get_import(session_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return _public(_session(session_id, user.user_id, include_tables=True), include_tables=True)


@router.post('/connectors/imports/{session_id}/preview')
def preview_import(session_id: UUID, payload: MappingRequest, user: AuthenticatedUser = Depends(get_current_user)):
    s = _session(session_id, user.user_id, include_tables=True)
    if s['decisions'] is not None or s['revision'] != payload.revision:
        raise HTTPException(409, 'This import has changed or already started. Reload its results.')
    if datetime.fromisoformat(s['expires_at'].replace('Z', '+00:00')) < datetime.now(timezone.utc):
        raise HTTPException(410, 'This preview expired. Upload the source file again to review it.')
    if payload.sheet >= len(s['tables']):
        raise HTTPException(422, 'Choose an existing worksheet.')
    try:
        rows = review_table(s['tables'][payload.sheet], filename=s['filename'], columns=payload.columns,
                            defaults={'category': payload.category, 'quantity': payload.quantity, 'location': s['location']},
                            inventory=_inventory(s), locations=_locations(s), bom=s['kind']=='bom')
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc
    updated = get_supabase_raw().table('connector_import_sessions').update({
        'mapping': payload.model_dump(), 'review': rows, 'revision': s['revision']+1, 'status': 'review',
    }).eq('id', s['id']).eq('actor_id', user.user_id).eq('revision', payload.revision).is_('decisions', 'null').execute().data
    if not updated:
        raise HTTPException(409, 'This import changed. Reload before reviewing again.')
    return _public(updated[0], include_tables=True)


@router.post('/connectors/imports/{session_id}/commit')
@limiter.limit('30/minute')
def commit_import(request: Request, session_id: UUID, payload: CommitRequest, user: AuthenticatedUser = Depends(get_current_user)):
    s = _session(session_id, user.user_id)
    if s['kind'] != 'inventory':
        raise HTTPException(422, 'BOM analysis does not create inventory.')
    if s['revision'] != payload.revision or s['status'] == 'draft':
        raise HTTPException(409, 'Review the latest preview before importing.')
    if s['decisions'] is not None and s['decisions'] != payload.decisions:
        raise HTTPException(409, 'This import already started with different choices.')
    expected = {str(r['index']) for r in s['review']}
    if set(payload.decisions) != expected:
        raise HTTPException(422, 'Choose an action for every row.')
    for r in s['review']:
        choice = payload.decisions[str(r['index'])]
        if choice != 'skip' and r['errors']:
            raise HTTPException(422, 'Exclude invalid rows before importing.')
        if choice == 'create' and (r['duplicates'] or r['duplicate_rows']):
            raise HTTPException(422, 'Review duplicate rows before importing.')
    limit = check_item_limit(s['owner_id'])['limit']
    try:
        receipt = get_supabase_raw().rpc('findez_commit_connector_import', {
            'p_actor': user.user_id, 'p_session': s['id'], 'p_revision': payload.revision,
            'p_decisions': payload.decisions, 'p_item_limit': limit, 'p_retry_failed': payload.retry_failed,
            'p_quota': _import_quota(user.user_id),
        }).execute().data
        if not isinstance(receipt, dict) or receipt.get('id') != s['id'] or receipt.get('status') not in ('complete', 'importing'):
            raise ValueError('Unverified receipt')
    except Exception as exc:
        if getattr(exc, 'message', '') == 'CONNECTOR_IMPORT_LIMIT':
            raise HTTPException(403, 'Your monthly import allowance has been used. No rows were saved by this request.') from exc
        # Return no invented success when the network loses a response. The same
        # session can be fetched/retried; receipts and writes commit together.
        logger.warning('connector_commit_unconfirmed session=%s', s['id'])
        raise HTTPException(503, 'The result could not be confirmed. Retry this import safely.')
    invalidate_inventory_cache(s['owner_id'])
    return _public({**s, **receipt, 'decisions': payload.decisions}, include_rows=False)


@router.get('/connectors/imports/{session_id}/bom')
def analyze_import(session_id: UUID, export: bool = False, user: AuthenticatedUser = Depends(get_current_user)):
    s = _session(session_id, user.user_id)
    if s['kind'] != 'bom' or not s['review']:
        raise HTTPException(422, 'Map and review a BOM first.')
    rows = match_bom(s['review'], _inventory(s), _list_reservations())
    if export and any(r['errors'] for r in s['review']):
        raise HTTPException(422, 'Correct invalid BOM rows before exporting a complete purchasing list.')
    if export:
        return Response(shortage_csv(rows), media_type='text/csv', headers={'Content-Disposition': 'attachment; filename="findez-shortages.csv"'})
    return {'items': rows, 'purchasing_csv': shortage_csv(rows), 'invalid_rows': sum(bool(r['errors']) for r in s['review']),
            'excluded_rows': sum(bool(r.get('excluded')) for r in s['review'])}

"""Inventory-authorized comparison and explicit shared BOM history."""

import json
from uuid import UUID
from typing import Literal

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, Query
from pydantic import ValidationError, Field
from starlette.concurrency import run_in_threadpool

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.cad.snapshot import MAX_SNAPSHOT_BYTES, Snapshot, Model
from app.services.cad.comparison import compare
from app.services.cad.repository import read_inventory, authorize_inventory
from app.services.cad import tabular
from app.services.cad import corrections

router = APIRouter(tags=['cad'])


def reject_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key.')
        result[key] = value
    return result


def analyze(raw, inventory_id, actor_id, filename="bom.json", sheet="", mapping="", flat_bom_confirmed=False):
    try:
        if filename.lower().endswith(('.csv', '.xlsx')):
            snapshot = tabular.snapshot(raw, filename, sheet, json.loads(mapping or '{}', object_pairs_hook=reject_duplicates), flat_bom_confirmed)
        elif filename.lower().endswith('.json'):
            data = json.loads(raw, object_pairs_hook=reject_duplicates)
            snapshot = Snapshot.model_validate(data)
        else:
            raise ValueError('Choose a Fusion JSON, CSV or Excel (.xlsx) BOM.')
    except ValidationError:
        raise HTTPException(422, 'Check the BOM format and map the required name and quantity columns.') from None
    except (ValueError, RecursionError) as exc:
        message = str(exc) if filename.lower().endswith(('.csv', '.xlsx')) and not isinstance(exc, json.JSONDecodeError) else 'Choose a valid Fusion JSON, CSV or Excel (.xlsx) BOM.'
        raise HTTPException(422, message) from None
    items, reservations, checkouts = read_inventory(inventory_id, actor_id)
    try:
        result = compare(snapshot, items, reservations, checkouts, corrections.load(snapshot, inventory_id, actor_id))
    except ValueError:
        raise HTTPException(409, 'Inventory changed while comparing. Try again.') from None
    authorize_inventory(inventory_id, actor_id)
    return corrections.annotate({'inventory_id': inventory_id, **result}, snapshot, inventory_id, actor_id)


@router.post('/inventories/{inventory_id}/cad/compare')
@limiter.limit('5/minute')
async def compare_snapshot(request: Request, inventory_id: UUID, file: UploadFile = File(...),
                           sheet: str = Form("", max_length=512), mapping: str = Form("", max_length=2000),
                           flat_bom_confirmed: bool = Form(False),
                           user: AuthenticatedUser = Depends(get_current_user)):
    raw = await file.read(MAX_SNAPSHOT_BYTES + 1)
    if len(raw) > MAX_SNAPSHOT_BYTES:
        raise HTTPException(413, 'Choose a FindEZ BOM export smaller than 5 MiB.')
    return await run_in_threadpool(analyze, raw, str(inventory_id), user.actor_id or user.user_id, file.filename or "", sheet, mapping, flat_bom_confirmed)


def preview_table(raw, name, inventory_id, actor_id):
    authorize_inventory(inventory_id, actor_id)
    try:
        result = tabular.preview(raw, name)
    except (ValueError, RecursionError) as exc:
        raise HTTPException(422, str(exc)) from None
    authorize_inventory(inventory_id, actor_id)
    return {'inventory_id': inventory_id, **result}


@router.post('/inventories/{inventory_id}/cad/preview')
@limiter.limit('10/minute')
async def preview_spreadsheet(request: Request, inventory_id: UUID, file: UploadFile = File(...),
                              user: AuthenticatedUser = Depends(get_current_user)):
    raw = await file.read(MAX_SNAPSHOT_BYTES + 1)
    if len(raw) > MAX_SNAPSHOT_BYTES:
        raise HTTPException(413, 'Choose a BOM smaller than 5 MiB.')
    return await run_in_threadpool(preview_table, raw, file.filename or '', str(inventory_id), user.actor_id or user.user_id)


class Correction(Model):
    review_token: str = Field(min_length=20, max_length=4096)
    decision: Literal['match', 'no_match', 'reset']
    item_id: UUID | None = None


def actor(user):
    return user.actor_id or user.user_id


@router.post('/inventories/{inventory_id}/cad/corrections')
@limiter.limit('30/minute')
async def correct(request: Request, inventory_id: UUID, body: Correction, user: AuthenticatedUser = Depends(get_current_user)):
    return await run_in_threadpool(corrections.save, str(inventory_id), actor(user), body.review_token,
        body.decision, str(body.item_id) if body.item_id else None)


@router.get('/inventories/{inventory_id}/cad/candidates')
@limiter.limit('30/minute')
async def candidates(request: Request, inventory_id: UUID, q: str = Query(min_length=2, max_length=100), user: AuthenticatedUser = Depends(get_current_user)):
    items, _, _ = await run_in_threadpool(read_inventory, str(inventory_id), actor(user))
    needle = q.strip().casefold()
    matches = [i for i in items if needle in str(i.get('name') or '').casefold() or needle in str(i.get('part_number') or '').casefold()]
    return {'inventory_id': str(inventory_id), 'items': [{k: i.get(k) for k in ('item_id','name','part_number','location')} for i in matches[:50]], 'has_more': len(matches)>50}


class SaveVersion(Model):
    request_id: UUID
    snapshot: Snapshot


async def read_version(request):
    raw = bytearray()
    async for chunk in request.stream():
        if len(raw) + len(chunk) > MAX_SNAPSHOT_BYTES:
            raise HTTPException(413, 'Choose a BOM smaller than 5 MiB.')
        raw.extend(chunk)
    try:
        return SaveVersion.model_validate(json.loads(raw, object_pairs_hook=reject_duplicates))
    except (ValidationError, ValueError, RecursionError):
        raise HTTPException(422, 'The BOM version could not be read. Compare the design again.') from None


@router.get('/inventories/{inventory_id}/cad/versions')
def versions(inventory_id: UUID, offset: int=Query(0,ge=0,le=10000), user: AuthenticatedUser=Depends(get_current_user)):
    from app.services.cad import projects
    return projects.versions(str(inventory_id), actor(user), offset)


@router.get('/inventories/{inventory_id}/cad/versions/{version_id}')
def version(inventory_id: UUID, version_id: UUID, user: AuthenticatedUser=Depends(get_current_user)):
    from app.services.cad import projects
    return projects.version(str(inventory_id), actor(user), version_id)


@router.post('/inventories/{inventory_id}/cad/versions')
@limiter.limit('10/minute')
async def save_version(request: Request, inventory_id: UUID, user: AuthenticatedUser=Depends(get_current_user)):
    from app.services.cad import projects
    data = await read_version(request)
    return await run_in_threadpool(projects.save, data.snapshot, str(inventory_id), actor(user), data.request_id)

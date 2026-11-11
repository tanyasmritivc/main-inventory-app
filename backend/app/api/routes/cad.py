"""Stateless prototype: authorized BOM comparison without storing design data."""

import json
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from pydantic import ValidationError
from starlette.concurrency import run_in_threadpool

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.cad.snapshot import MAX_SNAPSHOT_BYTES, Snapshot
from app.services.cad.comparison import compare
from app.services.cad.repository import read_inventory, authorize_inventory
from app.services.cad import tabular

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
        result = compare(snapshot, items, reservations, checkouts)
    except ValueError:
        raise HTTPException(409, 'Inventory changed while comparing. Try again.') from None
    return {'inventory_id': inventory_id, **result}


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

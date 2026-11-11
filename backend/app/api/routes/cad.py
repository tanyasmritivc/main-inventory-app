"""Stateless prototype: authorized BOM comparison without storing design data."""

import json
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from pydantic import ValidationError
from starlette.concurrency import run_in_threadpool

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.cad.snapshot import MAX_SNAPSHOT_BYTES, Snapshot
from app.services.cad.comparison import compare
from app.services.cad.repository import read_inventory

router = APIRouter(tags=['cad'])


def reject_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key.')
        result[key] = value
    return result


def analyze(raw, inventory_id, actor_id):
    try:
        data = json.loads(raw, object_pairs_hook=reject_duplicates)
        snapshot = Snapshot.model_validate(data)
    except (ValueError, ValidationError, RecursionError):
        raise HTTPException(422, 'Choose a valid FindEZ Fusion BOM export. Re-export the assembly if needed.') from None
    items, reservations, checkouts = read_inventory(inventory_id, actor_id)
    try:
        result = compare(snapshot, items, reservations, checkouts)
    except ValueError:
        raise HTTPException(409, 'Inventory changed while comparing. Try again.') from None
    return {'inventory_id': inventory_id, **result}


@router.post('/inventories/{inventory_id}/cad/compare')
@limiter.limit('5/minute')
async def compare_snapshot(request: Request, inventory_id: UUID, file: UploadFile = File(...),
                           user: AuthenticatedUser = Depends(get_current_user)):
    raw = await file.read(MAX_SNAPSHOT_BYTES + 1)
    if len(raw) > MAX_SNAPSHOT_BYTES:
        raise HTTPException(413, 'Choose a FindEZ BOM export smaller than 5 MiB.')
    return await run_in_threadpool(analyze, raw, str(inventory_id), user.actor_id or user.user_id)

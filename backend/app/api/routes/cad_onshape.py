"""OAuth is actor-scoped; assembly comparisons and corrections are inventory-scoped."""
from typing import Literal
from uuid import UUID
from fastapi import APIRouter, Depends, Request, Query
from pydantic import Field
from starlette.concurrency import run_in_threadpool

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.cad.snapshot import Model
from app.services.cad import connections, corrections, onshape
from app.services.cad.comparison import compare
from app.services.cad.repository import authorize_inventory, read_inventory

router = APIRouter(tags=['cad'])


def actor(user):
    return user.actor_id or user.user_id


class Callback(Model):
    code: str = Field(min_length=1, max_length=4096)
    state: str = Field(min_length=32, max_length=256)


class Correction(Model):
    review_token: str = Field(min_length=20, max_length=4096)
    decision: Literal['match', 'no_match', 'reset']
    item_id: UUID | None = None


@router.get('/onshape/connection')
def connection(user: AuthenticatedUser = Depends(get_current_user)):
    return connections.status(actor(user))


@router.post('/onshape/connect')
@limiter.limit('5/minute')
async def connect(request: Request, user: AuthenticatedUser = Depends(get_current_user)):
    return await run_in_threadpool(connections.start, actor(user))


@router.post('/onshape/callback')
@limiter.limit('5/minute')
async def callback(request: Request, body: Callback, user: AuthenticatedUser = Depends(get_current_user)):
    return await connections.complete(actor(user), body.code, body.state)


@router.delete('/onshape/connection')
def disconnect(user: AuthenticatedUser = Depends(get_current_user)):
    return connections.disconnect(actor(user))


def analyze(snapshot, inventory, user_id):
    items, reserved, checked_out = read_inventory(inventory, user_id)
    result = compare(snapshot, items, reserved, checked_out, corrections.load(snapshot, inventory, user_id))
    authorize_inventory(inventory, user_id)
    return corrections.annotate({'inventory_id': inventory, **result}, snapshot, inventory, user_id)


@router.post('/inventories/{inventory_id}/cad/onshape/compare')
@limiter.limit('5/minute')
async def check(request: Request, inventory_id: UUID, body: onshape.Assembly, user: AuthenticatedUser = Depends(get_current_user)):
    inventory, user_id = str(inventory_id), actor(user)
    await run_in_threadpool(authorize_inventory, inventory, user_id)
    token, generation = await connections.access_token(user_id)
    snapshot = await onshape.extract(body, token)
    await run_in_threadpool(connections.assert_connected, user_id, generation)
    return await run_in_threadpool(analyze, snapshot, inventory, user_id)


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

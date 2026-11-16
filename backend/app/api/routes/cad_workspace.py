"""Fusion-only read capability; normal application JWTs approve/revoke pairing."""
import json
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, Query, Response
from pydantic import Field, ValidationError
from starlette.concurrency import run_in_threadpool
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.cad import workspace
from app.services.cad.snapshot import Model, Snapshot, MAX_SNAPSHOT_BYTES
from app.services.cad.repository import read_inventory
from app.api.routes.cad import reject_duplicates
from app.services.cad.comparison import compare
from app.services.supabase_client import get_supabase_raw

router = APIRouter(prefix='/fusion', tags=['cad-workspace'])

class Approval(Model):
    code: str = Field(pattern=r'^[A-HJ-NP-Z2-9]{10}$')
    inventory_id: UUID

class Poll(Model):
    device_code: str = Field(pattern=r'^[A-Za-z0-9_-]{64}$')


def session(request: Request):
    scheme, _, token = request.headers.get('authorization','').partition(' ')
    return workspace.authorize(token if scheme.lower()=='bearer' else '')

@router.post('/pairing')
@limiter.limit('5/minute')
def start(request: Request, response: Response):
    response.headers["Cache-Control"] = "no-store"
    return workspace.start()

@router.post('/pairing/approve')
@limiter.limit('10/minute')
def approve(request: Request, data: Approval, user: AuthenticatedUser = Depends(get_current_user)):
    return workspace.approve(data.code,str(data.inventory_id),user.actor_id or user.user_id)

@router.post('/pairing/poll')
@limiter.limit('20/minute')
def poll(request: Request, data: Poll, response: Response):
    response.headers["Cache-Control"] = "no-store"
    return workspace.exchange(data.device_code)

@router.get('/session')
def info(grant=Depends(session)):
    return {k:grant[k] for k in ('inventory_id','inventory_name','workspace_name','session_expires_at')}

@router.delete('/session')
def disconnect(grant=Depends(session)):
    return workspace.revoke(grant)

@router.get('/connections')
def connections(user: AuthenticatedUser = Depends(get_current_user)):
    return {'connections':get_supabase_raw().table('cad_device_grants').select(
        'id,inventory_id,approved_at,session_expires_at').eq('actor_id',user.actor_id or user.user_id)
        .is_('revoked_at','null').gt('session_expires_at',datetime.now(timezone.utc).isoformat()).execute().data or []}

@router.delete('/connections/{connection_id}')
def revoke(connection_id: UUID,user: AuthenticatedUser = Depends(get_current_user)):
    get_supabase_raw().table('cad_device_grants').update({'revoked_at':datetime.now(timezone.utc).isoformat()}).eq(
        'id',str(connection_id)).eq('actor_id',user.actor_id or user.user_id).execute()
    return {'disconnected':True}

@router.get('/inventory')
@limiter.limit('30/minute')
def inventory(request: Request, q: str=Query('',max_length=100),offset:int=Query(0,ge=0,le=50000),
              location:str|None=Query(None,max_length=512),grant=Depends(session)):
    return workspace.browse(grant,q,offset,location)

@router.get('/catalog')
@limiter.limit('30/minute')
def catalog(request: Request,q:str=Query('',max_length=100),offset:int=Query(0,ge=0,le=50000),grant=Depends(session)):
    result=workspace.catalog(q,offset)
    workspace._inventory(grant['inventory_id'],grant['actor_id'])
    return result

@router.post('/compare')
@limiter.limit('5/minute')
async def comparison(request:Request,grant=Depends(session)):
    raw=bytearray()
    async for chunk in request.stream():
        raw.extend(chunk)
        if len(raw)>MAX_SNAPSHOT_BYTES:
            raise HTTPException(413,'Choose a BOM smaller than 5 MiB.')
    try:
        snapshot=Snapshot.model_validate(json.loads(raw, object_pairs_hook=reject_duplicates))
    except (ValidationError,ValueError,RecursionError):
        raise HTTPException(422,'The Fusion BOM could not be read. Export again.') from None
    def run():
        items,reservations,checkouts=read_inventory(grant['inventory_id'],grant['actor_id'])
        try:
            result=compare(snapshot,items,reservations,checkouts)
        except ValueError:
            raise HTTPException(409,'Inventory changed during comparison. Try again.') from None
        return {'inventory_id':grant['inventory_id'],**result}
    return await run_in_threadpool(run)

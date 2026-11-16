"""Scoped Fusion capability; application JWTs approve optional CAD writes."""
import json
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, Query, Response
from pydantic import Field, ValidationError, StrictBool
from starlette.concurrency import run_in_threadpool
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.cad import workspace, projects, generation, corrections, rexcad
from app.services.cad.search import SearchRequest, search as search_parts
from app.services.cad.snapshot import Model, Snapshot, MAX_SNAPSHOT_BYTES
from app.services.cad.repository import read_inventory
from app.api.routes.cad import reject_duplicates, read_version
from app.services.cad.comparison import compare
from app.services.supabase_client import get_supabase_raw
from typing import Literal

router = APIRouter(prefix='/fusion', tags=['cad-workspace'])

class Approval(Model):
    code: str = Field(pattern=r'^[A-HJ-NP-Z2-9]{10}$')
    inventory_id: UUID
    allow_cad_writes: StrictBool = False

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
    return workspace.approve(data.code,str(data.inventory_id),user.actor_id or user.user_id,data.allow_cad_writes)

@router.post('/pairing/poll')
@limiter.limit('20/minute')
def poll(request: Request, data: Poll, response: Response):
    response.headers["Cache-Control"] = "no-store"
    return workspace.exchange(data.device_code)

@router.get('/session')
def info(grant=Depends(session)):
    return {**{k:grant[k] for k in ('inventory_id','inventory_name','workspace_name','session_expires_at')},
            'allow_cad_writes': bool(grant.get('allow_cad_writes')), 'saved_bom_enabled': projects.enabled(),
            'generation_enabled': projects.enabled() and rexcad.configured()}

@router.delete('/session')
def disconnect(grant=Depends(session)):
    return workspace.revoke(grant)

@router.get('/connections')
def connections(user: AuthenticatedUser = Depends(get_current_user)):
    return {'cad_writes_enabled':projects.enabled(), 'connections':get_supabase_raw().table('cad_device_grants').select(
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

@router.post('/search')
@limiter.limit('10/minute')
def search(request: Request, data: SearchRequest, grant=Depends(session)):
    result = search_parts(grant, data)
    session(request)  # A revoked or expired capability cannot publish an AI result.
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
            result=compare(snapshot,items,reservations,checkouts,
                           corrections.load(snapshot,grant['inventory_id'],grant['actor_id']) if projects.enabled() else {})
        except ValueError:
            raise HTTPException(409,'Inventory changed during comparison. Try again.') from None
        session(request)
        result = {'inventory_id':grant['inventory_id'],**result}
        return corrections.annotate(result,snapshot,grant['inventory_id'],grant['actor_id']) if projects.enabled() and grant.get('allow_cad_writes') else result
    return await run_in_threadpool(run)


class Review(Model):
    review_token: str = Field(min_length=20, max_length=4096)
    decision: Literal['match', 'no_match', 'reset']
    item_id: UUID | None = None


@router.post('/bom/corrections')
@limiter.limit('30/minute')
def save_review(request: Request, data: Review, grant=Depends(session)):
    projects.writable(grant['inventory_id'], grant['actor_id'], grant['id'])
    return corrections.save(grant['inventory_id'], grant['actor_id'], data.review_token,
        data.decision, str(data.item_id) if data.item_id else None, grant['id'])


@router.post('/bom/versions')
@limiter.limit('10/minute')
async def save_version(request: Request, grant=Depends(session)):
    data = await read_version(request)
    return await run_in_threadpool(projects.save, data.snapshot, grant['inventory_id'], grant['actor_id'], data.request_id, grant['id'])


@router.get('/bom/versions')
def saved_versions(request: Request, offset: int=Query(0,ge=0,le=10000), grant=Depends(session)):
    result = projects.versions(grant['inventory_id'], grant['actor_id'], offset)
    session(request)
    return result


@router.get('/bom/versions/{version_id}')
def saved_version(request: Request, version_id: UUID, grant=Depends(session)):
    result = projects.version(grant['inventory_id'], grant['actor_id'], version_id)
    session(request)
    return result


@router.post('/generation/jobs')
@limiter.limit('5/minute')
def create_job(request: Request, data: generation.Submission, grant=Depends(session)):
    return generation.submit(data, grant['inventory_id'], grant['actor_id'], grant['id'])


@router.get('/generation/jobs')
def list_jobs(request: Request, grant=Depends(session)):
    result = generation.jobs(grant['inventory_id'], grant['actor_id'])
    session(request)
    return result


@router.get('/generation/jobs/{job_id}')
@limiter.limit('30/minute')
def job_status(request: Request, job_id: UUID, grant=Depends(session)):
    result = generation.status(grant['inventory_id'], grant['actor_id'], job_id)
    session(request)
    return result


@router.post('/generation/jobs/{job_id}/resume')
@limiter.limit('5/minute')
def resume_job(request: Request, job_id: UUID, grant=Depends(session)):
    job = generation.owned(grant['inventory_id'], grant['actor_id'], job_id)
    return generation.resume(job, grant['inventory_id'], grant['actor_id'], grant['id'])


@router.post('/generation/jobs/{job_id}/answers')
@limiter.limit('10/minute')
def answer_job(request: Request, job_id: UUID, data: generation.Answer, grant=Depends(session)):
    return generation.answer(grant['inventory_id'], grant['actor_id'], job_id, data, grant['id'])


@router.post('/generation/jobs/{job_id}/cancel')
@limiter.limit('10/minute')
def cancel_job(request: Request, job_id: UUID, grant=Depends(session)):
    return generation.cancel(grant['inventory_id'], grant['actor_id'], job_id, grant['id'])


@router.get('/generation/jobs/{job_id}/download')
@limiter.limit('5/minute')
def download_job(request: Request, job_id: UUID, grant=Depends(session)):
    data, metadata = generation.download(grant['inventory_id'], grant['actor_id'], job_id)
    session(request)
    return Response(data, media_type='application/step', headers={'Cache-Control':'no-store',
        'X-STEP-SHA256':metadata['artifact']['sha256'], 'Content-Disposition':'attachment; filename="generated.step"'})

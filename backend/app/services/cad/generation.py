"""Durable FindEZ ownership for temporary provider jobs; no shared-key ID access."""
from uuid import UUID
from typing import Literal
from fastapi import HTTPException
from pydantic import Field, model_validator
from .snapshot import Model
from . import rexcad, projects
from .repository import authorize_inventory
from app.services.supabase_client import get_supabase_raw


class Specification(Model):
    prompt: str = Field(min_length=10, max_length=16000)
    name: str = Field(min_length=1, max_length=160)
    units: Literal['mm', 'in'] = 'mm'

    @model_validator(mode='after')
    def text(self):
        if not self.prompt.strip() or not self.name.strip() or len(self.prompt.encode()) > 65536:
            raise ValueError('Provide a bounded dimensional specification.')
        return self


class Submission(Specification):
    request_id: UUID
    confirmed: Literal[True]


class Answer(Model):
    request_id: UUID
    version: int = Field(ge=0)
    question_id: str = Field(min_length=1, max_length=512)
    answer: str = Field(min_length=1, max_length=16000)


def owned(inventory, actor, job_id):
    projects.require_enabled()
    authorize_inventory(inventory, actor)
    rows = get_supabase_raw().table('cad_generation_jobs').select('*').eq('inventory_id', inventory).eq(
        'actor_id', actor).eq('id', str(job_id)).limit(1).execute().data or []
    if not rows:
        raise HTTPException(404, 'This generation job is unavailable in your inventory.')
    return rows[0]


def public(job, status):
    # Never expose the shared provider job ID or its paths as capabilities.
    return {**status, 'id': job['id'], 'name': job['specification']['name'],
            'units': job['specification']['units'], 'quality': 'generated_unverified'}


def submit(data, inventory, actor, grant=None):
    projects.writable(inventory, actor, grant)
    if not rexcad.configured():
        raise HTTPException(503, 'Model generation is not enabled yet.')
    spec = Specification.model_validate(data.model_dump(include={'prompt', 'name', 'units'})).model_dump()
    job = projects.receipt(get_supabase_raw().rpc('findez_cad_begin_generation', {
        'p_actor': actor, 'p_inventory': inventory, 'p_grant': grant,
        'p_request': str(data.request_id), 'p_hash': projects.digest(spec), 'p_spec': spec}).execute().data)
    return resume(job, inventory, actor, grant)


def resume(job, inventory, actor, grant=None):
    projects.writable(inventory, actor, grant)
    if job.get('provider_id'):
        return public(job, rexcad.status(job['provider_id']))
    spec = job['specification']
    # The DB receipt exists before provider submission. Uncertain network results
    # retry with this same global FindEZ job ID, never mint another provider job.
    result = rexcad.submit(**spec, request_id='findez-' + job['id'])
    provider_id = result['id']
    rows = get_supabase_raw().table('cad_generation_jobs').update({'provider_id': provider_id}).eq(
        'id', job['id']).eq('inventory_id', inventory).eq('actor_id', actor).is_('provider_id', 'null').execute().data
    if not rows:
        current = owned(inventory, actor, job['id'])
        if current.get('provider_id') != provider_id:
            raise HTTPException(409, 'The generated job receipt could not be confirmed. Retry this job.')
    authorize_inventory(inventory, actor)
    return public(job, result)


def status(inventory, actor, job_id):
    job = owned(inventory, actor, job_id)
    if not job.get('provider_id'):
        return public(job, {'state': 'pending_submission', 'version': 0, 'question': None, 'expires': None})
    result = rexcad.status(job['provider_id'])
    authorize_inventory(inventory, actor)
    return public(job, result)


def jobs(inventory, actor):
    projects.require_enabled()
    authorize_inventory(inventory, actor)
    rows = get_supabase_raw().table('cad_generation_jobs').select('id,created_at,specification->name').eq(
        'inventory_id', inventory).eq('actor_id', actor).order('created_at', desc=True).limit(50).execute().data or []
    authorize_inventory(inventory, actor)
    return {'jobs': rows, 'inventory_id': inventory}


def answer(inventory, actor, job_id, data, grant=None):
    projects.writable(inventory, actor, grant)
    job = owned(inventory, actor, job_id)
    if not job.get('provider_id'):
        raise HTTPException(409, 'Resume this submission before answering a question.')
    result = rexcad.answer(job['provider_id'], data.version, data.question_id, data.answer,
                          'findez-' + job['id'] + '-answer-' + str(data.request_id))
    authorize_inventory(inventory, actor)
    return public(job, result)


def cancel(inventory, actor, job_id, grant=None):
    projects.writable(inventory, actor, grant)
    job = owned(inventory, actor, job_id)
    if not job.get('provider_id'):
        raise HTTPException(409, 'Submission is unconfirmed. Resume it, then cancel.')
    result = rexcad.cancel(job['provider_id'])
    authorize_inventory(inventory, actor)
    return public(job, result)


def download(inventory, actor, job_id):
    job = owned(inventory, actor, job_id)
    if not job.get('provider_id'):
        raise HTTPException(409, 'This model is not ready.')
    data, metadata = rexcad.download(job['provider_id'])
    authorize_inventory(inventory, actor)
    return data, metadata

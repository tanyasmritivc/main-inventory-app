"""Server-only RexCAD transport. Never follow provider URLs or expose its key."""
import hashlib
import json
import os
import math
from datetime import datetime
from typing import Literal
from uuid import UUID

import httpx
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

ORIGIN = 'https://rexcad.com/api/v1/generation'
MAX_STEP = 100 * 1024 * 1024
MAX_JSON = 1024 * 1024


class ProviderModel(BaseModel):
    model_config = ConfigDict(extra='ignore', strict=True)


class Question(ProviderModel):
    id: str = Field(min_length=1, max_length=512)
    text: str = Field(min_length=1, max_length=65536)


class Job(ProviderModel):
    id: str
    state: Literal['queued', 'running', 'validating', 'needs_input', 'succeeded', 'failed', 'cancelled', 'expired']
    version: int = Field(ge=0)
    expires: str
    question: Question | None = None


class Geometry(ProviderModel):
    valid: Literal[True]
    solids: int = Field(ge=1)
    volume: float = Field(gt=0, allow_inf_nan=False)
    boundsMin: list[float] = Field(min_length=3, max_length=3)
    boundsMax: list[float] = Field(min_length=3, max_length=3)

    @model_validator(mode='after')
    def bounds(self):
        if any(not math.isfinite(v) for v in self.boundsMin + self.boundsMax) or any(
                hi <= lo for lo, hi in zip(self.boundsMin, self.boundsMax)):
            raise ValueError('Invalid solid bounds.')
        return self


class Artifact(ProviderModel):
    sha256: str = Field(pattern=r'^[a-f0-9]{64}$')
    bytes: int = Field(gt=0, le=MAX_STEP)
    geometry: Geometry


class Result(ProviderModel):
    id: str
    artifact: Artifact
    verification: dict | None = None


def configured():
    return os.getenv('CAD_GENERATION_ENABLED') == 'true' and bool(os.getenv('REXCAD_GENERATION_KEY'))


def _key():
    if not configured():
        raise HTTPException(503, 'Model generation is not enabled. Existing Fusion models remain available.')
    return os.environ['REXCAD_GENERATION_KEY']


def _uuid(value):
    try:
        return str(UUID(str(value)))
    except ValueError:
        raise HTTPException(422, 'Choose a valid generation job.') from None


def _request(path, *, method='GET', body=None, request_id=None, binary=False):
    headers = {'Authorization': 'Bearer ' + _key(), 'Accept': 'application/step' if binary else 'application/json'}
    if request_id:
        headers['Idempotency-Key'] = request_id
    try:
        with httpx.Client(follow_redirects=False, timeout=httpx.Timeout(60, connect=10)) as client:
            with client.stream(method, ORIGIN + path, headers=headers, json=body) as response:
                if response.status_code in (401, 403):
                    raise HTTPException(503, 'The model-generation connection needs administrator attention.')
                if response.status_code == 404:
                    raise HTTPException(410, 'This generated model is unavailable or has expired.')
                if response.status_code == 409:
                    raise HTTPException(409, 'This generation job changed. Refresh it before trying again.')
                if response.status_code == 429:
                    raise HTTPException(429, 'Model generation is busy. Wait before retrying this request.')
                if response.status_code < 200 or response.status_code >= 300:
                    raise HTTPException(502, 'The model-generation service could not complete this request.')
                limit = MAX_STEP if binary else MAX_JSON
                data = bytearray()
                for chunk in response.iter_bytes():
                    if len(data) + len(chunk) > limit:
                        raise HTTPException(502, 'The model-generation response exceeds the supported size.')
                    data.extend(chunk)
                if binary:
                    if response.headers.get('content-type', '').split(';')[0].strip() != 'application/step':
                        raise HTTPException(502, 'The model-generation service did not return a STEP model.')
                    return bytes(data)
                result = json.loads(data)
                if not isinstance(result, dict):
                    raise ValueError()
                return result
    except (httpx.HTTPError, ValueError):
        # Do not relay exceptions, headers, provider errors or echoed prompts.
        raise HTTPException(502, 'Model generation could not be reached. Retry the same request to avoid duplicate jobs.') from None


def _job(data, expected=None):
    try:
        job = Job.model_validate(data)
        job_id = str(UUID(job.id))
        expiry = datetime.fromisoformat(job.expires.replace('Z', '+00:00'))
        if expiry.tzinfo is None or (expected and job_id != _uuid(expected)):
            raise ValueError()
        if job.state == 'needs_input' and job.question is None:
            raise ValueError()
        return {**job.model_dump(), 'id': job_id, 'quality': 'generated_unverified',
                'error': 'Generation failed. Review the specifications and start a new job.' if job.state == 'failed' else None}
    except (ValidationError, ValueError):
        raise HTTPException(502, 'The model-generation status could not be verified.') from None


def submit(prompt, name, units, request_id):
    return _job(_request('/jobs', method='POST', body={'prompt': prompt, 'name': name, 'units': units}, request_id=request_id))


def status(job_id):
    return _job(_request('/jobs/' + _uuid(job_id)), job_id)


def answer(job_id, version, question_id, text, request_id):
    return _job(_request('/jobs/' + _uuid(job_id) + '/answers', method='POST',
        body={'version': version, 'questionId': question_id, 'answer': text}, request_id=request_id), job_id)


def cancel(job_id):
    return _job(_request('/jobs/' + _uuid(job_id) + '/cancel', method='POST'), job_id)


def result(job_id):
    try:
        data = Result.model_validate(_request('/jobs/' + _uuid(job_id) + '/result'))
        if str(UUID(data.id)) != _uuid(job_id):
            raise ValueError()
        # Export consistency is evidence, not manufacturer certification.
        return {'artifact': data.artifact.model_dump(), 'verification': data.verification,
                'quality': 'generated_unverified'}
    except (ValidationError, ValueError):
        raise HTTPException(502, 'The generated model metadata could not be verified.') from None


def download(job_id):
    metadata = result(job_id)
    data = _request('/jobs/' + _uuid(job_id) + '/download', binary=True)
    artifact = metadata['artifact']
    if len(data) != artifact['bytes'] or hashlib.sha256(data).hexdigest() != artifact['sha256']:
        raise HTTPException(502, 'The generated STEP failed its size or checksum check. Do not insert this model.')
    if not data.lstrip().startswith(b'ISO-10303-21;') or b'END-ISO-10303-21;' not in data[-512:]:
        raise HTTPException(502, 'The generated file is not a supported STEP document.')
    return data, metadata

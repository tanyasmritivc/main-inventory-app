"""Synthetic catalog sources; no manufacturer assets or production database."""
import base64
import hashlib
import io
import json
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from PIL import Image
import pytest

from app.api.routes import cad_workspace as routes
from app.services.cad import model_library as library
from tests.test_cad_workspace import Query, grant


@pytest.fixture
def publication(monkeypatch, tmp_path):
    key = uuid4()
    folder = tmp_path / str(key)
    folder.mkdir()
    monkeypatch.setenv('FINDEZ_CAD_MODEL_LIBRARY', str(tmp_path))
    png = io.BytesIO()
    Image.new('RGB', (5, 5)).save(png, format='PNG')
    step = b'ISO-10303-21;\nHEADER;ENDSEC;\nDATA;ENDSEC;\nEND-ISO-10303-21;'
    record = dict(catalog_id=str(key), manufacturer='Test manufacturer', part_number='P-123',
                  specifications={'length_mm':'4'}, units='mm', revision='A', source='manufacturer',
                  source_url='https://example.org/model', redistribution_evidence='fixture only', redistribution_approved=True,
                  reviewed_by='test fixture')
    for field, extension, data in [('step_sha256','.step',step), ('preview_sha256','.png',png.getvalue())]:
        digest = hashlib.sha256(data).hexdigest()
        record[field] = digest
        (folder / (digest + extension)).write_bytes(data)
    (folder / 'manifest.json').write_text(json.dumps(record))
    db = Query([{'brand':'Test manufacturer', 'part_number':'P-123','specifications':{'length_mm':4}}])
    monkeypatch.setattr(library,'get_supabase_raw',lambda:db)
    return key, folder, record, step, db


def test_preview_and_download_require_current_verified_identity(publication):
    key, _, record, step, db = publication
    model = library.preview(key)['model']
    assert model['part_number'] == 'P-123'
    assert 'redistribution_evidence' not in model and 'reviewed_by' not in model
    assert Image.open(io.BytesIO(base64.b64decode(model['preview_png']))).size == (5, 5)
    assert library.download(key, model['revision_id'], record['step_sha256']) == step
    assert ('eq', ('verification_status','verified'), {}) in db.calls
    assert ('eq', ('catalog_id',str(key)), {}) in db.calls
    db.rows[0]['specifications']['length_mm'] = 5
    assert library.preview(key) == {'model':None}
    with pytest.raises(HTTPException) as err:
        library.download(key, model['revision_id'], record['step_sha256'])
    assert err.value.status_code == 409


@pytest.mark.parametrize('failure', ['missing-rights','bad-preview','bad-step','stale-review','replaced-identity'])
def test_bad_publications_fail_closed(publication, failure):
    key, folder, record, _, _ = publication
    revision = library.preview(key)['model']['revision_id']
    if failure == 'bad-preview':
        (folder / (record['preview_sha256'] + '.png')).write_bytes(b'changed')
    if failure == 'bad-step':
        (folder / (record['step_sha256'] + '.step')).write_bytes(b'changed')
    if failure == 'missing-rights':
        del record['redistribution_evidence']
    if failure == 'stale-review':
        record['revision'] = 'B'
    if failure == 'replaced-identity':
        record['catalog_id'] = str(uuid4())
    (folder / 'manifest.json').write_text(json.dumps(record))
    with pytest.raises(HTTPException):
        if failure in ('bad-step', 'stale-review'):
            library.download(key, revision, record['step_sha256'])
        else:
            library.preview(key)


def test_catalog_endpoints_require_grant_and_recheck_after_read(publication, monkeypatch):
    key, _, _, _, _ = publication
    app = FastAPI()
    app.include_router(routes.router)
    client = TestClient(app)
    path = f'/fusion/catalog/{key}/model'
    assert client.get(path).status_code == 401
    app.dependency_overrides[routes.session] = grant
    monkeypatch.setattr(routes, 'session', lambda request:grant())
    model = client.get(path).json()['model']
    url = f"{path}/{model['revision_id']}/{model['step_sha256']}"
    response = client.get(url)
    assert response.status_code == 200 and response.headers['X-STEP-SHA256'] == model['step_sha256']
    assert response.headers['content-type'] == 'application/step'
    def revoked(request):
        raise HTTPException(403, 'Revoked')
    monkeypatch.setattr(routes, 'session', revoked)
    assert client.get(path).status_code == 403
    assert client.get(url).status_code == 403


def test_library_disabled_or_no_published_asset(monkeypatch, tmp_path):
    monkeypatch.delenv('FINDEZ_CAD_MODEL_LIBRARY', raising=False)
    assert not library.configured() and library.preview(uuid4()) == {'model':None}
    monkeypatch.setenv('FINDEZ_CAD_MODEL_LIBRARY', str(tmp_path))
    assert library.configured() and library.preview(uuid4()) == {'model':None}


def test_missing_library_volume_is_reported(monkeypatch, tmp_path):
    monkeypatch.setenv('FINDEZ_CAD_MODEL_LIBRARY', str(tmp_path / 'missing'))
    assert not library.configured()
    with pytest.raises(HTTPException) as error:
        library.preview(uuid4())
    assert error.value.status_code == 503

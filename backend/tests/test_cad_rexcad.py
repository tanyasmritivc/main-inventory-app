import hashlib
import json
from unittest.mock import Mock
from uuid import uuid4
import httpx
import pytest
from fastapi import HTTPException
from app.services.cad import rexcad, generation, projects
from backend.tests.test_cad_workspace import Query, INV, ACTOR
from backend.tests.test_cad_prototype import snapshot, stock

JOB=str(uuid4())
STATE={'id':JOB,'state':'queued','version':1,'expires':'2026-12-01T00:00:00Z'}
STEP=b'ISO-10303-21;\nDATA;\nENDSEC;\nEND-ISO-10303-21;'
META={'id':JOB,'download':'https://attacker.invalid/steal', 'filename':'../../private',
      'artifact':{'bytes':len(STEP),'sha256':hashlib.sha256(STEP).hexdigest(),'geometry':{'valid':True,'solids':1,'volume':10.0,'boundsMin':[0.0,0.0,0.0],'boundsMax':[1.0,2.0,5.0]}}}

@pytest.fixture
def transport(monkeypatch):
    monkeypatch.setenv('CAD_GENERATION_ENABLED','true');monkeypatch.setenv('REXCAD_GENERATION_KEY','synthetic-test-key')
    real=httpx.Client
    def install(handler):
        seen=[]
        def wrapped(request):
            seen.append(request)
            assert request.url.host=='rexcad.com'
            assert request.headers['Authorization']=='Bearer synthetic-test-key'
            return handler(request)
        monkeypatch.setattr(rexcad.httpx,'Client',lambda **kwargs:real(transport=httpx.MockTransport(wrapped),**kwargs))
        return seen
    return install


def test_submission_reuses_idempotency_and_does_not_send_secret_in_prompt(transport):
    seen=transport(lambda req:httpx.Response(202,json=STATE))
    assert rexcad.submit('Plate 60x40x5 mm','Plate','mm','stable-request')['id']==JOB
    assert seen[0].headers['Idempotency-Key']=='stable-request'
    assert json.loads(seen[0].content)=={'prompt':'Plate 60x40x5 mm','name':'Plate','units':'mm'}

@pytest.mark.parametrize('status,expected',[(301,502),(400,502),(401,503),(403,503),(404,410),(409,409),(429,429),(500,502)])
def test_provider_errors_are_scrubbed_and_redirects_not_followed(transport,status,expected):
    seen=transport(lambda req:httpx.Response(status,headers={'Location':'https://attacker.invalid'},json={'error':'sensitive provider content'}))
    with pytest.raises(HTTPException) as error:rexcad.status(JOB)
    assert error.value.status_code==expected
    assert 'sensitive' not in error.value.detail and len(seen)==1


def test_checksum_download_uses_fixed_path_not_provider_url(transport):
    seen=transport(lambda req:httpx.Response(200,json=META) if req.url.path.endswith('/result') else httpx.Response(200,content=STEP,headers={'Content-Type':'application/step'}))
    data,meta=rexcad.download(JOB)
    assert data==STEP and meta['quality']=='generated_unverified'
    assert seen[-1].url.path==f'/api/v1/generation/jobs/{JOB}/download'
    assert 'download' not in meta and 'filename' not in meta

@pytest.mark.parametrize('corruption',['bytes','hash','mime','step'])
def test_corrupted_models_are_rejected_before_insertion(transport,corruption):
    data=STEP if corruption!='step' else b'not a STEP'
    meta=json.loads(json.dumps(META))
    if corruption=='bytes':meta['artifact']['bytes']+=1
    if corruption=='hash':meta['artifact']['sha256']='0'*64
    if corruption=='step':meta['artifact'].update(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
    transport(lambda req:httpx.Response(200,json=meta) if req.url.path.endswith('/result') else httpx.Response(200,content=data,headers={'Content-Type':'text/html' if corruption=='mime' else 'application/step'}))
    with pytest.raises(HTTPException):rexcad.download(JOB)


def test_question_state_requires_question_and_limits_response(transport,monkeypatch):
    transport(lambda req:httpx.Response(200,json={**STATE,'state':'needs_input'}))
    with pytest.raises(HTTPException):rexcad.status(JOB)
    monkeypatch.setattr(rexcad,'MAX_JSON',8)
    with pytest.raises(HTTPException):rexcad.status(JOB)


def test_clarification_preserves_version_question_and_retry(transport):
    seen=transport(lambda req:httpx.Response(200,json=STATE))
    rexcad.answer(JOB,7,'question-1','Thickness 5 mm','same-answer')
    assert json.loads(seen[0].content)=={'version':7,'questionId':'question-1','answer':'Thickness 5 mm'}
    assert seen[0].headers['Idempotency-Key']=='same-answer'

def test_malformed_provider_identity_is_a_gateway_failure(transport):
    transport(lambda req:httpx.Response(200,json={**STATE,'id':'bad'}))
    with pytest.raises(HTTPException) as error:rexcad.status(JOB)
    assert error.value.status_code==502

@pytest.mark.parametrize('geometry',[{'valid':False},{'solids':0},{'volume':float('nan')},{'boundsMax':[0.0,2.0,5.0]}])
def test_invalid_geometry_metadata_prevents_download(transport,geometry):
    meta=json.loads(json.dumps(META));meta['artifact']['geometry'].update(geometry)
    seen=transport(lambda req:httpx.Response(200,content=json.dumps(meta)))
    with pytest.raises(HTTPException):rexcad.download(JOB)
    assert len(seen)==1 and seen[0].url.path.endswith('/result')

def test_write_revocation_stops_generation_before_provider_or_database_write(monkeypatch):
    def revoked(*args):raise HTTPException(403,'Revoked')
    monkeypatch.setattr(projects,'writable',revoked)
    provider=Mock();db=Mock();monkeypatch.setattr(rexcad,'submit',provider);monkeypatch.setattr(generation,'get_supabase_raw',db)
    data=generation.Submission(prompt='Plate 60 x 40 x 5 mm',name='Plate',units='mm',request_id=uuid4(),confirmed=True)
    with pytest.raises(HTTPException):generation.submit(data,INV,ACTOR,'grant')
    provider.assert_not_called();db.assert_not_called()


def test_owned_generation_never_allows_a_shared_provider_key_to_bypass_inventory(monkeypatch):
    monkeypatch.setenv('CAD_BOM_ENABLED','true');monkeypatch.setattr(generation,'authorize_inventory',Mock())
    db=Query([]);monkeypatch.setattr(generation,'get_supabase_raw',lambda:db)
    provider=Mock();monkeypatch.setattr(rexcad,'status',provider)
    with pytest.raises(HTTPException) as error:generation.status(INV,ACTOR,JOB)
    assert error.value.status_code==404;provider.assert_not_called()
    for column,value in [('inventory_id',INV),('actor_id',ACTOR),('id',JOB)]:assert ('eq',(column,value),{}) in db.calls


def test_pending_submission_does_not_auto_create_provider_job_on_read(monkeypatch):
    monkeypatch.setattr(generation,'owned',lambda *args:{'id':JOB,'specification':{'name':'Plate','units':'mm'}})
    remote=Mock();monkeypatch.setattr(rexcad,'submit',remote)
    assert generation.status(INV,ACTOR,JOB)['state']=='pending_submission';remote.assert_not_called()


def test_retry_uses_durable_job_identity(monkeypatch):
    monkeypatch.setattr(projects,'writable',Mock());monkeypatch.setattr(generation,'authorize_inventory',Mock())
    db=Query([{'id':JOB}]);monkeypatch.setattr(generation,'get_supabase_raw',lambda:db)
    submit=Mock(return_value=STATE);monkeypatch.setattr(rexcad,'submit',submit)
    job={'id':JOB,'specification':{'prompt':'Plate 60x40x5','name':'Plate','units':'mm'}}
    generation.resume(job,INV,ACTOR,'grant');generation.resume(job,INV,ACTOR,'grant')
    assert submit.call_count==2
    assert submit.call_args.kwargs['request_id']=='findez-'+JOB
    assert 'synthetic-test-key' not in str(db.calls)


def test_saved_bom_requires_saved_design_and_does_not_accept_stock_from_client(monkeypatch):
    monkeypatch.setattr(projects,'writable',Mock());monkeypatch.setattr(projects,'authorize_inventory',Mock())
    read=Mock(return_value=([stock(3)],[],[]));monkeypatch.setattr(projects,'read_inventory',read)
    monkeypatch.setattr(projects.corrections,'load',lambda *args:{})
    db=Query(data={'id':JOB,'project_id':JOB,'version':1});monkeypatch.setattr(projects,'get_supabase_raw',lambda:db)
    snap=snapshot();snap.document.external_id='unsaved:random'
    with pytest.raises(HTTPException):projects.save(snap,INV,ACTOR,JOB)
    read.assert_not_called()
    snap.document.external_id='fusion-file'
    projects.save(snap,INV,ACTOR,JOB,'grant')
    args=next(c[1][1] for c in db.calls if c[0]=='rpc')
    assert args['p_comparison']['summary']['covered_units']==3
    assert args['p_grant']=='grant' and args['p_inventory']==INV
    assert 'review_token' not in json.dumps(args['p_comparison'])


def test_snapshot_identity_changes_invalidate_corrections_but_quantity_does_not():
    from app.services.cad.corrections import identity
    row={'name':'M4 screw','part_number':'M4-16','source_token':'component','required':4}
    assert identity(row)==identity({**row,'required':8})
    assert identity(row)!=identity({**row,'part_number':'M4-12'})

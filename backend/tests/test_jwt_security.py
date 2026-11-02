"""Real signed-token verification for algorithm, issuer and required claims."""
import json
from time import time
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from app.core import auth
from app.services import supabase_client

ACTOR='e6000000-0000-0000-0000-000000000001'
ISSUER='https://auth.example.invalid/auth/v1'
SECRET='isolated-security-test-secret-32-characters'

@pytest.fixture(params=['HS256','ES256','RS256'])
def verifier(request, monkeypatch):
    algorithm=request.param
    key=SECRET if algorithm=='HS256' else ec.generate_private_key(ec.SECP256R1()) if algorithm=='ES256' else rsa.generate_private_key(public_exponent=65537,key_size=2048)
    settings=SimpleNamespace(supabase_jwt_secret=SECRET,supabase_jwt_audience='authenticated',supabase_public_url='https://auth.example.invalid',supabase_url='http://internal.invalid',supabase_jwks_url='https://auth.example.invalid/jwks')
    monkeypatch.setattr(auth,'get_settings',lambda:settings)
    monkeypatch.setattr(auth,'_get_cached_first_name',lambda _: (True,None))
    db=MagicMock();db.rpc.return_value.execute.return_value.data=True
    monkeypatch.setattr(supabase_client,'get_supabase_raw',lambda:db)
    keys=[]
    if algorithm!='HS256':
        cls=jwt.algorithms.ECAlgorithm if algorithm=='ES256' else jwt.algorithms.RSAAlgorithm
        keys=[{**json.loads(cls.to_jwk(key.public_key())),'kid':'test-key','alg':algorithm,'use':'sig'}]
    monkeypatch.setattr(auth._jwks_cache,'get',AsyncMock(return_value={'keys':keys}))
    app=FastAPI()
    @app.get('/protected')
    def protected(user=Depends(auth.get_current_user)):return {'user_id':user.user_id}
    with TestClient(app) as client:yield client,algorithm,key,db

def claims():
    now=int(time());return {'sub':ACTOR,'aud':'authenticated','iss':ISSUER,'iat':now,'exp':now+120}

def send(v,payload,**kw):
    client,algorithm,key,_=v
    token=jwt.encode(payload,key,algorithm=algorithm,headers={'kid':'test-key',**kw})
    return client.get('/protected',headers={'Authorization':'Bearer '+token})

def test_current_signed_token_accepted(verifier):
    assert send(verifier,claims()).status_code==200

@pytest.mark.parametrize('missing',['exp','iat','iss','sub','aud'])
def test_missing_required_claim_rejected(verifier,missing):
    payload=claims();del payload[missing]
    assert send(verifier,payload).status_code==401
    verifier[3].rpc.assert_not_called()

@pytest.mark.parametrize('field,value',[('iss','https://foreign.invalid/auth/v1'),('aud','other-service'),('exp',1),('iat',4102444800)])
def test_wrong_or_expired_claim_rejected(verifier,field,value):
    payload=claims();payload[field]=value
    assert send(verifier,payload).status_code==401
    verifier[3].rpc.assert_not_called()

def test_unsigned_token_rejected_before_account_lookup(verifier):
    client,_,_,db=verifier
    token=jwt.encode(claims(),key='',algorithm='none')
    assert client.get('/protected',headers={'Authorization':'Bearer '+token}).status_code==401
    db.rpc.assert_not_called()

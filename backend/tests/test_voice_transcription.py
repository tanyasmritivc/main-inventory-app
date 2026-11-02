import asyncio
import io
import wave
from types import SimpleNamespace
from unittest.mock import patch

import httpx
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.api.routes.voice import router
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services import voice_transcription as voice


def wav(frames=16000, rate=16000):
    out = io.BytesIO()
    with wave.open(out, 'wb') as audio:
        audio.setnchannels(1); audio.setsampwidth(2); audio.setframerate(rate)
        audio.writeframes(b'\x00\x00' * frames)
    return out.getvalue()


@pytest.mark.parametrize('data,status', [(b'',413),(b'x'*2100001,413),(b'not audio',422),(wav(0),422),(wav(rate=8000),422),(wav(1040001),422),(wav()[:-2],422)])
def test_invalid_audio_never_reaches_provider(data, status):
    with pytest.raises(HTTPException) as error:
        voice.validate_audio(data)
    assert error.value.status_code == status


def test_valid_wave():
    voice.validate_audio(wav())


@pytest.mark.parametrize('kind,status', [('ok',200),('empty',200),('auth',502),('redirect',502),('timeout',504),('malformed',502),('too_long',502)])
def test_provider_contract_and_scrubbed_failures(kind,status):
    requests=[]
    def handler(request):
        requests.append(request)
        assert request.url == 'https://llmtest.ftctools.com/v1/audio/transcriptions'
        assert request.headers['authorization'] == 'Bearer test-only-secret'
        assert b'whisper-large-v3' in request.content and b'audio/wav' in request.content
        if kind=='timeout': raise httpx.ReadTimeout('private upstream detail',request=request)
        if kind=='auth': return httpx.Response(401,json={'error':'private upstream detail'})
        if kind=='redirect': return httpx.Response(307,headers={'location':'https://untrusted.test'})
        value={'ok':' Find my drill ','empty':'','too_long':'x'*10001}.get(kind)
        return httpx.Response(200,json={'text':value})
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    with patch.object(voice,'get_settings',return_value=SimpleNamespace(whisper_api_key=SecretStr('test-only-secret'))), patch.object(voice.httpx,'AsyncClient',return_value=client):
        if status==200:
            assert asyncio.run(voice.transcribe_audio(wav())) == ('Find my drill' if kind=='ok' else '')
        else:
            with pytest.raises(HTTPException) as error: asyncio.run(voice.transcribe_audio(wav()))
            assert error.value.status_code==status
            assert 'private' not in error.value.detail and 'secret' not in error.value.detail
    assert len(requests)==1


def test_missing_config_is_safe():
    with patch.object(voice,'get_settings',return_value=SimpleNamespace(whisper_api_key=None)):
        with pytest.raises(HTTPException) as error: asyncio.run(voice.transcribe_audio(wav()))
    assert error.value.status_code==503


def test_http_requires_session_and_rejects_wrong_mime():
    app=FastAPI();app.include_router(router)
    limiter.enabled=False
    try:
        with TestClient(app) as client:
            response=client.post('/voice/transcriptions',files={'file':('voice.wav',wav(),'audio/wav')})
            assert response.status_code in (401,403)
            app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id='test-user')
            assert client.post('/voice/transcriptions',files={'file':('voice.wav',wav(),'image/png')}).status_code==415
            assert client.post('/voice/transcriptions',files={'file':('voice.wav',b'bad','audio/wav')}).status_code==422
    finally: limiter.enabled=True

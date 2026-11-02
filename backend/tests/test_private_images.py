from types import SimpleNamespace
from unittest.mock import MagicMock
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.api.routes import private_images
from app.core.auth import AuthenticatedUser,get_current_user
from app.services import storage
PATH='d4000000-0000-0000-0000-000000000003/photo.jpg'

@pytest.fixture
def image_api(monkeypatch):
    raw=MagicMock()
    raw.rpc.return_value.execute.return_value.data=True
    raw.storage.from_.return_value.download.return_value=b'\xff\xd8fixture'
    monkeypatch.setattr(private_images,'get_supabase_raw',lambda:raw)
    monkeypatch.setattr(private_images,'get_settings',lambda:SimpleNamespace(supabase_storage_bucket='item-images'))
    app=FastAPI();app.include_router(private_images.router)
    yield app,raw

def test_photo_url_without_a_signed_in_user_is_not_access(image_api):
    app,raw=image_api
    with TestClient(app) as client: assert client.get('/media/item-image',params={'path':PATH}).status_code==401
    raw.storage.from_.assert_not_called()

@pytest.mark.parametrize('allowed,status',[(True,200),(False,404),(None,404)])
def test_photo_requires_fresh_record_permission_and_never_redirects_to_storage(image_api,allowed,status):
    app,raw=image_api
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id='actor')
    raw.rpc.return_value.execute.return_value.data=allowed
    with TestClient(app) as client:
        result=client.get('/media/item-image',params={'path':PATH})
        assert result.status_code==status
        assert 'location' not in result.headers
        if allowed:
            assert result.content==b'\xff\xd8fixture'
            assert 'no-store' in result.headers['cache-control']
            assert result.headers['content-type']=='image/jpeg'
        else: raw.storage.from_.assert_not_called()
    raw.rpc.assert_called_once_with('findez_can_read_item_image',{'p_actor':'actor','p_path':PATH})

@pytest.mark.parametrize('path',['../foreign.jpg',PATH+'/../other.jpg',PATH.replace('photo','%2e%2e'),PATH+'\\other',PATH+'\x00'])
def test_invalid_photo_locator_never_reaches_storage(image_api,path):
    app,raw=image_api
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id='actor')
    with TestClient(app) as client: assert client.get('/media/item-image',params={'path':path}).status_code==400
    raw.rpc.assert_not_called()

def test_unavailable_permission_check_fails_closed(image_api):
    app,raw=image_api
    app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id='actor')
    raw.rpc.return_value.execute.side_effect=RuntimeError('private database detail')
    with TestClient(app) as client:
        result=client.get('/media/item-image',params={'path':PATH});assert result.status_code==503
        assert 'private database' not in result.text
    raw.storage.from_.assert_not_called()

from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from fastapi import FastAPI, Header, HTTPException
from fastapi.testclient import TestClient

from app.api.routes import documents, team_workspace
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import storage


@pytest.fixture
def api():
    app = FastAPI()
    app.include_router(documents.router)
    app.include_router(team_workspace.router)

    def current(authorization: str | None = Header(default=None)):
        if authorization not in ('Bearer owner', 'Bearer unrelated'):
            raise HTTPException(401, 'Sign in required')
        return AuthenticatedUser(user_id=authorization.split()[1])

    app.dependency_overrides[get_current_user] = current
    return TestClient(app)


def owned_document(*, user_id, storage_path):
    if user_id == 'owner' and storage_path == 'owner/docs/sample.txt':
        return {'storage_path': storage_path, 'user_id': user_id}
    return None


@pytest.mark.parametrize('method,path', [
    ('get', '/documents/open'), ('delete', '/documents'),
])
@pytest.mark.parametrize('token,status', [(None, 401), ('unrelated', 404)])
def test_document_access_checks_before_storage(api, method, path, token, status):
    with patch.object(documents, 'get_document', side_effect=owned_document), patch.object(
        documents, 'create_document_signed_url'
    ) as sign, patch.object(documents, 'get_supabase_admin') as admin:
        response = api.request(
            method, path, params={'storage_path': 'owner/docs/sample.txt'},
            headers={} if token is None else {'Authorization': f'Bearer {token}'},
        )
    # Existing open API deliberately returns its compatible 400 not-found code.
    expected = 400 if method == 'get' and token == 'unrelated' else status
    assert response.status_code == expected
    sign.assert_not_called()
    admin.assert_not_called()


def test_owner_open_preserves_signed_url_contract(api):
    with patch.object(documents, 'get_document', side_effect=owned_document), patch.object(
        documents, 'create_document_signed_url', return_value='https://storage.test/signed'
    ) as sign:
        response = api.get('/documents/open', params={'storage_path': 'owner/docs/sample.txt'},
                           headers={'Authorization': 'Bearer owner'})
    assert response.status_code == 200
    assert response.json() == {'url': 'https://storage.test/signed'}
    assert response.headers['cache-control'] == 'private, no-store'
    sign.assert_called_once_with(storage_path='owner/docs/sample.txt')


@pytest.mark.parametrize('method,path', [('get', '/documents/open'), ('delete', '/documents')])
def test_forged_owned_record_cannot_reference_another_users_object(api, method, path):
    with patch.object(documents, 'get_document', return_value={'user_id': 'owner'}), patch.object(
        documents, 'create_document_signed_url'
    ) as sign, patch.object(documents, 'get_supabase_admin') as admin:
        response = api.request(method, path, params={'storage_path': 'victim/docs/sample.txt'},
                               headers={'Authorization': 'Bearer owner'})
    assert response.status_code in (400, 404)
    sign.assert_not_called()
    admin.assert_not_called()


def test_owner_delete_scopes_row_and_object(api):
    admin = MagicMock()
    with patch.object(documents, 'get_document', side_effect=owned_document), patch.object(
        documents, 'get_supabase_admin', return_value=admin
    ):
        response = api.delete('/documents', params={'storage_path': 'owner/docs/sample.txt'},
                              headers={'Authorization': 'Bearer owner'})
    assert response.status_code == 204
    admin.storage.from_.assert_called_once_with('documents')
    admin.storage.from_.return_value.remove.assert_called_once_with(['owner/docs/sample.txt'])
    admin.table.return_value.delete.return_value.eq.assert_called_once_with('user_id', 'owner')


def test_failed_storage_delete_preserves_record(api):
    admin = MagicMock()
    admin.storage.from_.return_value.remove.side_effect = RuntimeError('PRIVATE storage failure')
    with patch.object(documents, 'get_document', side_effect=owned_document), patch.object(
        documents, 'get_supabase_admin', return_value=admin
    ):
        response = api.delete('/documents', params={'storage_path': 'owner/docs/sample.txt'},
                              headers={'Authorization': 'Bearer owner'})
    assert response.status_code == 503
    assert 'PRIVATE' not in response.text
    admin.table.assert_not_called()


@pytest.mark.parametrize('team', [False, True])
@pytest.mark.parametrize('key', ['signedURL', 'signedUrl'])
def test_document_upload_never_uses_public_image_flag(team, key):
    settings = SimpleNamespace(
        supabase_storage_public=True,
        supabase_public_url='https://files.test',
        supabase_storage_signed_url_ttl_seconds=3600,
    )
    admin = MagicMock()
    bucket = admin.storage.from_.return_value
    bucket.create_signed_url.return_value = {
        key: 'http://localhost:18000/storage/v1/object/sign/documents/owner/docs/sample.txt?token=test'
    }
    with patch.object(storage, 'get_settings', return_value=settings), patch.object(
        storage, 'get_supabase_admin', return_value=admin
    ):
        stored = (storage.upload_team_document(team_id='team', user_id='owner', filename='sample.txt', content=b'sample')
                  if team else storage.upload_document(user_id='owner', filename='sample.txt', content=b'sample'))
    bucket.get_public_url.assert_not_called()
    bucket.create_signed_url.assert_called_once_with(stored.path, 3600)
    assert stored.url.startswith('https://files.test/storage/v1/object/sign/documents/')
    assert stored.url.endswith('?token=test')
    bucket.upload.assert_called_once()


def test_team_document_revocation_prevents_new_url(api):
    with patch.object(team_workspace, '_membership', side_effect=HTTPException(403, 'Not a team member')), patch.object(
        team_workspace, '_team_document'
    ) as document, patch.object(team_workspace, 'create_document_signed_url') as sign:
        response = api.get('/teams/team/documents/document/open', headers={'Authorization': 'Bearer unrelated'})
    assert response.status_code == 403
    document.assert_not_called()
    sign.assert_not_called()


def test_team_member_can_open_authorized_document(api):
    with patch.object(team_workspace, '_membership', return_value={'role': 'viewer'}), patch.object(
        team_workspace, '_team_document', return_value={'storage_path': 'teams/team/owner/sample.txt'}
    ), patch.object(team_workspace, 'create_document_signed_url', return_value='https://files.test/signed') as sign:
        response = api.get('/teams/team/documents/document/open', headers={'Authorization': 'Bearer owner'})
    assert response.status_code == 200
    assert response.headers['cache-control'] == 'private, no-store'
    sign.assert_called_once_with(storage_path='teams/team/owner/sample.txt')


@pytest.mark.parametrize('method', ['get', 'delete'])
def test_forged_team_record_cannot_reference_another_teams_file(api, method):
    path = '/teams/team/documents/document' + ('/open' if method == 'get' else '')
    with patch.object(team_workspace, '_membership', return_value={'role': 'owner'}), patch.object(
        team_workspace, '_editor', return_value={'role': 'owner'}
    ), patch.object(team_workspace, '_team_document', return_value={'storage_path': 'teams/victim/owner/sample.txt'}), patch.object(
        team_workspace, 'create_document_signed_url'
    ) as sign, patch.object(team_workspace, 'get_supabase_admin') as admin:
        response = api.request(method, path, headers={'Authorization': 'Bearer owner'})
    assert response.status_code == 404
    sign.assert_not_called()
    admin.assert_not_called()


def test_missing_signed_url_is_a_failure_not_public_fallback():
    admin = MagicMock()
    admin.storage.from_.return_value.create_signed_url.return_value = {}
    with patch.object(storage, 'get_supabase_admin', return_value=admin):
        with pytest.raises(RuntimeError, match='Storage did not return'):
            storage.create_document_signed_url(storage_path='owner/docs/sample.txt')
    admin.storage.from_.return_value.get_public_url.assert_not_called()


@pytest.mark.parametrize('path', [
    'victim/docs/file.txt', 'owner/docs/../victim.txt',
    'owner/%2e%2e/victim/file.txt', 'owner/%252e%252e/victim/file.txt',
    'owner/docs/..%2fvictim.txt', 'owner/docs/%5c..%5cvictim.txt',
    'owner/docs//file.txt', 'owner2/docs/file.txt',
])
def test_rejects_foreign_or_encoded_traversal_paths(path):
    assert not storage.document_path_in_scope(path, 'owner/')


@pytest.mark.parametrize('path', ['owner/docs/note.txt', 'owner/docs/my%20file.txt', 'owner/docs/revision..pdf'])
def test_valid_document_names_are_preserved(path):
    assert storage.document_path_in_scope(path, 'owner/')

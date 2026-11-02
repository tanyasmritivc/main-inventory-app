from io import BytesIO
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

from app.api.routes import checkouts, profile, documents
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import sharing_service, storage
from app.services.inventory_scope import current_inventory, InventoryScope


@pytest.fixture
def api(monkeypatch):
    app = FastAPI()
    for router in (checkouts.router, profile.router, documents.router):
        app.include_router(router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(user_id='actor')
    db = MagicMock()
    query = db.table.return_value
    for method in ('select','eq','in_','order','range','gte','insert','update','upsert'):
        getattr(query, method).return_value = query
    query.execute.return_value = SimpleNamespace(data=[])
    for module in (checkouts, profile):
        monkeypatch.setattr(module, 'get_supabase_admin', lambda: db)
    monkeypatch.setattr(checkouts, '_owned_items', lambda _: [{'item_id':'own','location':'Bench'}])
    monkeypatch.setattr(sharing_service, 'get_joined_shares', lambda **_: [
        {'share_id':'share','team_shares':{'share_id':'share','is_active':True}},
        {'share_id':'revoked','team_shares':{'share_id':'revoked','is_active':False}},
    ])
    monkeypatch.setattr(sharing_service, 'get_share_inventory', lambda **_: [{'item_id':'shared','location':'Bench'}])
    monkeypatch.setattr(sharing_service, 'get_share_access', lambda **_: ({}, False))
    return TestClient(app), db, query


@pytest.mark.parametrize('permission,item,status', [(False,'own',200),(False,'shared',404),(True,'shared',200),(True,'other-space',404),(True,'other-owner-same-name',404)])
def test_checkout_requires_exact_visible_editable_item(api,monkeypatch,permission,item,status):
    client,db,q=api
    monkeypatch.setattr(sharing_service,'get_share_access',lambda **_: ({},permission))
    q.execute.return_value=SimpleNamespace(data=[{'checkout_id':'new'}])
    response=client.post('/checkouts/checkout',json={'item_id':item})
    assert response.status_code==status
    if status==404:q.insert.assert_not_called()
    else:assert q.insert.call_args.args[0]['item_id']==item


def test_active_checkouts_query_exact_item_ids_not_space_names(api):
    client,db,q=api
    assert client.get('/checkouts/active').status_code==200
    assert q.in_.call_args.args==('item_id',['own','shared'])
    assert all(call.args[0]!='space_name' for call in q.eq.call_args_list)


def test_revoked_share_never_queries_checkouts(api,monkeypatch):
    client,db,q=api
    def revoked(**_):raise ValueError('Share revoked')
    monkeypatch.setattr(sharing_service,'get_share_inventory',revoked)
    assert client.get('/checkouts/space?share_id=revoked').status_code==403
    q.select.assert_not_called()


@pytest.mark.parametrize('borrower,editable,status',[('actor',False,200),('other',False,403),('other',True,200)])
def test_return_requires_borrower_or_editor(api,monkeypatch,borrower,editable,status):
    client,db,q=api
    monkeypatch.setattr(sharing_service,'get_share_access',lambda **_: ({},editable))
    q.execute.return_value=SimpleNamespace(data=[{'checkout_id':'c','user_id':borrower,'item_id':'shared'}])
    assert client.post('/checkouts/return',json={'checkout_id':'c'}).status_code==status
    if status==403:q.update.assert_not_called()


def test_history_does_not_leak_foreign_same_name_item(api):
    client,db,q=api
    assert client.get('/checkouts/item/foreign').status_code==404
    q.select.assert_not_called()


@pytest.mark.parametrize('path',['victim/avatar.jpg','actor/../victim/avatar.png','actor/avatar.svg','actor/avatar.jpg%2f..'])
def test_forged_profile_photo_cannot_be_signed_or_deleted(api,monkeypatch,path):
    client,db,q=api
    q.execute.return_value=SimpleNamespace(data=[{'avatar_path':path}])
    db.auth.admin.get_user_by_id.return_value=SimpleNamespace(user=SimpleNamespace(email='qa@example.invalid'))
    sign=MagicMock()
    monkeypatch.setattr(profile,'create_profile_photo_signed_url',sign)
    assert client.get('/profile/me').json()['avatar_url']==''
    assert client.delete('/profile/photo').status_code==200
    sign.assert_not_called()
    db.storage.from_.assert_not_called()
    with pytest.raises(ValueError):storage.create_profile_photo_signed_url(storage_path=path,owner_id='actor')


def test_owner_photo_is_removed_and_reference_cleared(api):
    client,db,q=api
    q.execute.return_value=SimpleNamespace(data=[{'avatar_path':'actor/avatar.png'}])
    assert client.delete('/profile/photo').status_code==200
    db.storage.from_.return_value.remove.assert_called_once_with(['actor/avatar.png'])
    q.upsert.assert_called_once_with({'id':'actor','avatar_path':None})


@pytest.mark.parametrize('name,mime,body',[('payload.html','image/png',b'<script>bad()</script>'),('x.png','image/png',b'<html>bad</html>'),('x.pdf','application/pdf',b'not pdf'),('x.txt','text/plain',b'\x00binary'),('x.svg','image/svg+xml',b'<svg/>')])
def test_spoofed_documents_rejected_before_storage(api,monkeypatch,name,mime,body):
    client,_,_=api
    upload=MagicMock()
    monkeypatch.setattr(documents,'upload_document',upload)
    assert client.post('/documents/upload',files={'file':(name,body,mime)}).status_code==400
    upload.assert_not_called()


def test_real_supported_document_bytes_and_active_team_mime():
    from app.services.document_validation import validate_document
    image=BytesIO();Image.new('RGB',(2,2)).save(image,format='PNG')
    assert validate_document('test.png','image/png',image.getvalue())=='image/png'
    assert validate_document('note.txt','application/octet-stream',b'QA note')=='text/plain'
    assert validate_document('test.pdf','application/pdf',b'%PDF-1.7\n')=='application/pdf'
    for name in ['page.html','script.js','vector.svg','document.xml']:
        assert storage._guess_content_type(name)=='application/octet-stream'

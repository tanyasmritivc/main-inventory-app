"""Synthetic pixels and fake scoped storage only; never customer photos/accounts."""
import asyncio
import io
import random
import time
from types import SimpleNamespace
from unittest.mock import Mock, patch, AsyncMock

import pytest
from PIL import Image, ImageDraw

from app.services import saved_photo_search as search
from app.services import ask_photo_questions as ask
from app.services.resource_access import ActorAccess, request_actor

OWNER = '11111111-1111-4111-8111-111111111111'
PATH = OWNER + '/later.jpg'
URL = 'https://placeholder.supabase.co/storage/v1/object/public/item-images/' + PATH
ITEM = {'item_id':'part','name':'PN-F117','location':'Fastener DB','quantity':10,'image_url':URL}


def scene(seed=1):
    rng = random.Random(seed)
    image = Image.new('RGB',(320,480),'tan')
    draw = ImageDraw.Draw(image)
    for _ in range(25):
        x,y = rng.randrange(280),rng.randrange(400)
        draw.rectangle((x,y,x+rng.randrange(5,40),y+rng.randrange(5,80)),fill=tuple(rng.randrange(256) for _ in range(3)))
    return image


def encode(image,format='PNG',**args):
    out=io.BytesIO(); image.save(out,format=format,**args);return out.getvalue()


def run(content=None, inventory=None):
    return asyncio.run(search.search_saved_photos(user_id='actor',image_bytes=content or encode(scene()),inventory=inventory or [ITEM]))


@pytest.fixture(autouse=True)
def clear_cache():
    search._CACHE.clear()
    yield
    search._CACHE.clear()


@pytest.mark.parametrize('variant', ['exact','jpeg','resize','rotation','crop'])
def test_same_photo_transforms_are_found(variant):
    original=scene(); changed=original
    if variant=='resize':changed=original.resize((160,240))
    if variant=='rotation':changed=original.rotate(90,expand=True)
    if variant=='crop':changed=original.crop((32,48,288,432))
    content=encode(changed,'JPEG',quality=78) if variant=='jpeg' else encode(changed)
    basis=search.compare(search.fingerprint(encode(original)),search.fingerprint(content))
    assert basis==('same saved photo' if variant=='exact' else 'possible saved-photo match')


def test_unrelated_photos_and_uniform_backgrounds_are_not_similar():
    first=search.fingerprint(encode(scene()))
    for seed in range(2,25):
        assert search.compare(first,search.fingerprint(encode(scene(seed)))) is None
    assert search.compare(search.fingerprint(encode(Image.new('RGB',(64,64),'white'))),search.fingerprint(encode(Image.new('RGB',(32,32),'white')))) is None


@pytest.mark.parametrize('url',[
    'https://evil.test/storage/v1/object/public/item-images/'+PATH,
    'http://169.254.169.254/latest/meta-data',
    'https://[broken-host/photo.jpg',
    URL.replace('item-images','documents'), URL.replace('later.jpg','../secret.jpg'),
    URL.replace('later.jpg','%252e%252e/secret.jpg'),
    URL.replace('https://','https://user:pass@'),
])
def test_foreign_or_malformed_urls_never_become_storage_paths(url):
    assert search.storage_path(url) is None


def test_known_private_locator_maps_without_fetching_arbitrary_url():
    assert search.storage_path(URL)==PATH
    assert search.storage_path(URL.replace('/storage/', '//storage/'))==PATH
    assert search.storage_path(URL.replace('/public/','/sign/')+'?token=old')==PATH


class Query:
    def __init__(self, rows, calls, name): self.rows,self.calls,self.name=rows,calls,name;self.ids=None
    def select(self,*a):return self
    def in_(self,key,ids):self.ids=ids;self.calls.append((self.name,key,ids));return self
    def eq(self,key,value):assert (key,value)==('event_type','photo');return self
    def order(self,*a):return self
    def range(self,*a):return self
    def execute(self):return SimpleNamespace(data=[r for r in self.rows if r['item_id'] in self.ids])


def test_live_gallery_includes_late_photos_and_ignores_deleted_and_foreign_items():
    calls=[]
    items=[{'item_id':'part','image_url':URL}]
    events=[{'item_id':'part','image_url':URL.replace('later','second')},
            {'item_id':'foreign','image_url':URL.replace('later','private')},
            {'item_id':'deleted','image_url':URL.replace('later','deleted')}]
    client=SimpleNamespace(table=lambda name:Query(items if name=='items' else events,calls,name))
    with patch.object(search,'get_supabase_admin',return_value=client):
        refs=search.references([ITEM,{'item_id':'deleted','image_url':URL}])
    assert refs==[('part',PATH),('part',PATH.replace('later','second'))]
    assert calls[-1]==('item_events','item_id',['part'])


def test_photo_attached_after_creation_matches_even_when_item_name_differs():
    pixels=search.fingerprint(encode(scene()))
    with patch.object(search,'references',return_value=[('part',PATH)]),patch.object(search,'_load',return_value=pixels),patch.object(search,'_authorized',return_value=True):
        result=run()
    assert result['complete'] is True
    assert result['matches']==[{'item_id':'part','match_basis':'same saved photo'}]
    evidence=ask.photo_evidence(identified=[{'name':'hex bolt'}],inventory=[ITEM],photo_url=URL,saved_photos=result)
    assert evidence['observations'][0]['matches']==[]
    assert evidence['inventory_matches'][0]['name']=='PN-F117'
    assert evidence['answer_context']['rows'][0]['id']=='part'
    assert evidence['inventory_changed'] is False


@pytest.mark.parametrize('kind',['photo_deleted','item_deleted','permission_revoked'])
def test_removed_or_revoked_photo_is_not_returned_even_during_search(kind):
    pixels=search.fingerprint(encode(scene()))
    refs=[[('part',PATH)],[] if kind!='permission_revoked' else [('part',PATH)]]
    with patch.object(search,'references',side_effect=refs),patch.object(search,'_load',return_value=pixels),patch.object(search,'_authorized',return_value=kind!='permission_revoked'):
        assert run()['matches']==[]


def test_actor_identity_not_inventory_owner_is_used_for_private_photo_access():
    token=request_actor.set(ActorAccess('viewer'))
    try:
        with patch.object(search,'references',return_value=[('part',PATH)]),patch.object(search,'_load',return_value=None) as load:
            result=run()
        load.assert_called_once_with('viewer',PATH)
        assert result['complete'] is False
    finally:request_actor.reset(token)


def test_permission_is_rechecked_on_cached_pixels_and_no_download_after_revocation():
    bucket=Mock();bucket.download.return_value=encode(scene())
    client=Mock();client.storage.from_.return_value=bucket
    with patch.object(search,'get_supabase_raw',return_value=client),patch.object(search,'_authorized',side_effect=[True,True,False]) as allowed:
        assert search._load('viewer',PATH)
        assert search._load('viewer',PATH)
        assert search._load('viewer',PATH) is None
    assert allowed.call_count==3
    bucket.download.assert_called_once_with(PATH)


def test_no_gallery_results_cached_so_added_photos_are_found_next_question():
    pixels=search.fingerprint(encode(scene()))
    with patch.object(search,'references',side_effect=[[],[('part',PATH)],[('part',PATH)]]),patch.object(search,'_load',return_value=pixels),patch.object(search,'_authorized',return_value=True):
        assert run()['matches']==[]
        assert run()['matches'][0]['item_id']=='part'


@pytest.mark.parametrize('failure',[RuntimeError('private database failure'),None])
def test_unavailable_photos_are_reported_as_incomplete_not_missing(failure):
    with patch.object(search,'references',side_effect=failure,return_value=[('part',PATH)]),patch.object(search,'_load',return_value=None):
        result=run()
    assert result['complete'] is False
    assert result['matches']==[]
    assert 'private' not in str(result)


def test_deadline_and_limit_do_not_claim_all_photos_checked():
    def slow(*args):time.sleep(.05);return None
    with patch.object(search,'references',return_value=[('part',PATH),('part',PATH+'2')]),patch.object(search,'_load',side_effect=slow),patch.object(search,'SEARCH_SECONDS',.005),patch.object(search,'MAX_PHOTOS',1):
        result=run()
    assert result['photos_available']==2 and result['complete'] is False


def test_no_inventory_does_not_fetch_storage_or_database():
    with patch.object(search,'get_supabase_admin') as client:
        result=asyncio.run(search.search_saved_photos(user_id='actor',image_bytes=encode(scene()),inventory=[]))
    client.assert_not_called()
    assert result['complete'] is True


@pytest.mark.parametrize('content',[b'not an image',b'x'*(search.MAX_BYTES+1)])
def test_invalid_and_oversize_images_rejected(content):
    with pytest.raises((ValueError,OSError)): search.fingerprint(content)

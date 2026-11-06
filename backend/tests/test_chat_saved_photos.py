from contextlib import contextmanager
from unittest.mock import Mock, patch
import io
import json
from types import SimpleNamespace as NS
from PIL import Image
import pytest
from fastapi import HTTPException
from app.services import chat_saved_photos as photos, world_chat as world
from backend.tests.test_world_chat import ACTOR, WORLD, INVENTORY, completion

ITEM = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

@contextmanager
def inventory(*args):
    yield {'owner_user_id': ACTOR}


def test_gallery_pixels_are_read_even_when_label_conflicts_and_never_written():
    image = io.BytesIO()
    Image.new('RGB', (1600, 800), 'blue').save(image, 'PNG')
    db = Mock()
    db.storage.from_.return_value.download.return_value = image.getvalue()
    gallery = ({'item_id': ITEM, 'name': 'Shaft'}, [{'image_url': 'saved'}])
    with patch.object(world, 'in_inventory', inventory), patch.object(world, 'inventory_scope'), \
         patch('app.services.item_photos.list_item_photos', return_value=gallery), \
         patch('app.services.saved_photo_search.storage_path', return_value='owner/file.jpg'), \
         patch('app.services.saved_photo_search._authorized', return_value=True), \
         patch('app.services.supabase_client.get_supabase_raw', return_value=db):
        result = photos.inspect_item(ACTOR, WORLD, {'inventory_id': INVENTORY, 'item_id': ITEM})
    assert result['items'][0]['name'] == 'Shaft'
    assert result['photos_shown'] == 1 and result['complete']
    assert result['_image_parts'][0]['image_url']['url'].startswith('data:image/jpeg;base64,')
    db.table.assert_not_called()
    db.rpc.assert_not_called()


def test_forbidden_inventory_never_downloads_gallery():
    with patch.object(world, 'in_inventory', side_effect=HTTPException(403, 'denied')), \
         patch('app.services.item_photos.list_item_photos') as gallery:
        with pytest.raises(HTTPException):
            photos.inspect_item(ACTOR, WORLD, {'inventory_id': INVENTORY, 'item_id': ITEM})
    gallery.assert_not_called()


def test_removed_gallery_image_is_not_sent_to_model():
    image = io.BytesIO(); Image.new('RGB', (20, 20)).save(image, 'PNG')
    db = Mock(); db.storage.from_.return_value.download.return_value = image.getvalue()
    with patch.object(world, 'in_inventory', inventory), patch.object(world, 'inventory_scope'), \
         patch('app.services.item_photos.list_item_photos', side_effect=[({'item_id': ITEM}, [{'image_url': 'saved'}]), ({'item_id': ITEM}, [])]), \
         patch('app.services.saved_photo_search.storage_path', return_value='owner/file.jpg'), \
         patch('app.services.saved_photo_search._authorized', return_value=True), \
         patch('app.services.supabase_client.get_supabase_raw', return_value=db):
        result = photos.inspect_item(ACTOR, WORLD, {'inventory_id': INVENTORY, 'item_id': ITEM})
    assert result['_image_parts'] == [] and not result['complete']


def test_gallery_tool_passes_multimodal_pixels_not_base64_tool_text():
    args = {'inventory_id': INVENTORY, 'item_id': ITEM}
    call = NS(id='photo', function=NS(name='world_compare_item_photo', arguments=json.dumps(args)))
    first = NS(choices=[NS(message=NS(content='', tool_calls=[call]))])
    seen = []
    def gateway(**kwargs):
        seen.append(json.loads(json.dumps(kwargs['messages'])))
        return first if len(seen) == 1 else completion('The saved photo matches; its label conflicts.')
    part = {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,cGl4ZWxz'}}
    with patch.object(world, 'authorize'), patch('app.services.agent_gateway_client.gateway_completion', side_effect=gateway), \
         patch('app.services.chat_saved_photos.inspect_item', return_value={'items': [], 'photos_shown': 1, '_image_parts': [part]}):
        events = list(world.stream_turn(ACTOR, WORLD, 'Compare its saved image', [], 'cid'))
    assert events[-1]['type'] == 'done'
    assert seen[-1][-1]['content'][-1] == part
    tool = next(m for m in seen[-1] if m['role'] == 'tool')
    assert 'base64' not in tool['content']

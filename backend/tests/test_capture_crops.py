"""Exercise the documented FIND crop contract independently of identity certainty."""
from io import BytesIO
from unittest.mock import patch

import httpx
import pytest
from PIL import Image, ImageDraw

from app.services.find_pipeline import FindPipelineClient, _crop_from_box
from app.services.storage import StoredImage


def scene():
    image = Image.new('RGB', (400, 240), 'blue')
    ImageDraw.Draw(image).rectangle((280, 100, 359, 199), fill='red')
    output = BytesIO()
    image.save(output, 'PNG')
    return output.getvalue()


def close_up():
    output = BytesIO()
    Image.new('RGB', (40, 70), 'green').save(output, 'JPEG')
    return output.getvalue()


def test_bbox_is_width_height_and_scaled_from_the_stored_frame():
    crop = _crop_from_box(scene(), {'bbox': [140, 50, 40, 50]}, frame_size=(200, 120))
    image = Image.open(BytesIO(crop))
    assert image.size == (80, 100)
    red, green, blue = image.getpixel((40, 50))
    assert red > 200 and green < 30 and blue < 30


@pytest.mark.parametrize('bbox', [[140, 50, 0, 50], [140, 50, -2, 50], [float('nan'), 2, 4, 6], [1, 2, float('inf'), 4], [500, 300, 30, 40], ['bad', 1, 2, 3]])
def test_invalid_or_empty_boxes_do_not_invent_a_crop(bbox):
    assert _crop_from_box(scene(), {'bbox': bbox}) is None


def test_legacy_named_corners_remain_supported():
    crop = _crop_from_box(scene(), {'bounding_box': {'x_min': 280, 'y_min': 100, 'x_max': 360, 'y_max': 200}})
    assert Image.open(BytesIO(crop)).size == (80, 100)


@pytest.fixture
def anyio_backend():
    # FastAPI already installs AnyIO; CI must not require an undeclared plugin.
    return 'asyncio'


@pytest.mark.anyio
@pytest.mark.parametrize('crop_response', ['valid', 'missing', 'invalid', 'timeout'])
async def test_unknown_detection_keeps_its_persisted_crop_before_job_cleanup(crop_response):
    calls, stored = [], []
    item = {'item_id': 'it_0007', 'bbox': [140, 50, 40, 50], 'low_confidence': True,
            'identity': {'name': 'unknown', 'confidence': 0.1, 'unknown': True}}

    async def handle(request):
        calls.append((request.method, request.url.path))
        if request.method == 'DELETE':
            assert stored, 'The crop must outlive the temporary FIND job'
            return httpx.Response(204)
        if request.url.path.endswith('/crop.jpg'):
            assert request.url.path == '/v1/jobs/job_fixture/items/it_0007/crop.jpg'
            assert dict(request.url.params) == {'crop_max': '1024', 'masked': 'true'}
            assert request.headers['authorization'] == 'Bearer fixture-key'
            if crop_response == 'timeout':
                raise httpx.ReadTimeout('fixture only')
            return httpx.Response(404 if crop_response == 'missing' else 200,
                                  content=close_up() if crop_response == 'valid' else b'not an image')
        if request.url.path.endswith('/result'):
            return httpx.Response(200, json={'width': 200, 'height': 120, 'items': [item]})
        if request.method == 'POST':
            return httpx.Response(202, json={'job_id': 'job_fixture'})
        return httpx.Response(200, json={'done': True})

    def persist(**kwargs):
        assert kwargs['user_id'] == 'fixture-user'
        stored.append(kwargs['content'])
        return StoredImage('fixture-user/close-up.jpg', 'https://storage.test/close-up.jpg')

    async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as http:
        pipeline = FindPipelineClient(base_url='https://find.test', api_key='fixture-key', client=http)
        with patch('app.services.find_pipeline.upload_image', side_effect=persist):
            result = await pipeline.extract(filename='fixture.png', image_bytes=scene(), user_id='fixture-user',
                                            source_frame_url='https://storage.test/source.jpg')
    saved = result['items'][0]
    assert saved['image_url'] == 'https://storage.test/close-up.jpg'
    assert saved['source_frame_url'] == 'https://storage.test/source.jpg'
    assert saved['scan_evidence']['needs_review'] is True
    assert saved['confidence'] == 0.1
    assert Image.open(BytesIO(stored[0])).size == ((40, 70) if crop_response == 'valid' else (80, 100))
    assert calls[-1] == ('DELETE', '/v1/jobs/job_fixture')

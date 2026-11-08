"""Regular scans read whole crops promptly without changing result semantics."""
import io
import json
import threading
from unittest.mock import patch

import httpx
import pytest
from PIL import Image

from app.services import glm_extraction as g


@pytest.mark.parametrize('count', [1, 4, 8, 9])
def test_whole_crops_bounded_workers_and_stable_items(count):
    image = Image.new('RGB', (100 * count, 1600), 'red')
    content = io.BytesIO()
    image.save(content, format='JPEG')
    boxes = [g.Box(label=f'tool {i}', box=[i * 1000 // count, 0,
              (i + 1) * 1000 // count, 1000]) for i in range(count)]
    active = peak = entered = 0
    seen = []
    lock = threading.Lock()
    barrier = threading.Barrier(4, timeout=2) if count >= 4 else None

    def model(prompt, images, schema):
        nonlocal active, peak, entered
        hints = json.loads(prompt.split('candidate hints: ', 1)[1].split('. Return', 1)[0])
        with Image.open(io.BytesIO(images[0])) as crop:
            # One crop keeps 1280px detail; pairs retain the old contact sheet.
            assert crop.height == (1280 if len(hints) == 1 else 680)
        with lock:
            active += 1
            entered += 1
            first_wave = entered <= 4
            peak = max(peak, active)
            seen.append(len(hints))
        try:
            if barrier and first_wave:
                barrier.wait()
            return g.Identities(items=[g.Identity(
                index=h['index'], name=h['candidate'], category='Tools',
                identity_confidence=.95, quantity=1,
                quantity_basis='visible_individuals', quantity_confidence=.95,
                uncertainty='Check the visible markings.') for h in reversed(hints)])
        finally:
            with lock:
                active -= 1

    events = []
    with patch.object(g, '_ground_photo', return_value=g.Grounding(items=boxes, partial=False)), \
         patch.object(g, '_json', side_effect=model):
        result = g.extract(content.getvalue(), None, None, on_regions=events.append)
    assert [item['name'] for item in result['items']] == [f'tool {i}' for i in range(count)]
    assert len(result['items']) == count and not result['summary']['partial']
    assert peak == min(4, count)
    assert sorted(seen) == ([1] * count if count <= 4 else ([1] if count % 2 else []) + [2] * (count // 2))
    assert len(events[0]['regions']) == count


def test_small_scan_failed_crop_does_not_discard_its_neighbors():
    image = Image.new('RGB', (600, 600), 'white')
    content = io.BytesIO()
    image.save(content, format='JPEG')
    boxes = [g.Box(label=name, box=bounds) for name, bounds in [
        ('Hammer', [0, 0, 400, 1000]), ('Pliers', [600, 0, 1000, 1000])]]
    def model(prompt, images, schema):
        if 'Pliers' in prompt:
            raise httpx.ReadTimeout('private upstream failure')
        return g.Identities(items=[g.Identity(index=0, name='Hammer', category='Tools',
            identity_confidence=.95, uncertainty='Check markings.')])
    with patch.object(g, '_ground_photo', return_value=g.Grounding(items=boxes, partial=False)), \
         patch.object(g, '_json', side_effect=model):
        result = g.extract(content.getvalue(), None, None)
    assert [item['name'] for item in result['items']] == ['Hammer', 'Unknown item']
    assert result['summary']['partial'] and result['summary']['unknown_count'] == 1
    assert 'private upstream failure' not in str(result)

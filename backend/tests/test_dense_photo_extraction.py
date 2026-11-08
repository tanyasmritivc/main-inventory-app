"""Crowded-photo coverage, source coordinates, deduplication and honest counts."""
import io
import threading
import time
from unittest.mock import patch

import httpx
import pytest
from PIL import Image

from app.services import glm_extraction as g


def box(label, bounds, **kw):
    return g.Box(label=label, box=bounds, **kw)


@pytest.mark.parametrize('size', [(4032, 3024), (3024, 4032), (2048, 2048)])
def test_overlapping_views_cover_original_edges_and_interiors(size):
    windows = g._detail_windows(*size)
    assert 4 <= len(windows) <= 6
    for x in range(0, size[0], 31):
        for y in range(0, size[1], 31):
            assert any(l <= x < r and t <= y < b for l, t, r, b in windows)
    assert max(r for _, _, r, _ in windows) == size[0]
    assert max(b for _, _, _, b in windows) == size[1]
    assert any(g._overlap(a, b)[0] > 0 for a in windows for b in windows if a != b)


def test_local_boxes_map_to_oriented_source_and_mark_cut_interior_edges():
    mapped, cut = g._map_window(box('gear', [100, 200, 900, 800]),
                                (1000, 500, 2000, 1500), (4000, 3000))
    assert mapped.box == [275, 233, 475, 434]
    assert not cut and not mapped.occluded
    mapped, cut = g._map_window(box('spring', [0, 0, 1000, 1000]),
                                (1000, 500, 2000, 1500), (4000, 3000))
    assert cut and mapped.occluded
    _, cut = g._map_window(box('whole image', [0, 0, 1000, 1000]),
                           (0, 0, 4000, 3000), (4000, 3000))
    assert not cut


def test_overlap_dedup_preserves_adjacent_identical_parts_and_best_whole_view():
    whole = box('bolt', [100, 100, 300, 400], detection_confidence=.8)
    adjacent = box('bolt', [320, 100, 520, 400], detection_confidence=.8)
    duplicate = box('metal fastener', [105, 100, 305, 400], detection_confidence=.9)
    cut = box('bolt', [100, 100, 210, 400], detection_confidence=.99, occluded=True)
    result, replaced = g._merge_views(g.Grounding(items=[whole, adjacent], partial=False),
                                      [[(duplicate, False), (cut, True)]])
    assert len(result) == 2 and not replaced
    assert result[0].label == 'metal fastener'
    assert result[1] == adjacent
    assert all(not candidate.occluded for candidate in result)


def test_distinct_overlapping_objects_are_not_merged_by_shared_name_alone():
    a = box('spring', [100, 100, 500, 200])
    b = box('spring', [300, 150, 700, 250])
    result, _ = g._merge_views(g.Grounding(items=[a], partial=False), [[(b, False)]])
    assert len(result) == 2


def test_cross_view_synonyms_and_thin_edge_fragments_do_not_duplicate_an_object():
    mounting_plate = box('silver cast metal mount', [800, 100, 958, 222])
    same_plate = box('silver aluminum hub', [806, 113, 945, 208])
    wheel = box('black plastic sprocket', [303, 123, 480, 255])
    edge = box('black rubber textured wheel', [444, 141, 472, 249], occluded=True)
    result, _ = g._merge_views(g.Grounding(items=[mounting_plate, wheel], partial=False),
                              [[(same_plate, False), (edge, True)]])
    assert len(result) == 2
    assert {tuple(b.box) for b in result} == {tuple(mounting_plate.box), tuple(wheel.box)}


def test_same_view_distinguishable_overlapping_objects_use_stricter_dedup():
    a = box('washer', [100, 100, 300, 300])
    b = box('washer', [130, 100, 330, 300])
    result, _ = g._merge_views(g.Grounding(items=[a, b], partial=False), [])
    assert result == [a, b]


def test_balanced_contained_synonyms_merge_but_small_nested_parts_remain():
    bearing = box('brass flanged ball bearing', [802, 242, 885, 301])
    tighter = box('brass thrust bearing', [817, 245, 877, 291])
    small_part = box('bolt', [820, 250, 830, 260])
    result, _ = g._merge_views(g.Grounding(items=[bearing], partial=False),
                              [[(tighter, False), (small_part, False)]])
    assert result == [bearing, small_part]


def test_resolved_pile_is_not_counted_again_alongside_its_contents():
    pile = box('pile of parts', [0, 0, 800, 800], kind='group', occluded=True)
    gear = box('gear', [100, 100, 300, 300])
    bearing = box('bearing', [400, 400, 500, 500])
    result, replaced = g._merge_views(g.Grounding(items=[pile], partial=True),
                                      [[(gear, False), (bearing, False)]])
    assert replaced and result == [gear, bearing]


def test_dense_scene_uses_original_sections_with_bounded_parallelism():
    active = peak = 0
    lock = threading.Lock()
    image = Image.new('RGB', (2400, 2400), 'red')
    updates = []
    def model(prompt, images, schema):
        nonlocal active, peak
        if 'close-up section' not in prompt:
            return g.Grounding(items=[], partial=False, dense=True)
        with lock:
            active += 1
            peak = max(active, peak)
        try:
            with Image.open(io.BytesIO(images[0])) as tile:
                assert tile.size == (1280, 1280)
                assert not tile.getexif()
            time.sleep(.02)
            return g.Grounding(items=[box('part', [250, 250, 500, 500])], partial=False)
        finally:
            with lock: active -= 1
    with patch.object(g, '_json', side_effect=model) as call:
        result = g._ground_photo(image, updates.append)
    assert call.call_count == 5 and peak == min(4, g.GROUNDING_WORKERS)
    assert len(result.items) == 4
    assert len({tuple(candidate.box) for candidate in result.items}) == 4
    assert result.partial is False
    assert 'Checked 4 of 4 photo sections...' in updates


def test_simple_and_low_resolution_photos_do_not_pay_for_extra_model_calls():
    for size, dense in [((4032, 3024), False), ((1000, 800), True)]:
        overview = g.Grounding(items=[box('tool', [0, 0, 1000, 1000])], partial=False, dense=dense)
        with patch.object(g, '_json', return_value=overview) as call:
            assert g._ground_photo(Image.new('RGB', size), lambda _: None) == overview
        assert call.call_count == 1


def test_failed_closeups_preserve_overview_with_explicit_partial_status():
    overview = g.Grounding(items=[box('wheel', [0, 0, 300, 300])], partial=False, dense=True)
    def model(prompt, *args):
        if 'close-up section' in prompt: raise httpx.ReadTimeout('unavailable')
        return overview
    with patch.object(g, '_json', side_effect=model):
        result = g._ground_photo(Image.new('RGB', (2400, 2400)), lambda _: None)
    assert result.items == overview.items and result.partial


def test_detail_time_is_reserved_and_closeup_deadline_is_shared_not_renewed():
    overview = g.Grounding(items=[], partial=False, dense=True)
    token = g._deadline.set(time.monotonic() + 80)
    try:
        with patch.object(g, '_json', return_value=overview) as call:
            assert g._ground_photo(Image.new('RGB', (2000, 2000)), lambda _: None).partial
        assert call.call_count == 1
    finally:
        g._deadline.reset(token)
    deadlines = []
    total = time.monotonic() + 150
    token = g._deadline.set(total)
    def model(prompt, *args):
        if 'close-up section' in prompt: deadlines.append(g._deadline.get())
        return overview
    try:
        with patch.object(g, '_json', side_effect=model):
            g._ground_photo(Image.new('RGB', (2000, 2000)), lambda _: None)
    finally:
        g._deadline.reset(token)
    assert len(deadlines) == 4 and len(set(deadlines)) == 1
    assert deadlines[0] <= total - g.DETAIL_RESERVE_SECONDS


@pytest.mark.parametrize('kw', [{'occluded': True}, {'kind': 'group'}])
def test_hidden_or_inseparable_counts_stay_unknown_even_after_confident_guess(kw):
    item = g._item(box('fasteners', [0, 0, 1000, 1000], **kw),
                   g.Identity(index=0, name='Screws', category='Hardware', uncertainty='Check.',
                              quantity=150, quantity_basis='visible_individuals', quantity_confidence=.99), None)
    assert item['quantity'] == 1  # Existing contract placeholder; evidence is authoritative.
    assert item['scan_evidence']['quantity_basis'] == 'unknown'
    assert item['scan_evidence']['quantity_confidence'] is None
    assert 'unknown' in item['scan_evidence']['quantity_note']


def test_four_crop_grid_preserves_each_tile_resolution_and_order():
    colours = ['red', 'green', 'blue', 'yellow']
    inputs = []
    for colour in colours:
        data = io.BytesIO()
        Image.new('RGB', (620, 620), colour).save(data, format='PNG')
        inputs.append(data.getvalue())
    with Image.open(io.BytesIO(g._contact_sheet(inputs))) as sheet:
        assert sheet.size == (1280, 1360)
        for i, colour in enumerate(colours):
            expected = Image.new('RGB', (1, 1), colour).getpixel((0, 0))
            observed = sheet.getpixel((640 * (i % 2) + 320, 680 * (i // 2) + 360))
            assert all(abs(a - b) < 5 for a, b in zip(expected, observed))


def test_four_crop_batch_recovers_all_indices_including_second_row():
    payload = {'items': [g.Identity(index=i, name=f'Part {i}', category='Hardware',
                                    uncertainty='Check.').model_dump() for i in [3, 1, 0, 2]]}
    result = g._parse_result(__import__('json').dumps(payload), g.Identities)
    assert {item.index: item.name for item in result.items} == {i: f'Part {i}' for i in range(4)}


def test_portrait_closeups_run_in_one_bounded_wave():
    active = peak = 0
    lock = threading.Lock()
    barrier = threading.Barrier(6, timeout=2)
    def model(prompt, *args):
        nonlocal active, peak
        if 'close-up section' not in prompt:
            return g.Grounding(items=[], partial=False, dense=True)
        with lock:
            active += 1
            peak = max(peak, active)
        try:
            barrier.wait()
            return g.Grounding(items=[], partial=False)
        finally:
            with lock: active -= 1
    with patch.object(g, '_json', side_effect=model):
        g._ground_photo(Image.new('RGB', (3024, 4032)), lambda _: None)
    assert peak == 6

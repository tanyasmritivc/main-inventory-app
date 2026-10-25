import io
import re
from types import SimpleNamespace as NS
from unittest.mock import patch, Mock, AsyncMock
import pytest
from PIL import Image
from app.services import glm_extraction as g
from app.services import photo_extraction as p
from app.schemas.inventory import ExtractedInventoryItem, MultiExtractFromImageResponse


def image_bytes():
    im = Image.new("RGB", (500, 300), "white")
    for x in range(100, 400):
        for y in range(50, 250):
            im.putpixel((x, y), (220, 10, 10))
    out = io.BytesIO()
    im.save(out, format="PNG")
    return out.getvalue()


def identity(**kw):
    return g.Identity(
        index=0,
        name="M3 screws",
        category="Hardware",
        uncertainty="Check thread pitch.",
        **kw
    )


def test_complete_public_contract_and_evidence_without_fabricated_dimensions():
    box = g.Box(label="screws", box=[200, 167, 800, 833], detection_confidence=0.95)
    i = identity(
        subcategory="Fasteners",
        brand="Acme",
        part_number="M3-20",
        tags=["screw"],
        identity_confidence=0.87,
        visible_text="ACME M3-20 20 mm",
        ocr_confidence=0.92,
        length_mm=20,
        width_mm=3,
        measurement_basis="printed_label",
        measurement_quote="20 mm",
        quantity=3,
        quantity_basis="visible_individuals",
        quantity_confidence=0.97,
    )
    item = g._item(box, i, "https://fixture.test/source")
    assert set(ExtractedInventoryItem.model_fields).issubset(item)
    assert (
        item["confidence"] == 0.87 and item["quantity"] == 3 and item["brand"] == "Acme"
    )
    assert (
        item["part_number"] == "M3-20"
        and item["purchase_source"] is None
        and item["location"] is None
    )
    e = item["scan_evidence"]
    assert e["length_mm"] == 20 and e["width_mm"] is None
    assert (
        e["detection_confidence"] == 0.95
        and e["ocr_confidence"] == 0.92
        and e["needs_review"]
    )
    assert "model estimates" in e["warnings"][0]


def test_unsupported_identity_counts_measurements_and_barcodes_remain_unknown():
    item = g._item(
        g.Box(label="bag", box=[0, 0, 1000, 1000]),
        identity(
            brand="Guessed brand",
            part_number="PN123",
            quantity=50,
            quantity_basis="unknown",
            length_mm=120,
            width_mm=30,
            measurement_basis="printed_label",
            measurement_quote="invented 120 mm",
            barcode="1234567890",
            barcode_confidence=0.99,
        ),
        "source",
    )
    assert (
        item["brand"] is None
        and item["part_number"] is None
        and item["barcode"] is None
    )
    assert item["quantity"] == 1
    assert (
        item["scan_evidence"]["length_mm"] is None
        and item["scan_evidence"]["measurement_method"] == "unavailable"
    )
    assert item["scan_evidence"]["barcode_confidence"] is None


@pytest.mark.parametrize("score", [float("nan"), float("inf"), -1, 1.1])
def test_invalid_confidence_is_rejected(score):
    with pytest.raises(ValueError):
        identity(identity_confidence=score)


def test_crop_refinement_has_small_margin_and_preserves_whole_object():
    im = Image.open(io.BytesIO(image_bytes()))
    result = g._final_crop(
        im,
        g.Box(label="object", box=[0, 0, 1000, 1000]),
        identity(refined_box=[200, 167, 800, 833]),
    )
    crop = Image.open(io.BytesIO(result))
    assert crop.size == (312, 208)
    assert crop.getpixel((0, 0))[0] > 230  # clean surrounding margin
    assert crop.getpixel((156, 104))[0] > 190
    assert not crop.getexif()
    with pytest.raises(ValueError):
        g._final_crop(
            im,
            g.Box(label="object", box=[0, 0, 1000, 1000]),
            identity(refined_box=[400, 400, 410, 410]),
        )


def test_all_batches_validate_before_upload_and_preserve_summary():
    boxes = [
        g.Box(
            label=str(i), box=[i * 100, 0, i * 100 + 80, 1000], detection_confidence=0.9
        )
        for i in range(5)
    ]

    def model(prompt, images, schema):
        if schema is g.Grounding:
            return g.Grounding(items=boxes, partial=False)
        indices = [int(value) for value in re.findall(r'"index": (\d+)', prompt)]
        return g.Identities(
            items=[
                g.Identity(
                    index=i,
                    name="Object",
                    category="Tools",
                    uncertainty="Verify.",
                    identity_confidence=0.8,
                )
                for i in indices
            ]
        )

    upload = Mock(
        return_value=NS(path="fixture/crop.jpg", url="https://fixture.test/crop.jpg")
    )
    with patch.object(g, "_json", side_effect=model):
        result = g.extract(image_bytes(), "fixture", "source", upload=upload)
    assert upload.call_count == 5
    assert result["summary"]["categories"] == {"Tools": 5}
    assert (
        MultiExtractFromImageResponse.model_validate(result).summary.total_detected == 5
    )


def test_no_actor_does_not_upload_private_files():
    ground = g.Grounding(
        items=[g.Box(label="tool", box=[0, 0, 1000, 1000])], partial=False
    )
    with patch.object(
        g, "_json", side_effect=[ground, g.Identities(items=[identity()])]
    ), patch("app.services.storage.upload_image") as upload:
        result = g.extract(image_bytes(), None, None)
    upload.assert_not_called()
    assert result["items"][0]["image_url"] is None


def test_provider_switch_has_no_silent_fallback_and_preserves_find():
    import asyncio

    with patch.object(
        p, "get_settings", return_value=NS(findez_extraction_provider="find")
    ), patch.object(
        p,
        "extract_inventory_items_with_find",
        new=AsyncMock(return_value={"items": []}),
    ) as find:
        assert asyncio.run(
            p.extract_inventory_items(filename="photo.jpg", image_bytes=b"x")
        ) == {"items": []}
        find.assert_awaited_once()
    with patch.object(
        p, "get_settings", return_value=NS(findez_extraction_provider="glm")
    ), patch(
        "app.services.glm_extraction.extract",
        side_effect=ValueError("private provider detail"),
    ), patch.object(
        p, "extract_inventory_items_with_find"
    ) as find:
        with pytest.raises(p.PhotoExtractionError) as error:
            asyncio.run(
                p.extract_inventory_items(filename="photo.jpg", image_bytes=b"x")
            )
    assert "private provider detail" not in error.value.public_message
    find.assert_not_called()


def test_exif_orientation_and_metadata_are_normalized_before_model_and_crop():
    im = Image.new("RGB", (80, 40), "red")
    exif = im.getexif()
    exif[274] = 6
    exif[270] = "private camera comment"
    out = io.BytesIO()
    im.save(out, format="JPEG", exif=exif)
    ground = g.Grounding(
        items=[g.Box(label="tool", box=[0, 0, 1000, 1000])], partial=False
    )
    observed = []

    def model(prompt, images, schema):
        scene = Image.open(io.BytesIO(images[0]))
        observed.append(scene.size)
        assert scene.format == "JPEG" and not scene.getexif()
        return ground if schema is g.Grounding else g.Identities(items=[identity()])

    with patch.object(g, "_json", side_effect=model):
        g.extract(out.getvalue(), None, None)
    assert observed == [(40, 80), (40, 80)]


def test_partial_upload_failure_removes_only_new_crop():
    boxes = [
        g.Box(label="a", box=[0, 0, 400, 1000]),
        g.Box(label="b", box=[600, 0, 1000, 1000]),
    ]
    ids = [g.Identities(items=[identity(), identity().model_copy(update={"index": 1})])]
    with patch.object(
        g, "_json", side_effect=[g.Grounding(items=boxes, partial=False), *ids]
    ), patch(
        "app.services.storage.upload_image",
        side_effect=[
            NS(path="actor/new.jpg", url="https://fixture/new.jpg"),
            RuntimeError("upload failed"),
        ],
    ), patch(
        "app.services.storage.delete_image"
    ) as delete:
        with pytest.raises(RuntimeError):
            g.extract(image_bytes(), "actor", "https://fixture/source.jpg")
    delete.assert_called_once_with(path="actor/new.jpg")


def test_expired_budget_makes_no_provider_request():
    token = g._deadline.set(0.1)
    try:
        with patch.object(g, "gateway_completion") as call:
            with pytest.raises(TimeoutError):
                g._json("test", [image_bytes()], g.Grounding)
        call.assert_not_called()
    finally:
        g._deadline.reset(token)


def test_partial_part_number_is_not_accepted_from_a_longer_label():
    item = g._item(
        g.Box(label="part", box=[0, 0, 1000, 1000]),
        identity(part_number="PN-F1", visible_text="PN-F156"),
        None,
    )
    assert item["part_number"] is None


def test_network_timeout_does_not_retry_an_inflight_paid_request():
    import httpx

    with patch.object(
        g, "gateway_completion", side_effect=httpx.ReadTimeout("timeout")
    ) as call:
        with pytest.raises(httpx.ReadTimeout):
            g._json("test", [image_bytes()], g.Grounding)
    assert call.call_count == 1


def test_one_failed_batch_is_explicit_unknown_partial_not_lost():
    import httpx
    boxes = [g.Box(label=name, box=coords) for name, coords in [
        ('pliers', [0, 0, 300, 1000]), ('hammer', [350, 0, 600, 1000]),
        ('bag', [650, 0, 1000, 1000])]]
    def model(prompt, images, schema):
        if schema is g.Grounding:
            return g.Grounding(items=boxes, partial=False)
        if '"candidate": "bag"' in prompt:
            raise httpx.ReadTimeout('gateway')
        return g.Identities(items=[identity(identity_confidence=.8),
                                  identity(identity_confidence=.8).model_copy(update={'index': 1})])
    with patch.object(g, '_json', side_effect=model):
        result = g.extract(image_bytes(), None, None)
    assert len(result['items']) == 3 and result['summary']['partial']
    unknown = result['items'][2]
    assert unknown['name'] == 'Unknown item' and unknown['confidence'] is None
    assert unknown['scan_evidence']['needs_review']
    assert result['summary']['unknown_count'] == 1
    assert any('partial extraction' in r for r in result['items'][0]['scan_evidence']['review_reasons'])


def test_all_identity_failures_return_error_instead_of_success():
    import httpx

    ground = g.Grounding(
        items=[g.Box(label="bag", box=[0, 0, 1000, 1000])], partial=False
    )
    with patch.object(g, "_json", side_effect=[ground, httpx.ReadTimeout("gateway")]):
        with pytest.raises(ValueError, match="No detected object"):
            g.extract(image_bytes(), None, None)


def test_nullable_optional_prose_and_unknown_count_do_not_discard_an_object():
    item = identity(
        visible_text=None,
        notes=None,
        tags=None,
        quantity=None,
        quantity_basis="visible_individuals",
        quantity_confidence=0.99,
    )
    assert item.visible_text == "" and item.notes == "" and item.tags == []
    assert (
        item.quantity == 1
        and item.quantity_basis == "unknown"
        and item.quantity_confidence is None
    )
    long = identity(notes="x" * 2000)
    assert len(long.notes) == 1000


def test_low_confidence_guess_is_an_unknown_candidate_not_a_named_item():
    item = g._item(
        g.Box(label="fragment", box=[0, 0, 1000, 1000]),
        g.Identity(
            index=0,
            name="Carrot",
            category="Food",
            tags=["vegetable"],
            identity_confidence=0.4,
            uncertainty="Could be an orange plastic handle.",
        ),
        None,
    )
    assert item["name"] == "Unknown item" and item["category"] == "Uncategorized"
    assert item["tags"] == [] and item["confidence"] == 0.4
    assert "Possible description, not verified: Carrot" in item["notes"]


def test_unidentifiable_object_can_return_null_name_and_category():
    row = g.Identity(
        index=0,
        name=None,
        category=None,
        identity_confidence=0.1,
        uncertainty="Only an edge fragment is visible.",
    )
    assert row.name == "Unknown item" and row.category == "Uncategorized"


@pytest.mark.parametrize(
    "quote,length,width,expected",
    [
        ("M3x20mm", 20, 3, (20, None)),
        ("2 cm x 30 mm", 20, 30, (20, 30)),
        ("20×30mm", 20, 30, (20, 30)),
        ("1/4in", 101.6, None, (None, None)),
        ("PN-F156 20mm", 156, 20, (None, 20)),
    ],
)
def test_dimensions_are_bound_to_their_own_printed_units(
    quote, length, width, expected
):
    value = g._item(
        g.Box(label="part", box=[0, 0, 1000, 1000]),
        identity(
            visible_text=quote,
            measurement_quote=quote,
            measurement_basis="printed_label",
            length_mm=length,
            width_mm=width,
        ),
        None,
    )["scan_evidence"]
    assert (value["length_mm"], value["width_mm"]) == expected


def test_real_work_stages_are_reported_in_order_without_provider_content():
    statuses = []
    box = g.Box(label='private label', box=[0, 0, 1000, 1000])
    with patch.object(g, '_json', side_effect=lambda prompt, images, schema:
                      g.Grounding(items=[box], partial=False) if schema is g.Grounding
                      else g.Identities(items=[identity()])):
        g.extract(image_bytes(), None, None, on_progress=statuses.append)
    assert statuses[0] == 'Finding objects in your photo…'
    assert 'Checked 1 of 1 objects…' in statuses
    assert statuses[-1] == 'Preparing your editable draft…'
    assert 'private label' not in str(statuses)


def test_two_crop_sheet_is_single_image_and_maps_reversed_indices_safely():
    boxes = [g.Box(label='red', box=[0, 0, 400, 1000]), g.Box(label='blue', box=[600, 0, 1000, 1000])]
    calls = []
    def model(prompt, images, schema):
        calls.append(schema)
        assert len(images) == 1
        if schema is g.Grounding:
            return g.Grounding(items=boxes, partial=False)
        assert Image.open(io.BytesIO(images[0])).size == (1280, 680)
        return g.Identities(items=[identity(identity_confidence=.9).model_copy(update={'index': 1, 'name': 'Blue tool'}),
                                  identity(identity_confidence=.9).model_copy(update={'name': 'Red tool'})])
    with patch.object(g, '_json', side_effect=model):
        result = g.extract(image_bytes(), None, None)
    assert [i['name'] for i in result['items']] == ['Red tool', 'Blue tool']
    assert len(calls) == 2


def test_duplicate_batch_indices_cannot_assign_an_identity_to_the_wrong_crop():
    boxes = [g.Box(label='a', box=[0, 0, 400, 1000]), g.Box(label='b', box=[600, 0, 1000, 1000])]
    with patch.object(g, '_json', side_effect=[g.Grounding(items=boxes, partial=False),
                                              g.Identities(items=[identity(), identity()])]):
        with pytest.raises(ValueError, match='No detected object'):
            g.extract(image_bytes(), None, None)


def test_pile_is_not_one_unit_even_when_model_confidence_is_high():
    box = g.Box(label='resistor pile', box=[0, 0, 1000, 1000])
    item = g._item(box, g.Identity(index=0, name='Resistor pile', category='Electronics', uncertainty='Count uncertain',
        quantity=1, quantity_basis='visible_individuals', quantity_confidence=.99), 'source')
    assert item['scan_evidence']['quantity_basis'] == 'unknown'
    counted = g._item(box, g.Identity(index=0, name='Resistors', category='Electronics', uncertainty='Review',
        quantity=6, quantity_basis='visible_individuals', quantity_confidence=.99), 'source')
    assert counted['quantity'] == 6
    assert counted['scan_evidence']['quantity_basis'] == 'visible_individuals'


def test_same_marked_bars_group_without_losing_crop_or_count_and_piles_do_not():
    image = Image.new('RGB', (1000, 1000), 'white')
    boxes = [g.Box(label='bar', box=[100,100,400,400]), g.Box(label='bar', box=[450,100,750,400])]
    def prepared(text='CADBURY 5 STAR 40g', basis='visible_individuals'):
        result = []
        for box in boxes:
            item = g._item(box, g.Identity(index=0, name='Cadbury 5 Star 40g', category='Food', uncertainty='Review',
                brand='Cadbury', visible_text=text, identity_confidence=.98,
                quantity=1, quantity_basis=basis, quantity_confidence=.97), 'source')
            result.append((item, b'crop'))
        return result
    grouped = g._group_identical(image, [(b,b'') for b in boxes], prepared())
    assert len(grouped) == 1 and grouped[0][0]['quantity'] == 2
    assert grouped[0][0]['scan_evidence']['grouped_observations'] == 2
    rows = prepared()
    rows[1][0]['scan_evidence']['warnings'] = ['Second wrapper is partly obscured.']
    merged = g._group_identical(image, [(b,b'') for b in boxes], rows)
    assert 'Second wrapper is partly obscured.' in merged[0][0]['scan_evidence']['warnings']
    assert Image.open(io.BytesIO(grouped[0][1])).width > 650
    assert len(g._group_identical(image, [(b,b'') for b in boxes], prepared(basis='unknown'))) == 2
    different = prepared(); different[1][0]['scan_evidence']['ocr_text'] = 'CADBURY 5 STAR 20g'
    assert len(g._group_identical(image, [(b,b'') for b in boxes], different)) == 2
    overlapping = [(boxes[0],b''), (boxes[0],b'')]
    assert len(g._group_identical(image, overlapping, prepared())) == 2

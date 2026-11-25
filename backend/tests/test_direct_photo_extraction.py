import base64
import io
import json
from types import SimpleNamespace as NS
from unittest.mock import patch

import pytest
from PIL import Image

from app.services import direct_photo_extraction as direct
from app.schemas.inventory import ExtractedInventoryItem


def photo():
    im = Image.new("RGB", (80, 40), "red")
    exif = im.getexif()
    exif[274] = 6
    exif[270] = "private camera metadata"
    out = io.BytesIO()
    im.save(out, format="JPEG", exif=exif)
    return out.getvalue()


def row(**changes):
    value = {"name": "Black screws", "category": "Hardware", "quantity": 11,
            "quantity_basis": "estimated_visible", "quantity_note": "About 10–12 visible, overlapping.",
            "confidence": 0.8, "box": [0, 0, 1000, 1000], **changes}
    count = "unknown" if value["quantity"] is None else "about 10–12" if value["quantity_basis"] == "estimated_visible" else str(value["quantity"])
    value.setdefault("evidence_quote", value["name"] + " | " + count + " | Overlapping in tray")
    return value


def stream(data, finish="stop"):
    text = data if isinstance(data, str) else json.dumps(data)
    yield NS(choices=[NS(delta=NS(content=text[:20]), finish_reason=None)])
    yield NS(choices=[NS(delta=NS(content=text[20:]), finish_reason=finish)])


def responses(data):
    description = "\n".join("ITEM: " + r["evidence_quote"] for r in data["items"])
    return [stream(description), stream(data)]


def test_one_full_photo_stream_has_chat_vision_settings_and_preserves_estimates():
    with patch.object(direct, "get_settings", return_value=NS(findez_chat_vision_model="configured-vision")), \
         patch.object(direct, "gateway_completion", side_effect=responses({"items": [row()], "partial": False})) as call:
        result = direct.extract(photo(), None, "source")
    assert call.call_count == 2
    assert isinstance(call.call_args_list[1].kwargs["messages"][1]["content"], str)
    args = call.call_args_list[0].kwargs
    assert args["model"] == "configured-vision" and args["stream"] is True
    assert args["tools"] == [] and args["options"] == {"enabled_tools": [], "max_steps": 1}
    assert args["max_tokens"] == 8192 and args["request_timeout_seconds"] == 110
    content = args["messages"][0]["content"]
    assert len(content) == 2
    encoded = content[1]["image_url"]["url"].split(",", 1)[1]
    with Image.open(io.BytesIO(base64.b64decode(encoded))) as image:
        assert image.size == (40, 80) and not image.getexif()
    item = result["items"][0]
    ExtractedInventoryItem.model_validate(item)
    assert item["quantity"] == 10 and "10–12" in item["scan_evidence"]["quantity_note"]
    assert item["scan_evidence"]["quantity_basis"] == "estimated_visible"
    assert item["scan_evidence"]["quantity_confidence"] is None
    assert item["scan_evidence"]["needs_review"] and item["location"] is None


@pytest.mark.parametrize("finish", [None, "length", "content_filter", "tool_calls"])
def test_incomplete_stream_never_becomes_a_successful_draft(finish):
    with patch.object(direct, "gateway_completion", return_value=stream({"items": [row()]}, finish)), \
         pytest.raises(ValueError):
        direct._read_photo(b"jpeg")


def test_tools_rejected_and_stream_closed():
    closed = []
    def generated():
        try:
            yield NS(choices=[NS(delta=NS(tool_calls=[NS()]), finish_reason=None)])
        finally:
            closed.append(True)
    with patch.object(direct, "gateway_completion", return_value=generated()), pytest.raises(ValueError):
        direct._read_photo(b"jpeg")
    assert closed == [True]


def test_invalid_geometry_retains_identity_with_source_image_and_invalid_row_marks_partial():
    payload = {"items": [row(box=[0.1, 0.2, 0.4, 0.5]), row(name="")], "partial": False}
    with patch.object(direct, "gateway_completion", side_effect=responses(payload)):
        result = direct.extract(photo(), None, "source")
    assert len(result["items"]) == 1 and result["summary"]["partial"]
    assert "Whole source photo" in result["items"][0]["scan_evidence"]["warnings"][0]


def test_two_item_types_in_same_bin_are_not_deduplicated_by_box():
    payload = {"items": [row(name="Black screws"), row(name="Silver washers")], "partial": False}
    with patch.object(direct, "gateway_completion", side_effect=responses(payload)):
        result = direct.extract(photo(), None, None)
    assert [item["name"] for item in result["items"]] == ["Black screws", "Silver washers"]


def test_whole_photo_rows_reuse_the_authorized_source_without_duplicate_uploads():
    payload = {"items": [row(box=None), row(name="Washers", box=None)], "partial": False}
    with patch.object(direct, "gateway_completion", side_effect=responses(payload)), \
         patch("app.services.storage.upload_image") as upload:
        result = direct.extract(photo(), "actor", "owned-source")
    upload.assert_not_called()
    assert all(item["image_url"] == "owned-source" for item in result["items"])


def test_unknown_count_and_guessed_markings_do_not_become_inventory_facts():
    payload = {"items": [row(quantity=None, quantity_basis="unknown", brand="Guess", part_number="Fake123")], "partial": False}
    with patch.object(direct, "gateway_completion", side_effect=responses(payload)):
        item = direct.extract(photo(), None, None)["items"][0]
    assert item["quantity"] == 1 and item["scan_evidence"]["quantity_basis"] == "unknown"
    assert item["brand"] is None and item["part_number"] is None
    assert item["scan_evidence"]["length_mm"] is None


def test_table_counts_are_read_from_quote_not_formatter_numbers_or_basis():
    rows = [row(name="Wheel", quantity=900, quantity_basis="counted_visible"), row(name="Screws")]
    rows[0]["evidence_quote"] = "Wheel | 1 | On shelf"
    rows[1]["evidence_quote"] = "Screws | ~10–12 | In the bin"
    with patch.object(direct, "gateway_completion", side_effect=responses({"items": rows, "partial": False})):
        items = direct.extract(photo(), None, None)["items"]
    assert [r["quantity"] for r in items] == [1, 10]
    assert [r["scan_evidence"]["quantity_basis"] for r in items] == ["visible_individuals", "estimated_visible"]


def test_only_explicit_auto_extract_uses_new_path():
    import asyncio
    from app.services import photo_extraction
    with patch.object(photo_extraction, "get_settings", return_value=NS(findez_extraction_provider="glm")), \
         patch("app.services.glm_extraction.extract", return_value={"legacy": True}) as legacy, \
         patch.object(direct, "extract", return_value={"direct": True}) as modern:
        assert asyncio.run(photo_extraction.extract_inventory_items(filename="photo", image_bytes=b"x")) == {"legacy": True}
        modern.assert_not_called()
        assert asyncio.run(photo_extraction.extract_inventory_items(filename="photo", image_bytes=b"x", direct_photo=True)) == {"direct": True}
        legacy.assert_called_once()
        modern.assert_called_once()


def test_upload_failure_drains_other_uploads_and_removes_successful_crops():
    payload = {"items": [row(name="first"), row(name="second")], "partial": False}
    def upload(**args):
        if "fail" not in calls:
            calls.append("fail")
            raise RuntimeError("storage unavailable")
        calls.append("ok")
        return NS(url="private-preview", path="owned-crop")
    calls = []
    with patch.object(direct, "gateway_completion", side_effect=responses(payload)), \
         patch("app.services.storage.upload_image", side_effect=upload), \
         patch("app.services.storage.delete_image") as delete, pytest.raises(RuntimeError):
        direct.extract(photo(), "actor", None)
    assert sorted(calls) == ["fail", "ok"]
    delete.assert_called_once_with(path="owned-crop")


@pytest.mark.parametrize("bounds", ["unknown", "", "[0,0,1000,1000]", "[150,40,80,200]",
                                    "[0,0,1100,1000]", "[true,0,5,6]", "[.2,.2,.4,.5]"])
def test_unlocated_row_keeps_authorized_source_even_if_formatter_supplies_a_box(bounds):
    quote = f"Screws | 8 | Top left in the tray | {bounds}".strip()
    payload = {"items": [row(name="Screws", box=[50,50,80,90], evidence_quote=quote)], "partial": False}
    with patch.object(direct, "_stream_text", side_effect=[
            "ITEM: " + quote, json.dumps(payload)]), patch("app.services.storage.upload_image") as upload:
        item, = direct.extract(photo(), "actor", "source")["items"]
    assert item["image_url"] == "source" and item["quantity"] == 8
    upload.assert_not_called()


def test_extraction_uploads_original_pixel_crop_and_retains_source_for_second_slide():
    image = Image.new("RGB", (400, 200), "blue")
    from PIL import ImageDraw
    ImageDraw.Draw(image).rectangle((100, 50, 200, 150), fill="red")
    buffer = io.BytesIO(); image.save(buffer, format="JPEG")
    quote = "Black screws | about 10–12 | Top left | [250,250,500,750]"
    payload = {"items": [row(box=[800,0,1000,200], notes="Top left.", evidence_quote=quote)], "partial": False}
    calls = responses(payload)
    uploaded = []
    def upload(**args):
        uploaded.append(args["content"])
        return NS(url="owned-crop", path="crop-path")
    with patch.object(direct, "gateway_completion", side_effect=calls):
        result = direct.extract(buffer.getvalue(), "actor", "owned-source", upload=upload)
    item = result["items"][0]
    assert item["image_url"] == "owned-crop" and item["source_frame_url"] == "owned-source"
    assert item["quantity"] == 10 and item["scan_evidence"]["quantity_basis"] == "estimated_visible"
    with Image.open(io.BytesIO(uploaded[0])) as crop:
        assert crop.size == (104, 104) and not crop.getexif()
        red, green, blue = crop.getpixel((50, 50))
        assert red > 240 and green < 10 and blue < 10


def test_battery_photo_excludes_the_surface_even_if_formatter_offers_it():
    battery = "BATMAX camera battery | 1 | At center on a white tabletop. Label: 3.7 V."
    surface = "White surface | 1 | Background only."
    payload = {"items": [row(name="BATMAX camera battery", evidence_quote=battery),
                         row(name="White surface", evidence_quote=surface)], "partial": False}
    with patch.object(direct, "_stream_text", side_effect=[
            f"ITEM: {battery}\nCONTEXT: {surface}", json.dumps(payload)]) as model:
        items = direct.extract(photo(), None, None)["items"]
    assert surface not in model.call_args.args[0][1]["content"]
    assert [(item["name"], item["quantity"], item["scan_evidence"]["quantity_basis"])
            for item in items] == [("BATMAX camera battery", 1, "visible_individuals")]


@pytest.mark.parametrize(("count", "expected", "basis"), [
    ("8", 8, "visible_individuals"), ("about 12", 12, "estimated_visible"),
    ("10-15", 10, "estimated_visible"), ("at least 6", 6, "estimated_visible"),
    ("unknown", 1, "unknown"), ("3.7V", 1, "unknown"), ("15-10", 1, "unknown"),
])
def test_screws_in_a_box_keep_location_and_count_evidence(count, expected, basis):
    observed = f"Screws | {count} | Bottom left in a plastic box."
    with patch.object(direct, "_stream_text", side_effect=[
            f"CONTEXT: Plastic box holding screws.\nITEM: {observed}",
            json.dumps({"items": [row(name="Screws", notes="Bottom left in a plastic box.",
                                      evidence_quote=observed)], "partial": False})]):
        result = direct.extract(photo(), None, None)
    item, = result["items"]
    assert (item["name"], item["quantity"], item["scan_evidence"]["quantity_basis"]) == (
        "Screws", expected, basis)
    assert "plastic box" in item["notes"] and item["location"] is None
    assert count in item["scan_evidence"]["quantity_note"]


def test_empty_containers_are_inventory_when_they_are_the_photo_subject():
    quote = "Empty storage bins | 3 | Stack of empty bins for sale."
    with patch.object(direct, "_stream_text", side_effect=[
            "ITEM: " + quote, json.dumps({"items": [row(name="Empty storage bins",
                                                        evidence_quote=quote)], "partial": False})]):
        item, = direct.extract(photo(), None, None)["items"]
    assert (item["name"], item["quantity"]) == ("Empty storage bins", 3)


def test_scene_only_photo_returns_empty_without_a_formatter_call():
    with patch.object(direct, "_stream_text", return_value="CONTEXT: A wall and shadows.\nNO ITEMS") as model:
        assert direct._read_photo(b"test") == ([], False)
    model.assert_called_once()


def test_quantity_cannot_be_upgraded_by_shortening_a_quote():
    quote = "Bolts | about 12 | Overlap."
    with patch.object(direct, "_stream_text", side_effect=[
            "ITEM: " + quote, json.dumps({"items": [row(name="Bolts", evidence_quote="Bolts | 12")],
                                          "partial": False})]), pytest.raises(ValueError):
        direct._read_photo(b"test")


def test_reordered_rows_crop_different_objects_from_the_oriented_source():
    upright = Image.new("RGB", (60, 40), "navy")
    from PIL import ImageDraw
    paint = ImageDraw.Draw(upright)
    paint.rectangle((0, 0, 17, 18), fill="red")
    paint.rectangle((30, 20, 59, 39), fill="lime")
    raw = upright.transpose(Image.Transpose.ROTATE_90)
    exif = raw.getexif()
    exif[274] = 6
    buf = io.BytesIO()
    raw.save(buf, format="JPEG", exif=exif)
    first = "Red item | 1 | On desk | [0,0,300,450]"
    second = "Green item | 1 | On desk | [500,500,1000,1000]"
    payload = {"items": [row(name="Green item", evidence_quote=second),
                         row(name="Red item", evidence_quote=first)], "partial": False}
    uploads = {}

    def store(**args):
        name = args["filename"]
        uploads[name] = args["content"]
        return NS(url=name, path=name)

    with patch.object(direct, "_stream_text", side_effect=[
            f"ITEM: {first}\nITEM: {second}", json.dumps(payload)]):
        result = direct.extract(buf.getvalue(), "actor", "source", upload=store)
    assert result["summary"]["total_detected"] == 2
    for item, channel in zip(result["items"], [1, 0], strict=True):
        assert item["source_frame_url"] == "source"
        with Image.open(io.BytesIO(uploads[item["image_url"]])) as thumb:
            assert thumb.width < upright.width and thumb.height < upright.height
            assert thumb.getpixel((thumb.width // 2, thumb.height // 2))[channel] > 224

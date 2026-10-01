from io import BytesIO
from unittest.mock import patch

import pytest
from fastapi import HTTPException
from PIL import Image

from app.api.routes.items import _prepare_scan_image


def _png(width: int = 2, height: int = 2) -> bytes:
    output = BytesIO()
    Image.new("RGB", (width, height), (20, 30, 40)).save(output, format="PNG")
    return output.getvalue()


def test_prepare_scan_image_accepts_a_valid_photo():
    content = _png()
    prepared, filename = _prepare_scan_image(content, "capture.png")

    assert prepared == content
    assert filename == "capture.png"


def test_prepare_scan_image_rejects_non_image_content():
    with pytest.raises(HTTPException) as raised:
        _prepare_scan_image(b"not an image", "capture.png")

    assert raised.value.status_code == 400


def test_prepare_scan_image_checks_pixel_limit_before_conversion():
    with patch("app.api.routes.items.MAX_SCAN_IMAGE_PIXELS", 1), patch(
        "app.api.routes.items._convert_to_jpeg"
    ) as convert:
        with pytest.raises(HTTPException) as raised:
            _prepare_scan_image(_png(), "capture.heic")

    assert raised.value.status_code == 400
    convert.assert_not_called()

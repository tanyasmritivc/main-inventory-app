import asyncio
import io
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from fastapi import HTTPException, Request, UploadFile
from PIL import Image

from app.api.routes.items import upload_item_photo_route
from app.core.auth import AuthenticatedUser


def _photo() -> UploadFile:
    image = Image.new("RGB", (24, 24), "blue")
    output = io.BytesIO()
    image.save(output, format="PNG")
    return UploadFile(file=io.BytesIO(output.getvalue()), filename="part.png")


def _request() -> Request:
    return Request({"type": "http", "method": "POST", "path": "/items/item-1/photo", "headers": []})


def test_item_photo_requires_edit_access():
    user = AuthenticatedUser(user_id="user-1")
    with patch("app.api.routes.items.authorized_item", side_effect=LookupError):
        with pytest.raises(HTTPException) as error:
            asyncio.run(upload_item_photo_route(_request(), "item-1", _photo(), user))
    assert error.value.status_code == 404


def test_workspace_viewer_cannot_attach_photo():
    user = AuthenticatedUser(
        user_id="user-1", workspace_id="workspace-1", workspace_role="viewer"
    )
    with pytest.raises(HTTPException) as error:
        asyncio.run(upload_item_photo_route(_request(), "item-1", _photo(), user))
    assert error.value.status_code == 403


def test_item_photo_rejects_invalid_image():
    user = AuthenticatedUser(user_id="user-1")
    with patch("app.api.routes.items.authorized_item", return_value={"item_id": "item-1"}):
        with pytest.raises(HTTPException) as error:
            asyncio.run(upload_item_photo_route(
                _request(), "item-1", UploadFile(file=io.BytesIO(b"not a photo")), user
            ))
    assert error.value.status_code == 400


def test_item_photo_updates_existing_object():
    user = AuthenticatedUser(user_id="user-1")
    updated = {"item_id": "item-1", "name": "Part", "image_url": "https://example.test/photo.jpg"}
    with patch("app.api.routes.items.authorized_item", return_value={"item_id": "item-1"}) as authorize, patch(
        "app.api.routes.items.upload_image",
        return_value=SimpleNamespace(url="https://example.test/photo.jpg"),
    ) as upload, patch("app.api.routes.items.update_item", return_value=updated) as save:
        result = asyncio.run(upload_item_photo_route(_request(), "item-1", _photo(), user))

    authorize.assert_called_once_with(
        user_id="user-1", item_id="item-1", write=True, selected_workspace_id=None
    )
    assert upload.call_args.kwargs["filename"].endswith(".jpg")
    assert upload.call_args.kwargs["content"].startswith(b"\xff\xd8")
    save.assert_called_once_with(
        user_id="user-1", item_id="item-1",
        updates={"image_url": "https://example.test/photo.jpg"},
        actor_user_id="user-1", workspace_id=None,
    )
    assert result.item == updated

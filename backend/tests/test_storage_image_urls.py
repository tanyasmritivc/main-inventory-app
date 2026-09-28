from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.services.storage import upload_image


def test_uploaded_image_uses_public_storage_host():
    settings = SimpleNamespace(
        supabase_storage_bucket="item-images",
        supabase_storage_public=True,
        supabase_public_url="https://findez-db.example.test",
    )
    bucket = MagicMock()
    bucket.get_public_url.return_value = (
        "http://localhost:18000/storage/v1/object/public/item-images/user/photo.jpg"
    )
    admin = MagicMock()
    admin.storage.from_.return_value = bucket

    with patch("app.services.storage.get_settings", return_value=settings), patch(
        "app.services.storage.get_supabase_admin", return_value=admin
    ):
        stored = upload_image(
            user_id="user", filename="photo.jpg", content=b"photo"
        )

    assert stored.url == (
        "https://findez-db.example.test/storage/v1/object/public/"
        "item-images/user/photo.jpg"
    )
    bucket.upload.assert_called_once()

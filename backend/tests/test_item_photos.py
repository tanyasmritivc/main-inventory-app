import io
from types import SimpleNamespace
from unittest.mock import call, patch

from PIL import Image

from app.services.item_photos import (
    _jpeg_bytes,
    _photos_for_item,
    _storage_path,
    add_item_photo,
    delete_item_photo,
)


def _image_bytes() -> bytes:
    output = io.BytesIO()
    Image.new("RGBA", (40, 20), (20, 80, 160, 180)).save(output, format="PNG")
    return output.getvalue()


def test_photo_list_keeps_primary_first_and_deduplicates_urls():
    item = {
        "item_id": "item-1",
        "image_url": "https://images.test/primary.jpg",
        "created_at": "2026-09-28T12:00:00Z",
    }
    events = [
        {
            "event_id": "event-2",
            "image_url": "https://images.test/second.jpg",
            "created_at": "2026-09-28T13:00:00Z",
        },
        {
            "event_id": "event-1",
            "image_url": "https://images.test/primary.jpg",
            "created_at": "2026-09-28T12:00:00Z",
        },
        {
            "event_id": "duplicate",
            "image_url": "https://images.test/primary.jpg",
            "created_at": "2026-09-28T11:00:00Z",
        },
    ]

    photos = _photos_for_item(item=item, events=events)

    assert [photo["photo_id"] for photo in photos] == ["event-1", "event-2"]
    assert photos[0]["is_primary"] is True
    assert photos[1]["is_primary"] is False


def test_photo_is_normalized_to_jpeg():
    normalized = _jpeg_bytes(_image_bytes())

    assert normalized.startswith(b"\xff\xd8")
    with Image.open(io.BytesIO(normalized)) as image:
        assert image.mode == "RGB"
        assert image.size == (40, 20)


def test_add_photo_preserves_existing_primary_as_gallery_event():
    item = {
        "item_id": "item-1",
        "image_url": "https://images.test/captured.jpg",
    }
    updated = {**item, "image_url": "https://images.test/new.jpg"}
    final_photos = [
        {
            "photo_id": "event-new",
            "image_url": "https://images.test/new.jpg",
            "is_primary": True,
        },
        {
            "photo_id": "event-old",
            "image_url": "https://images.test/captured.jpg",
            "is_primary": False,
        },
    ]

    with patch("app.services.item_photos._get_item", return_value=item), patch(
        "app.services.item_photos._photo_events", return_value=[]
    ), patch(
        "app.services.item_photos.upload_image",
        return_value=SimpleNamespace(
            path="user-1/new.jpg",
            url="https://images.test/new.jpg",
        ),
    ), patch(
        "app.services.item_photos.log_event",
        side_effect=[{"event_id": "event-old"}, {"event_id": "event-new"}],
    ) as log, patch(
        "app.services.item_photos.update_item", return_value=updated
    ) as update, patch(
        "app.services.item_photos.list_item_photos",
        return_value=(updated, final_photos),
    ):
        result_item, photos = add_item_photo(
            user_id="user-1",
            item_id="item-1",
            filename="part.png",
            content=_image_bytes(),
        )

    assert result_item == updated
    assert photos == final_photos
    assert log.call_args_list == [
        call(
            user_id="user-1",
            item_id="item-1",
            event_type="photo",
            image_url="https://images.test/captured.jpg",
        ),
        call(
            user_id="user-1",
            item_id="item-1",
            event_type="photo",
            image_url="https://images.test/new.jpg",
        ),
    ]
    update.assert_called_once_with(
        user_id="user-1",
        item_id="item-1",
        updates={"image_url": "https://images.test/new.jpg"},
    )


def test_delete_primary_photo_promotes_the_next_photo():
    item = {"item_id": "item-1", "image_url": "https://images.test/one.jpg"}
    first_events = [
        {
            "event_id": "event-1",
            "image_url": "https://images.test/one.jpg",
            "created_at": "2026-09-28T13:00:00Z",
        },
        {
            "event_id": "event-2",
            "image_url": "https://images.test/two.jpg",
            "created_at": "2026-09-28T12:00:00Z",
        },
    ]
    remaining_events = [first_events[1]]
    updated = {**item, "image_url": "https://images.test/two.jpg"}

    with patch("app.services.item_photos._get_item", return_value=item), patch(
        "app.services.item_photos._photo_events",
        side_effect=[first_events, remaining_events],
    ), patch("app.services.item_photos._delete_event") as delete_event, patch(
        "app.services.item_photos.update_item", return_value=updated
    ) as update, patch(
        "app.services.item_photos._storage_path", return_value=None
    ), patch(
        "app.services.item_photos.list_item_photos",
        return_value=(updated, _photos_for_item(item=updated, events=remaining_events)),
    ):
        result_item, photos = delete_item_photo(
            user_id="user-1",
            item_id="item-1",
            photo_id="event-1",
        )

    delete_event.assert_called_once_with(
        user_id="user-1", item_id="item-1", event_id="event-1"
    )
    update.assert_called_once_with(
        user_id="user-1",
        item_id="item-1",
        updates={"image_url": "https://images.test/two.jpg"},
    )
    assert result_item == updated
    assert photos[0]["image_url"] == "https://images.test/two.jpg"


def test_storage_cleanup_only_accepts_the_items_owner_folder():
    own = (
        "https://findez.test/storage/v1/object/public/item-images/"
        "user-1/photo.jpg"
    )
    another_user = own.replace("user-1", "user-2")

    with patch("app.services.item_photos.get_settings") as settings:
        settings.return_value.supabase_storage_bucket = "item-images"
        assert _storage_path(user_id="user-1", image_url=own) == "user-1/photo.jpg"
        assert _storage_path(user_id="user-1", image_url=another_user) is None


def test_delete_keeps_storage_object_while_another_item_references_it():
    shared_url = "https://images.test/shared-source.jpg"
    item = {"item_id": "item-1", "image_url": shared_url}
    event = {
        "event_id": "event-1",
        "image_url": shared_url,
        "created_at": "2026-09-28T13:00:00Z",
    }
    updated = {**item, "image_url": None}

    with patch("app.services.item_photos._get_item", return_value=item), patch(
        "app.services.item_photos._photo_events", side_effect=[[event], []]
    ), patch("app.services.item_photos._delete_event"), patch(
        "app.services.item_photos.update_item", return_value=updated
    ), patch(
        "app.services.item_photos._storage_path", return_value="user-1/source.jpg"
    ), patch(
        "app.services.item_photos._image_url_is_referenced", return_value=True
    ), patch("app.services.item_photos.delete_image") as delete_image, patch(
        "app.services.item_photos.list_item_photos", return_value=(updated, [])
    ):
        delete_item_photo(
            user_id="user-1",
            item_id="item-1",
            photo_id="event-1",
        )

    delete_image.assert_not_called()

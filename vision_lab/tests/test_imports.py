import base64
import io
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from findez_vision.data import Invalid, authorize, load_dataset
from findez_vision.imports import add_photo, clean_photo
from test_lab import Fixture


def photo_body():
    image = Image.new("RGB", (20,30), "purple")
    exif = Image.Exif()
    exif[274] = 6
    exif[315] = "private"
    stream = io.BytesIO()
    image.save(stream, format="JPEG", exif=exif)
    return {"request_id":"a"*32, "name":"my_photo.jpg", "group_id":"my_photos",
            "owned_photo_checked":True, "image_base64":base64.b64encode(stream.getvalue()).decode()}


class ImportTests(Fixture):
    def add(self, body=None):
        return add_photo(self.root/"dataset.json", load_dataset(self.root/"dataset.json"), body or photo_body())

    def test_import_preserves_existing_annotations_and_has_no_training_grant(self):
        original = self.data["samples"]
        sample = self.add()
        data = load_dataset(self.root/"dataset.json")
        self.assertEqual(data["samples"][:-1], original)
        self.assertEqual(sample["image"]["width"], 30)
        self.assertEqual(sample["annotation"]["status"], "draft")
        self.assertEqual(sample["annotation"]["objects"], [])
        with self.assertRaisesRegex(Invalid, "Missing permission"):
            authorize({"samples":[sample]}, self.ledger, "evaluation")
        self.assertEqual(len(list((self.root/".history").glob("*.json"))), 1)

    def test_duplicate_import_does_not_add_another_image(self):
        self.add()
        self.add()  # Same idempotency key returns the existing sample.
        duplicate = photo_body()
        duplicate["request_id"] = "b"*32
        with self.assertRaisesRegex(Invalid, "already in"):
            self.add(duplicate)
        self.assertEqual(len(load_dataset(self.root/"dataset.json")["samples"]), 5)
        self.assertEqual(len(list((self.root/"images").glob("photo_*.png"))), 1)

    def test_reused_request_for_different_content_denied(self):
        self.add()
        body = photo_body()
        body["image_base64"] = base64.b64encode(b"other").decode()
        with self.assertRaisesRegex(Invalid, "reused"):
            self.add(body)

    def test_bad_input_rejected_without_writes(self):
        before = (self.root/"dataset.json").read_bytes()
        for field, value in (("owned_photo_checked",False),("request_id","../escape"),
                             ("group_id","../../escape"),("image_base64","%%%"),("name","")):
            with self.subTest(field=field):
                body = photo_body()
                body[field] = value
                with self.assertRaises(Invalid):
                    self.add(body)
        self.assertEqual((self.root/"dataset.json").read_bytes(), before)
        self.assertFalse(list((self.root/"images").glob("photo_*.png")))

    def test_filename_is_display_text_and_never_a_storage_path(self):
        body = photo_body()
        body["name"] = "../outside/<script>.jpg"
        sample = self.add(body)
        self.assertEqual(sample["image"]["path"], "images/photo_"+"a"*32+".png")
        self.assertFalse((self.root/"outside").exists())

    def test_failed_dataset_write_removes_only_new_image(self):
        before = (self.root/"dataset.json").read_bytes()
        with patch("findez_vision.imports.save_dataset", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                self.add()
        self.assertEqual((self.root/"dataset.json").read_bytes(), before)
        self.assertFalse(list((self.root/"images").glob("photo_*.png")))
        self.assertEqual(len(list((self.root/"images").glob("scene_*.png"))), 4)

    def test_invalid_image_and_unsupported_heic_have_clear_errors(self):
        with self.assertRaisesRegex(Invalid, "could not be read"):
            clean_photo(b"not an image")
        heic = b"\x00\x00\x00\x18ftypheic"+b"\0"*30
        with patch("findez_vision.imports.supports_heic",return_value=False):
            with self.assertRaisesRegex(Invalid, "export a JPEG"):
                clean_photo(heic)

    def test_import_keeps_unicode_filename_in_utf8(self):
        body = photo_body()
        body["name"] = "\u00e9tage.jpg"
        self.add(body)
        self.assertEqual(load_dataset(self.root/"dataset.json")["samples"][-1]["display_name"], body["name"])

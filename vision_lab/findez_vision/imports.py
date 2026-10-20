"""Local photo ingestion. No network calls or training permission grants."""
import base64
import hashlib
import io
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageOps

from .data import MAX_FILE_BYTES, MAX_PIXELS, Invalid, digest, file_hash, identifier, require, validate_dataset


def supports_heic():
    return sys.platform == "darwin" and shutil.which("sips") is not None


def clean_photo(raw):
    require(0 < len(raw) <= MAX_FILE_BYTES, "Choose an image smaller than 32 MB")
    heic = raw[4:8] == b"ftyp" and any(
        brand in raw[8:64] for brand in (b"heic", b"heix", b"hevc", b"hevx", b"mif1", b"msf1")
    )
    with tempfile.TemporaryDirectory(prefix="findez-photo-") as directory:
        source = io.BytesIO(raw)
        if heic:
            require(supports_heic(), "For HEIC photos on this computer, export a JPEG or PNG first")
            original, converted = Path(directory)/"photo.heic", Path(directory)/"photo.png"
            original.write_bytes(raw)
            try:
                info = subprocess.run(
                    ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(original)],
                    capture_output=True, text=True, timeout=15, check=True,
                ).stdout
                width = re.search(r"pixelWidth:\s*(\d+)", info)
                height = re.search(r"pixelHeight:\s*(\d+)", info)
                require(width and height and 0 < int(width[1])*int(height[1]) <= MAX_PIXELS,
                        "Image exceeds the 16-megapixel limit")
                subprocess.run(["sips", "-s", "format", "png", str(original), "--out", str(converted)],
                               capture_output=True, timeout=30, check=True)
                source = converted
            except (subprocess.SubprocessError, OSError):
                raise Invalid("HEIC conversion failed. Export a JPEG or PNG and try again.") from None
        try:
            with Image.open(source) as photo:
                require(photo.format in ("PNG", "JPEG"), "Choose a JPEG, PNG or supported HEIC photo")
                require(photo.width*photo.height <= MAX_PIXELS, "Image exceeds the 16-megapixel limit")
                require(not getattr(photo, "is_animated", False), "Choose a still photo")
                normalized = ImageOps.exif_transpose(photo).convert("RGB")
                clean = Image.new("RGB", normalized.size)
                clean.paste(normalized)
                return clean
        except (OSError, Image.DecompressionBombError):
            raise Invalid("The image could not be read safely. Choose a smaller JPEG or PNG.") from None


def save_dataset(path, before, after):
    """Keep a local prior revision and atomically replace the dataset file."""
    path = Path(path)
    history = path.parent/".history"
    require(not history.is_symlink(), "History directory must not be a symlink")
    history.mkdir(exist_ok=True)
    backup = history/(digest(before)+".json")
    if not backup.exists():
        with backup.open("x", encoding="utf-8") as stream:
            json.dump(before, stream, indent=2, ensure_ascii=False)
    temporary = path.with_name("."+path.name+"."+secrets.token_hex(8)+".tmp")
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(after, stream, indent=2, ensure_ascii=False, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def add_photo(path, data, body):
    require(body.get("owned_photo_checked") is True,
            "Confirm that this is your photo and you checked its visible content")
    request_id = body.get("request_id")
    require(isinstance(request_id, str) and re.fullmatch(r"[a-f0-9]{32}", request_id),
            "Invalid import request")
    sid = "photo_"+request_id
    group = identifier(body.get("group_id"), "photo group")
    name = body.get("name")
    require(isinstance(name, str) and 0 < len(name) <= 200, "Invalid photo name")
    encoded = body.get("image_base64")
    require(isinstance(encoded, str) and len(encoded) <= 43_000_000, "Photo is too large")
    try:
        raw = base64.b64decode(encoded, validate=True)
    except ValueError:
        raise Invalid("Invalid image upload") from None
    require(0 < len(raw) <= MAX_FILE_BYTES, "Choose an image smaller than 32 MB")
    original_hash = hashlib.sha256(raw).hexdigest()
    existing = next((s for s in data["samples"] if s["id"] == sid), None)
    if existing:
        require(existing.get("import_sha256") == original_hash, "Import request was reused for another photo")
        return existing
    clean = clean_photo(raw)
    require(len(data["samples"]) < 10000, "Dataset is full")
    path = Path(path)
    image_dir = path.parent/"images"
    require(not image_dir.is_symlink(), "Image directory must not be a symlink")
    image_dir.mkdir(exist_ok=True)
    target = image_dir/(sid+".png")
    require(not target.exists() and not target.is_symlink(), "Image destination already exists")
    committed = False
    try:
        with target.open("xb") as output:
            clean.save(output, format="PNG")
        fingerprint = file_hash(target)
        require(not any(s["image"]["sha256"] == fingerprint for s in data["samples"]),
                "This photo is already in the dataset")
        sample = {
            "id": sid, "display_name": name, "import_sha256": original_hash,
            "group_id": group, "physical_object_ids": [], "split": "train",
            "split_assignment": "Provisional. Review related-object groups and assign splits before experiments.",
            "tags": [],
            "image": {"path": f"images/{sid}.png", "sha256": fingerprint,
                      "width": clean.width, "height": clean.height},
            "provenance": {"source_type": "owned", "grant_id": "owned_pilot"},
            "annotation": {"status": "draft", "source": "human", "label_origin": "independent_human",
                           "reviewer": "", "objects": []},
        }
        updated = {**data, "samples": [*data["samples"], sample]}
        validate_dataset(updated, path.parent)
        save_dataset(path, data, updated)
        committed = True
        return sample
    finally:
        if not committed:
            target.unlink(missing_ok=True)

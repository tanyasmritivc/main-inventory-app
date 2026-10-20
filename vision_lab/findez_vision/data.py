"""Fail-closed local dataset and operator-attested permission validation."""
from __future__ import annotations

import hashlib
import json
import math
import re
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

MAX_PIXELS = 16_000_000
MAX_FILE_BYTES = 32_000_000
MAX_JSON_BYTES = 16_000_000
ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$")
USES = {"evaluation", "segmentation_training", "recognition_training", "ocr_training"}
Image.MAX_IMAGE_PIXELS = MAX_PIXELS


class Invalid(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Invalid(message)


def read_json(path):
    path = Path(path)
    require(path.stat().st_size <= MAX_JSON_BYTES, "JSON exceeds the local file limit")
    def pairs(values):
        obj = {}
        for key, value in values:
            require(key not in obj, f"Duplicate JSON key: {key}")
            obj[key] = value
        return obj
    def constant(value):
        raise Invalid(f"Non-finite JSON value: {value}")
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=pairs, parse_constant=constant)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=False, allow_nan=False).encode()).hexdigest()


def file_hash(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def timestamp(value):
    require(isinstance(value, str), "Timestamp must be an ISO date with timezone")
    try:
        date = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise Invalid("Invalid timestamp") from None
    require(date.tzinfo is not None, "Timestamp needs a timezone")
    return date


def safe_file(root, relative):
    require(isinstance(relative, str) and relative and "\\" not in relative, "Invalid relative path")
    p = Path(relative)
    require(not p.is_absolute() and ".." not in p.parts, "Paths must stay inside the dataset")
    root = Path(root).resolve()
    path = root / p
    # Disallow links even when they currently resolve within the dataset.
    for part in [path, *path.parents]:
        if part == root:
            break
        require(not part.is_symlink(), "Dataset symlinks are not allowed")
    require(path.resolve().is_relative_to(root) and path.is_file(), "Dataset file is missing or outside its root")
    require(path.stat().st_size <= MAX_FILE_BYTES, "Image exceeds local file limit")
    return path


def identifier(value, field="id"):
    require(isinstance(value, str) and ID.fullmatch(value), f"Invalid {field}")
    return value


def text(value, field, maximum=200):
    require(isinstance(value, str) and len(value) <= maximum, f"Invalid {field}")
    return value


def image_size(path):
    with Image.open(path) as im:
        im.verify()
    with Image.open(path) as im:
        require(im.format in ("JPEG", "PNG"), "Only JPEG/PNG images are supported")
        require(im.width * im.height <= MAX_PIXELS, "Image exceeds pixel limit")
        require(im.getexif().get(274, 1) == 1, "Normalize orientation before annotating")
        require(not im.getexif() and not im.info.get("icc_profile"), "Use ingest to strip image metadata")
        im.load()
        require(not im.info.get("comment") and not getattr(im, "text", {}), "Use ingest to strip image metadata")
        return im.size


def mask_for(obj, size, root):
    """Raster masks preserve holes. Polygon coordinates are original-image pixel centers."""
    require(isinstance(obj, dict), "Object must be a JSON object")
    identifier(obj.get("id"), "object id")
    require(("polygons" in obj) != ("mask" in obj), "Choose polygons or a binary mask")
    if "mask" in obj:
        ref = obj["mask"]
        require(isinstance(ref, dict), "Invalid mask reference")
        path = safe_file(root, ref.get("path"))
        require(file_hash(path) == ref.get("sha256"), "Mask checksum mismatch")
        with Image.open(path) as im:
            require(im.format == "PNG" and im.mode in ("1", "L"), "Masks must be binary PNGs")
            require(im.size == size, "Mask dimensions differ from source image")
            im = im.convert("L")
            require(set(im.tobytes()) <= {0, 255}, "Masks must contain only 0 and 255")
            require(im.getbbox() is not None, "Empty object mask")
            return im.copy()
    polygons = obj["polygons"]
    require(isinstance(polygons, list) and 1 <= len(polygons) <= 100, "Invalid polygon list")
    mask = Image.new("L", size)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        require(isinstance(polygon, list) and 3 <= len(polygon) <= 2000, "A polygon needs 3-2000 points")
        points = []
        for point in polygon:
            require(isinstance(point, list) and len(point) == 2, "Point must be [x,y]")
            x, y = point
            require(all(type(v) in (float, int) and math.isfinite(v) for v in point), "Invalid coordinate")
            require(0 <= x <= size[0]-1 and 0 <= y <= size[1]-1, "Point outside image")
            points.append((x, y))
        require(len(set(points)) == len(points), "Polygon contains repeated points")
        def cross(a, b, c):
            return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])
        def on_segment(a, b, p):
            return (min(a[0], b[0]) <= p[0] <= max(a[0], b[0]) and
                    min(a[1], b[1]) <= p[1] <= max(a[1], b[1]))
        # Non-adjacent edges must not touch or cross.
        for i in range(len(points)):
            a, b = points[i], points[(i+1) % len(points)]
            for j in range(i+2, len(points)):
                if i == 0 and j == len(points)-1:
                    continue
                c, d = points[j], points[(j+1) % len(points)]
                x, y, z, w = cross(a,b,c), cross(a,b,d), cross(c,d,a), cross(c,d,b)
                touches = ((x == 0 and on_segment(a,b,c)) or (y == 0 and on_segment(a,b,d)) or
                           (z == 0 and on_segment(c,d,a)) or (w == 0 and on_segment(c,d,b)))
                require(not touches and not ((x > 0) != (y > 0) and (z > 0) != (w > 0)),
                        "Polygon intersects itself")
        area = abs(sum(points[i][0] * points[(i+1) % len(points)][1] -
                       points[(i+1) % len(points)][0] * points[i][1] for i in range(len(points)))) / 2
        require(area > 0, "Polygon has no area")
        # ImageDraw pixels are inclusive; coordinates denote pixel centers here.
        draw.polygon(points, fill=255)
    require(mask.getbbox() is not None, "Empty object mask")
    return mask


def validate_annotation(annotation, size, root, *, verified=False):
    require(isinstance(annotation, dict), "Missing annotation")
    require(annotation.get("status") in ("draft", "verified", "rejected"), "Invalid annotation status")
    if verified:
        require(annotation["status"] == "verified", "Every selected sample must be verified")
    if annotation["status"] == "verified":
        require(bool(text(annotation.get("reviewer"), "reviewer")), "Verified labels need a reviewer")
        timestamp(annotation.get("reviewed_at"))
        require(annotation.get("source") in ("human", "synthetic"), "Model labels need independent human review")
    require(annotation.get("label_origin") in ("independent_human", "synthetic_authored", "model_assisted"),
            "Record the original label provenance")
    objects = annotation.get("objects")
    require(isinstance(objects, list) and len(objects) <= 255, "At most 255 instances per image")
    ids, occupied = set(), Image.new("L", size)
    for obj in objects:
        require(isinstance(obj, dict), "Invalid object")
        identifier(obj.get("id"), "object id")
        require(obj["id"] not in ids, "Duplicate object id")
        ids.add(obj["id"])
        mask = mask_for(obj, size, root)
        require(mask.getbbox() is not None, "Empty object mask")
        require(ImageChops.multiply(occupied, mask).getbbox() is None,
                "Visible-instance masks overlap; correct the boundaries")
        occupied = ImageChops.lighter(occupied, mask)
        text(obj.get("label", ""), "label")
        if "identity" in obj:
            text(obj["identity"], "identity")
        if "ocr" in obj:
            text(obj["ocr"], "ocr", 4000)
    return annotation


def validate_dataset(document, root, *, verified=False):
    require(isinstance(document, dict) and document.get("version") == 1, "Dataset version must be 1")
    identifier(document.get("id"), "dataset id")
    samples = document.get("samples")
    require(isinstance(samples, list) and 1 <= len(samples) <= 10000, "Dataset needs 1-10000 samples")
    ids, split_for = set(), {}
    for sample in samples:
        require(isinstance(sample, dict), "Invalid sample")
        sid = identifier(sample.get("id"), "sample id")
        require(sid not in ids, "Duplicate sample id")
        ids.add(sid)
        split = sample.get("split")
        require(split in ("train", "validation", "test"), "Invalid dataset split")
        group = identifier(sample.get("group_id"), "capture group")
        physical = sample.get("physical_object_ids")
        require(isinstance(physical, list), "physical_object_ids must be a list, even when empty")
        for identity in physical:
            identifier(identity, "physical object id")
        im = sample.get("image")
        require(isinstance(im, dict), "Missing image")
        path = safe_file(root, im.get("path"))
        require(file_hash(path) == im.get("sha256"), "Image checksum mismatch")
        size = image_size(path)
        require(list(size) == [im.get("width"), im.get("height")], "Image dimensions mismatch")
        # Decode-level duplicate detection catches PNG/JPEG metadata-only differences.
        with Image.open(path) as decoded:
            pixels = hashlib.sha256(decoded.convert("RGB").tobytes()).hexdigest()
        for name in ["group:" + group, "file:" + im["sha256"], f"pixels:{size}:{pixels}"] + ["object:" + x for x in physical]:
            require(name not in split_for or split_for[name] == split, "Related or duplicate images cross dataset splits")
            split_for[name] = split
        source = sample.get("provenance")
        require(isinstance(source, dict), "Missing provenance")
        require(source.get("source_type") in ("owned", "synthetic"), "Customer/shared data is not enabled in this local pilot")
        identifier(source.get("grant_id"), "grant id")
        tags = sample.get("tags", [])
        require(isinstance(tags, list) and len(tags) <= 30, "Invalid tags")
        for tag in tags:
            identifier(tag, "tag")
        validate_annotation(sample.get("annotation"), size, root, verified=verified)
    return document


def authorize(document, ledger, use, *, now=None):
    """Local operator attestations only; not a production consent or identity service."""
    require(use in USES, "Unknown dataset purpose")
    require(isinstance(ledger, dict) and ledger.get("version") == 1 and isinstance(ledger.get("grants"), list),
            "Invalid permission ledger")
    now = now or datetime.now(timezone.utc)
    grants = {}
    for grant in ledger["grants"]:
        require(isinstance(grant, dict), "Invalid grant")
        gid = identifier(grant.get("id"), "grant id")
        require(gid not in grants, "Duplicate grant id")
        grants[gid] = grant
    for sample in document["samples"]:
        grant = grants.get(sample["provenance"]["grant_id"])
        require(grant is not None, "Missing permission grant")
        require(grant.get("revoked_at") is None, "Permission has been withdrawn")
        require(timestamp(grant.get("granted_at")) <= now < timestamp(grant.get("expires_at")), "Permission is not current")
        require(grant.get("source_type") == sample["provenance"]["source_type"], "Grant/source mismatch")
        require(grant.get("rights_basis") in ("creator_owned", "synthetic_created"), "Unsupported rights basis")
        require((grant["rights_basis"] == "synthetic_created") == (grant["source_type"] == "synthetic"), "Rights/source mismatch")
        require(bool(text(grant.get("approved_by"), "approved_by")), "Permission needs an operator attestation")
        require(use in grant.get("uses", []), "This purpose is not authorized")
        require(sample["image"]["sha256"] in grant.get("asset_sha256", []), "Image is not covered by this permission")
        require(grant.get("sensitive_content_reviewed") is True, "Sensitive-content review is required")
        if use.endswith("_training"):
            require(sample["annotation"].get("status") == "verified", "Training labels must be verified")
            require(sample["annotation"].get("source") in ("human", "synthetic"), "Unverified model output cannot train another model")
            require(sample["annotation"].get("label_origin") in ("independent_human", "synthetic_authored"),
                    "Model-assisted labels require a separate license review; this pilot blocks their training export")
    return True


def load_dataset(path, *, verified=False):
    path = Path(path).resolve()
    return validate_dataset(read_json(path), path.parent, verified=verified)

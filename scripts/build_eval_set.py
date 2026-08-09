#!/usr/bin/env python3
"""
Build a FindEZ vision eval set from a Supabase CSV export.

Produces a folder of image files, each paired with a .expected.json containing the
items the current production model (GPT-4o) extracted from that image — so an
open-weight model can be scored against the same inputs.

USAGE
-----
1. In Supabase → SQL Editor, run the query in docs/local-llm-eval-pack.md and
   download the result as CSV.
2. python3 scripts/build_eval_set.py ~/Downloads/that-file.csv
3. Send the resulting findez-eval-set.zip

The CSV must contain an `image_url` column plus whichever item fields you selected.
Rows sharing an image_url are grouped into one test case.
"""

import csv
import json
import os
import ssl
import sys
import urllib.request
import zipfile
from collections import OrderedDict
from urllib.parse import urlparse

OUT_DIR = "findez-eval-set"
ZIP_NAME = "findez-eval-set.zip"

ITEM_FIELDS = [
    "name", "category", "subcategory", "brand",
    "part_number", "quantity", "confidence", "location",
]


def clean(value):
    if value is None:
        return None
    v = value.strip()
    if v == "" or v.lower() in ("null", "none"):
        return None
    return v


def coerce(field, value):
    v = clean(value)
    if v is None:
        return None
    if field == "quantity":
        try:
            return int(float(v))
        except ValueError:
            return None
    if field == "confidence":
        try:
            return float(v)
        except ValueError:
            return None
    return v


def extension_for(url):
    path = urlparse(url).path.lower()
    for ext in (".jpg", ".jpeg", ".png", ".webp", ".heic"):
        if path.endswith(ext):
            return ".jpg" if ext == ".jpeg" else ext
    return ".jpg"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    csv_path = os.path.expanduser(sys.argv[1])
    if not os.path.exists(csv_path):
        print(f"No such file: {csv_path}")
        sys.exit(1)

    groups = OrderedDict()
    with open(csv_path, newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        if "image_url" not in (reader.fieldnames or []):
            print("CSV has no image_url column. Columns found:", reader.fieldnames)
            sys.exit(1)
        for row in reader:
            url = clean(row.get("image_url"))
            if not url or not url.startswith("http"):
                continue
            item = {}
            for field in ITEM_FIELDS:
                if field in row:
                    val = coerce(field, row.get(field))
                    if val is not None:
                        item[field] = val
            if item.get("name"):
                groups.setdefault(url, []).append(item)

    if not groups:
        print("No rows with a usable image_url were found.")
        sys.exit(1)

    os.makedirs(OUT_DIR, exist_ok=True)
    ctx = ssl.create_default_context()

    manifest = []
    ok = 0
    for index, (url, items) in enumerate(groups.items(), start=1):
        stem = f"img_{index:03d}"
        image_name = stem + extension_for(url)
        image_path = os.path.join(OUT_DIR, image_name)

        try:
            req = urllib.request.Request(url, headers={"User-Agent": "findez-eval/1.0"})
            with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
                data = resp.read()
            with open(image_path, "wb") as out:
                out.write(data)
        except Exception as exc:
            print(f"  ! skipped {stem}: {exc}")
            continue

        expected = {
            "image": image_name,
            "source_url": url,
            "expected_items": items,
            "summary": {
                "total_detected": len(items),
                "categories": _count_categories(items),
            },
            "_note": (
                "Produced by GPT-4o in production. This is the CURRENT BASELINE, "
                "not verified ground truth. Correct by hand before publishing scores."
            ),
        }
        with open(os.path.join(OUT_DIR, f"{stem}.expected.json"), "w", encoding="utf-8") as out:
            json.dump(expected, out, indent=2, ensure_ascii=False)

        manifest.append({"image": image_name, "item_count": len(items)})
        ok += 1
        print(f"  ok {stem}  ({len(items)} item{'s' if len(items) != 1 else ''})")

    with open(os.path.join(OUT_DIR, "manifest.json"), "w", encoding="utf-8") as out:
        json.dump({"cases": manifest, "total_cases": len(manifest)}, out, indent=2)

    with open(os.path.join(OUT_DIR, "README.txt"), "w", encoding="utf-8") as out:
        out.write(README_TEXT)

    with zipfile.ZipFile(ZIP_NAME, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _dirs, files in os.walk(OUT_DIR):
            for name in files:
                full = os.path.join(root, name)
                zf.write(full, os.path.relpath(full, "."))

    print(f"\n{ok} test case(s) written to {OUT_DIR}/ and packaged as {ZIP_NAME}")
    print("Review the images before sending — they are real user photos.")


def _count_categories(items):
    counts = {}
    for item in items:
        cat = item.get("category") or "Other"
        counts[cat] = counts.get(cat, 0) + 1
    return counts


README_TEXT = """FindEZ vision eval set
======================

Each test case is a pair:

  img_001.jpg               the image given to the model
  img_001.expected.json     what GPT-4o extracted from it in production

IMPORTANT: expected_items is the CURRENT BASELINE, not verified ground truth.
It is what the live system produces today. Some of it is wrong. The bar for a
replacement model is parity or better, not exact string matching.

HOW TO USE
----------
Send each image to the candidate model using the exact prompts and tool schemas
in docs/local-llm-eval-pack.md, then compare its output to expected_items.

Score on:
  - JSON validity ......... must be 100%. No fallback exists in production.
  - Recall ................ found / expected
  - Precision ............. correct / found. Hallucinations count against.
  - Name usability ........ would this string be findable by search?
  - Category accuracy ..... one of: Food, Electronics, Clothing, Health, Home,
                            Office, Supplies, Toys, Cosmetics, Other

DO NOT evaluate on fasteners. M3x8 vs M3x10 is a 2mm difference and no vision
model can recover absolute length from an uncalibrated photo.
"""


if __name__ == "__main__":
    main()

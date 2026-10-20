"""Deterministic, generated fixtures. Never use these to claim model improvement."""
from datetime import datetime, timedelta, timezone
from pathlib import Path

from PIL import Image, ImageDraw

from .artifacts import write_json
from .data import digest, file_hash, require


def create_demo(destination):
    root = Path(destination)
    require(not root.exists(), "Demo destination exists; choose another directory")
    (root/"images").mkdir(parents=True)
    objects = [
        {"id": "motor_left", "label": "Motor", "identity": "synthetic-motor-A", "ocr": "M12",
         "polygons": [[[8, 10], [27, 10], [27, 34], [8, 34]]]},
        {"id": "motor_right", "label": "Motor", "identity": "synthetic-motor-B",
         "polygons": [[[33, 10], [53, 10], [53, 34], [33, 34]]]},
    ]
    now = datetime.now(timezone.utc)
    samples = []
    for index, split in enumerate(("train", "validation", "test", "test")):
        image = Image.new("RGB", (64, 48), (240-index*8, 235-index*7, 225-index*6))
        draw = ImageDraw.Draw(image)
        label_objects = objects if index != 3 else []
        for n, obj in enumerate(label_objects):
            draw.polygon([tuple(p) for p in obj["polygons"][0]], fill=("#d77d39", "#507c8d")[n])
        path = root/"images"/f"scene_{index}.png"
        image.save(path)
        samples.append({
            "id": f"scene_{index}", "group_id": f"independent_synthetic_{index}",
            "physical_object_ids": [], "split": split,
            "tags": ["negative"] if index == 3 else ["two_objects", "synthetic"],
            "image": {"path": f"images/scene_{index}.png", "width": 64, "height": 48, "sha256": file_hash(path)},
            "provenance": {"source_type": "synthetic", "grant_id": "synthetic_demo"},
            "annotation": {"status": "verified", "source": "synthetic", "label_origin": "synthetic_authored", "reviewer": "fixture_generator",
                           "reviewed_at": now.isoformat(), "objects": label_objects},
        })
    data = {"version": 1, "id": "synthetic_practice", "samples": samples}
    ledger = {"version": 1, "grants": [{
        "id": "synthetic_demo", "source_type": "synthetic", "rights_basis": "synthetic_created",
        "approved_by": "fixture_generator", "granted_at": now.isoformat(),
        "expires_at": (now+timedelta(days=30)).isoformat(), "revoked_at": None,
        "sensitive_content_reviewed": True,
        "uses": ["evaluation", "segmentation_training"],
        "asset_sha256": [s["image"]["sha256"] for s in samples],
    }]}
    good = {"version": 1, "dataset_sha256": digest(data),
            "run": {"id": "synthetic_correct", "kind": "synthetic"},
            "samples": [{"id": s["id"], "objects": s["annotation"]["objects"]} for s in samples if s["split"] == "test"]}
    bad = {"version": 1, "dataset_sha256": digest(data),
           "run": {"id": "synthetic_merge", "kind": "synthetic"},
           "samples": [
               {"id": "scene_2", "objects": [{"id": "merged", "label": "Motor",
                "polygons": [[[8, 10], [53, 10], [53, 34], [8, 34]]]}]},
               {"id": "scene_3", "objects": []},
           ]}
    policy = {"approved": False, "minimum_images": 100,
              "rules": [{"metric": "f1", "direction": "higher", "allowed_regression": 0},
                        {"metric": "recall", "direction": "higher", "allowed_regression": 0}],
              "required_slices": {"overlap": 20, "small_objects": 20, "negative": 10}}
    for name, value in {"dataset.json": data, "grants.json": ledger,
                        "predictions-good.json": good, "predictions-merged.json": bad,
                        "gate-policy.draft.json": policy}.items():
        write_json(root/name, value)
    return root

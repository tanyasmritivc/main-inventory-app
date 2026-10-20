"""Immutable local exports, with separate manifests and no server transfer."""
import json
import os
import shutil
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageChops

from .data import authorize, digest, file_hash, identifier, load_dataset, mask_for, read_json, require, safe_file, validate_dataset


def write_json(path, value):
    path = Path(path)
    require(not path.exists(), f"Refusing to overwrite {path.name}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False, allow_nan=False)
        stream.write("\n")


def export_sam(dataset_path, ledger_path, destination):
    source = Path(dataset_path).resolve()
    data = load_dataset(source, verified=True)
    chosen = {**data, "samples": [s for s in data["samples"] if s["split"] in ("train", "validation")]}
    require(any(s["split"] == "train" for s in chosen["samples"]), "No training examples")
    require(any(s["split"] == "validation" for s in chosen["samples"]), "A validation split is required")
    authorize(chosen, read_json(ledger_path), "segmentation_training")
    destination = Path(destination).resolve()
    require(not destination.exists(), "Export destination already exists; choose a new version")
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".findez-export-", dir=destination.parent))
    try:
        lists = {"train": [], "validation": []}
        for sample in chosen["samples"]:
            require(sample["annotation"]["objects"], "Empty training scenes need a reviewed sampler; keep them in the benchmark")
            sid = sample["id"]
            lists[sample["split"]].append(sid)
            image_dir, mask_dir = staging/"JPEGImages"/sid, staging/"Annotations"/sid
            image_dir.mkdir(parents=True)
            mask_dir.mkdir(parents=True)
            with Image.open(safe_file(source.parent, sample["image"]["path"])) as image:
                image.convert("RGB").save(image_dir/"00000.jpg", quality=95, subsampling=0)
                palette = Image.new("L", image.size)
                for index, obj in enumerate(sample["annotation"]["objects"], 1):
                    mask = mask_for(obj, image.size, source.parent)
                    palette.paste(index, (0, 0), mask)
                palette.save(mask_dir/"00000.png")
        for split, ids in lists.items():
            (staging/f"{split}.txt").write_text("\n".join(ids)+"\n")
        files = {str(p.relative_to(staging)): file_hash(p) for p in sorted(staging.rglob("*")) if p.is_file()}
        manifest = {
            "version": 1, "kind": "sam_single_frame_png", "source_dataset_sha256": digest(data),
            "purpose": "segmentation_training", "created_at": datetime.now(timezone.utc).isoformat(),
            "samples": chosen["samples"], "files": files, "test_images_included": False,
            "synthetic": any(s["provenance"]["source_type"] == "synthetic" for s in chosen["samples"]),
            "training_executed": False,
            "notes": "PNGRawDataset layout. One frame per image; configure num_frames=1. GPU config/weights must be verified by operator.",
        }
        write_json(staging/"snapshot.json", manifest)
        os.rename(staging, destination)
        return manifest
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def verify_snapshot(snapshot_path, ledger_path):
    path = Path(snapshot_path).resolve()
    snapshot = read_json(path)
    require(snapshot.get("version") == 1 and snapshot.get("kind") == "sam_single_frame_png", "Unknown snapshot")
    require(snapshot.get("purpose") == "segmentation_training" and snapshot.get("test_images_included") is False, "Invalid snapshot purpose")
    samples = snapshot.get("samples")
    require(isinstance(samples, list) and samples, "Snapshot has no samples")
    ids = [identifier(s.get("id")) for s in samples]
    require(len(set(ids)) == len(ids), "Duplicate snapshot samples")
    require(all(s.get("split") in ("train", "validation") for s in samples), "Test data cannot enter a training snapshot")
    require({s["split"] for s in samples} == {"train", "validation"}, "Snapshot needs both training and validation data")
    require(all(s.get("provenance", {}).get("source_type") in ("owned", "synthetic") for s in samples),
            "Snapshot contains unsupported data")
    expected_files = {"train.txt", "validation.txt"} | {
        f"{folder}/{sid}/{filename}" for sid in ids
        for folder, filename in (("JPEGImages", "00000.jpg"), ("Annotations", "00000.png"))
    }
    require(isinstance(snapshot.get("files"), dict) and set(snapshot["files"]) == expected_files,
            "Snapshot file inventory is incomplete or contains unexpected files")
    actual_files = {str(p.relative_to(path.parent)) for p in path.parent.rglob("*") if p.is_file()}
    require(actual_files == expected_files | {path.name}, "Snapshot directory contains unexpected files")
    for relative, expected in snapshot["files"].items():
        require(file_hash(safe_file(path.parent, relative)) == expected, "Export checksum mismatch")
    for split in ("train", "validation"):
        require((path.parent/f"{split}.txt").read_text().splitlines() == [s["id"] for s in samples if s["split"] == split],
                "Snapshot split list disagrees with its manifest")
    require(snapshot.get("synthetic") == any(s["provenance"]["source_type"] == "synthetic" for s in samples),
            "Snapshot synthetic flag disagrees with its samples")
    authorize({"samples": snapshot["samples"]}, read_json(ledger_path), "segmentation_training")
    return snapshot


def assemble(dataset_paths, destination, dataset_id):
    """Copy reviewed local samples into one self-contained dataset, preserving splits."""
    identifier(dataset_id)
    sources = [(Path(p).resolve(), load_dataset(p)) for p in dataset_paths]
    require(bool(sources), "Choose at least one dataset")
    ids = [s["id"] for _, data in sources for s in data["samples"]]
    require(len(ids) == len(set(ids)), "Choose distinct sample IDs before assembling")
    destination = Path(destination).resolve()
    require(not destination.exists(), "Destination exists")
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".findez-assemble-", dir=destination.parent))
    try:
        samples = []
        for source, data in sources:
            for original in data["samples"]:
                sample = json.loads(json.dumps(original))
                source_image = safe_file(source.parent, sample["image"]["path"])
                relative = f"images/{sample['id']}{source_image.suffix.lower()}"
                target = staging/relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source_image, target)
                sample["image"]["path"] = relative
                for obj in sample["annotation"]["objects"]:
                    if "mask" in obj:
                        relative = f"masks/{sample['id']}/{obj['id']}.png"
                        target = staging/relative
                        target.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(safe_file(source.parent, obj["mask"]["path"]), target)
                        obj["mask"]["path"] = relative
                samples.append(sample)
        result = {"version": 1, "id": dataset_id, "samples": samples}
        validate_dataset(result, staging)
        write_json(staging/"dataset.json", result)
        os.rename(staging, destination)
        return result
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def withdrawal_impact(ledger, grant_id, snapshot_paths):
    grant = next((g for g in ledger["grants"] if g["id"] == grant_id), None)
    require(grant is not None, "Grant not found")
    affected = []
    for path in snapshot_paths:
        snapshot = read_json(path)
        if any(s["provenance"]["grant_id"] == grant_id for s in snapshot.get("samples", [])):
            affected.append({"snapshot": str(path), "dataset_sha256": snapshot.get("source_dataset_sha256")})
    return {
        "grant_id": grant_id, "revoked": grant.get("revoked_at") is not None, "affected_snapshots": affected,
        "action": "Mark these snapshots unavailable for future jobs; remove authorized local/remote copies through the retention workflow.",
        "limits": "This local report cannot discover unregistered copies or erase influence from already-trained weights.",
    }

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from PIL import Image, ImageOps

from .artifacts import assemble, export_sam, verify_snapshot, withdrawal_impact, write_json
from .data import Invalid, authorize, file_hash, identifier, load_dataset, read_json, require
from .demo import create_demo
from .evaluate import compare, evaluate, html_report
from .experiments import doctor, plan


def main(argv=None):
    parser = argparse.ArgumentParser(description="FindEZ local Vision Lab. No production connection or deployment.")
    subs = parser.add_subparsers(dest="command", required=True)
    p = subs.add_parser("demo", help="Generate synthetic software-test images and predictions")
    p.add_argument("destination")
    p = subs.add_parser("ingest", help="Copy one owned image, normalize orientation and strip metadata")
    p.add_argument("image"); p.add_argument("destination"); p.add_argument("--id", required=True)
    p.add_argument("--group", required=True); p.add_argument("--physical-object", action="append", default=[])
    p.add_argument("--split", choices=["train", "validation", "test"], required=True)
    p = subs.add_parser("assemble", help="Combine local datasets while checking for split leakage")
    p.add_argument("datasets", nargs="+"); p.add_argument("--output", required=True); p.add_argument("--id", required=True)
    p = subs.add_parser("validate")
    p.add_argument("dataset"); p.add_argument("--verified", action="store_true")
    p.add_argument("--ledger"); p.add_argument("--purpose", default="evaluation")
    p = subs.add_parser("grant", help="Record a local creator-owned data attestation; not customer consent")
    p.add_argument("dataset"); p.add_argument("output"); p.add_argument("--reviewer", required=True)
    p.add_argument("--purpose", action="append", choices=["evaluation","segmentation_training","recognition_training","ocr_training"], required=True)
    p.add_argument("--days", type=int, default=30)
    p.add_argument("--attest-owned-and-sensitive-content-reviewed", action="store_true")
    p = subs.add_parser("evaluate")
    p.add_argument("dataset"); p.add_argument("predictions"); p.add_argument("--ledger", required=True)
    p.add_argument("--split", choices=["train","validation","test"], default="test")
    p.add_argument("--iou", type=float, default=.5); p.add_argument("--output", required=True)
    p = subs.add_parser("compare")
    p.add_argument("baseline"); p.add_argument("candidate"); p.add_argument("--policy", required=True)
    p.add_argument("--output", required=True)
    p = subs.add_parser("export-sam")
    p.add_argument("dataset"); p.add_argument("--ledger", required=True); p.add_argument("--output", required=True)
    p = subs.add_parser("verify-snapshot")
    p.add_argument("snapshot"); p.add_argument("--ledger", required=True)
    p = subs.add_parser("revoke")
    p.add_argument("ledger"); p.add_argument("grant_id"); p.add_argument("--output", required=True)
    p.add_argument("--snapshot", action="append", default=[])
    p = subs.add_parser("plan")
    p.add_argument("job"); p.add_argument("--snapshot", required=True); p.add_argument("--ledger", required=True)
    p = subs.add_parser("serve")
    p.add_argument("dataset"); p.add_argument("--port", type=int, default=8790)
    subs.add_parser("doctor")
    args = parser.parse_args(argv)
    try:
        result = execute(args)
        if result is not None:
            print(json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False))
        return 0
    except (Invalid, ValueError, KeyError, TypeError, OSError) as exc:
        print(f"Stopped: {exc}", file=sys.stderr)
        return 2


def execute(a):
    if a.command == "assemble":
        data = assemble(a.datasets, a.output, a.id)
        return {"created": a.output, "samples": len(data["samples"]), "permissions_copied": False}
    if a.command == "demo":
        return {"created": str(create_demo(a.destination)), "synthetic": True, "model_training": False}
    if a.command == "ingest":
        identifier(a.id); identifier(a.group)
        for name in a.physical_object:
            identifier(name)
        root = Path(a.destination)
        require(not root.exists(), "Destination exists")
        with Image.open(a.image) as source:
            require(source.width*source.height <= 16_000_000, "Image exceeds pixel limit")
            require(source.format in ("PNG","JPEG"), "Convert image to PNG/JPEG before ingest")
            normalized = ImageOps.exif_transpose(source).convert("RGB")
            clean = Image.new("RGB", normalized.size)
            clean.paste(normalized)
        (root/"images").mkdir(parents=True)
        path = root/"images"/f"{a.id}.png"; clean.save(path)
        sample = {"id": a.id, "group_id": a.group, "physical_object_ids": a.physical_object,
                  "split": a.split, "tags": [], "image": {"path": f"images/{a.id}.png",
                  "sha256": file_hash(path), "width": clean.width, "height": clean.height},
                  "provenance": {"source_type": "owned", "grant_id": "owned_pilot"},
                  "annotation": {"status": "draft", "source": "human", "label_origin": "independent_human", "reviewer": "", "objects": []}}
        write_json(root/"dataset.json", {"version": 1, "id": a.id, "samples": [sample]})
        return {"created": str(root), "permission_granted": False, "next": "Review the image, then record a separate rights attestation."}
    if a.command == "validate":
        data = load_dataset(a.dataset, verified=a.verified)
        if a.ledger:
            authorize(data, read_json(a.ledger), a.purpose)
        return {"valid": True, "samples": len(data["samples"]), "permission_checked": bool(a.ledger)}
    if a.command == "grant":
        require(a.attest_owned_and_sensitive_content_reviewed, "Explicit ownership and sensitive-content attestation required")
        require(1 <= a.days <= 365 and a.reviewer.strip(), "Choose a reviewer and 1-365 days")
        data = load_dataset(a.dataset)
        require(all(s["provenance"]["source_type"] == "owned" for s in data["samples"]), "This command supports creator-owned pilot images only")
        now = datetime.now(timezone.utc)
        ids = {s["provenance"]["grant_id"] for s in data["samples"]}
        grants = [{"id": gid, "source_type": "owned", "rights_basis": "creator_owned",
                   "approved_by": a.reviewer.strip(), "granted_at": now.isoformat(),
                   "expires_at": (now+timedelta(days=a.days)).isoformat(), "revoked_at": None,
                   "sensitive_content_reviewed": True, "uses": sorted(set(a.purpose)),
                   "asset_sha256": [s["image"]["sha256"] for s in data["samples"] if s["provenance"]["grant_id"] == gid]}
                  for gid in sorted(ids)]
        write_json(a.output, {"version": 1, "grants": grants})
        return {"created": a.output, "authority": "Local operator attestation; not production customer consent"}
    if a.command == "evaluate":
        data = load_dataset(a.dataset, verified=True)
        authorize({**data, "samples": [s for s in data["samples"] if s["split"] == a.split]},
                  read_json(a.ledger), "evaluation")
        result = evaluate(data, read_json(a.predictions), Path(a.dataset).resolve().parent, split=a.split, threshold=a.iou)
        path = Path(a.output)
        require(path.suffix == ".json", "Evaluation output must end in .json")
        require(not path.exists() and not path.with_suffix(".html").exists(), "Report output already exists")
        write_json(path, result)
        path.with_suffix(".html").write_text(html_report(result))
        return {"report": str(path), "html": str(path.with_suffix(".html")), "summary": result["summary"], "synthetic": result["synthetic"]}
    if a.command == "compare":
        result = compare(read_json(a.baseline), read_json(a.candidate), read_json(a.policy))
        write_json(a.output, result)
        return result
    if a.command == "export-sam":
        result = export_sam(a.dataset, a.ledger, a.output)
        return {"snapshot": a.output, "samples": len(result["samples"]), "test_images_included": False, "training_executed": False}
    if a.command == "verify-snapshot":
        result = verify_snapshot(a.snapshot, a.ledger)
        return {"valid": True, "synthetic": result["synthetic"], "permission_rechecked": True}
    if a.command == "revoke":
        ledger = read_json(a.ledger)
        grant = next((g for g in ledger["grants"] if g["id"] == a.grant_id), None)
        require(grant is not None, "Grant not found")
        grant["revoked_at"] = datetime.now(timezone.utc).isoformat()
        write_json(a.output, ledger)
        return withdrawal_impact(ledger, a.grant_id, a.snapshot)
    if a.command == "doctor":
        return doctor()
    if a.command == "plan":
        return plan(a.job, a.snapshot, a.ledger)
    if a.command == "serve":
        from .server import make_server
        server = make_server(a.dataset, a.port)
        print(f"Local review: http://127.0.0.1:{server.server_port}\nCtrl+C stops the server. No cloud uploads or production access.", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            server.server_close()

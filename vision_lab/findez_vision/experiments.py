"""Read-only experiment preflight. No SSH, GPU launch or deployment capability."""
import platform
import re
import shutil
import subprocess
from pathlib import Path

from .artifacts import verify_snapshot
from .data import file_hash, read_json


def doctor():
    result = {"python": platform.python_version(), "platform": platform.system(),
              "local_only": True, "gpu_check": "not_available"}
    executable = shutil.which("nvidia-smi")
    if executable:
        try:
            p = subprocess.run([executable, "--query-gpu=name,memory.total,driver_version",
                                "--format=csv,noheader"], capture_output=True, text=True, timeout=10)
            result["gpu_check"] = p.stdout.strip() if p.returncode == 0 else "nvidia-smi failed"
        except subprocess.TimeoutExpired:
            result["gpu_check"] = "nvidia-smi timed out"
    return result


def plan(job_path, snapshot_path, ledger_path):
    job = read_json(job_path)
    snapshot = verify_snapshot(snapshot_path, ledger_path)
    blockers = []
    for name in ("model_license_reviewed", "gpu_allocation_confirmed", "environment_smoke_test_passed"):
        if job.get(name) is not True:
            blockers.append(f"Operator must verify {name}")
    if job.get("mode") != "sam_segmentation_experiment":
        blockers.append("Unsupported experiment mode")
    revision = job.get("upstream_commit", "")
    if not isinstance(revision, str) or not re.fullmatch(r"[a-f0-9]{40}", revision):
        blockers.append("Pin the exact upstream SAM repository commit")
    source = Path(job.get("upstream_checkout") or "/nonexistent-findez-source")
    actual = None
    if (source/"training/train.py").is_file():
        try:
            actual = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL).strip()
            dirty = subprocess.check_output(["git", "-C", str(source), "status", "--porcelain"], text=True).strip()
            if actual != revision or dirty:
                blockers.append("Upstream checkout does not match the pinned clean revision")
        except subprocess.CalledProcessError:
            blockers.append("Cannot verify upstream repository")
    else:
        blockers.append("Upstream SAM training checkout is not available here")
    for name in ("checkpoint", "training_config"):
        path = Path(job.get(name) or "/nonexistent-findez-file")
        expected = job.get(name+"_sha256")
        if not path.is_file() or not isinstance(expected, str) or not re.fullmatch(r"[a-f0-9]{64}", expected):
            blockers.append(f"Supply reviewed {name} and its SHA256")
        elif file_hash(path) != expected:
            blockers.append(f"{name} checksum does not match")
    if type(job.get("max_runtime_minutes")) is not int or not 1 <= job["max_runtime_minutes"] <= 1440:
        blockers.append("Set an explicit experiment runtime budget of 1-1440 minutes")
    if job.get("production_access") is not False:
        blockers.append("Training must declare production_access=false")
    return {
        "version": 1, "ready_for_operator_review": not blockers,
        "blockers": blockers, "snapshot_dataset": snapshot["source_dataset_sha256"],
        "synthetic": snapshot["synthetic"], "training_executed": False,
        "actual_upstream_commit": actual,
        "notes": [
            "Preflight is not a sandbox or GPU compatibility test.",
            "The operator supplies and reviews the official training configuration; no guessed training recipe is run.",
            "Use train.txt and validation.txt separately, one frame per image. Held-out test images are not exported.",
            "An approved preflight still cannot deploy a checkpoint or start training from this toolkit.",
        ],
    }

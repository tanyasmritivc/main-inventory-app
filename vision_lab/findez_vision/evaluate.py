"""Offline, class-agnostic instance matching and conditional identity/OCR metrics."""
from __future__ import annotations

import html
import math
import re
from pathlib import Path

from PIL import ImageChops, ImageFilter

from .data import digest, mask_for, require, text
from . import __version__


def area(mask):
    return mask.histogram()[255]


def overlap(a, b):
    intersection = area(ImageChops.multiply(a, b))
    union = area(a) + area(b) - intersection
    return intersection / union if union else 0.0


def matching(scores, threshold):
    """Maximum-cardinality matching, preferring larger IoU within each search.

    This is NOT COCO AP or maximum-total-IoU assignment. The objective is TP count
    at one fixed, declared threshold, with deterministic input ordering.
    """
    right = {}
    def visit(i, seen):
        for j in sorted(range(len(scores[i])), key=lambda j: (-scores[i][j], j)):
            if scores[i][j] < threshold or j in seen:
                continue
            seen.add(j)
            if j not in right or visit(right[j], seen):
                right[j] = i
                return True
        return False
    for i in range(len(scores)):
        visit(i, set())
    return sorted((i, j) for j, i in right.items())


def boundary_score(a, b, tolerance=1):
    """Boundary F1 in original-image pixels, conditional on an instance match."""
    ba = ImageChops.subtract(a, a.filter(ImageFilter.MinFilter(3)))
    bb = ImageChops.subtract(b, b.filter(ImageFilter.MinFilter(3)))
    na, nb = area(ba), area(bb)
    if not na or not nb:
        return None
    size = 2 * tolerance + 1
    precision = area(ImageChops.multiply(bb, ba.filter(ImageFilter.MaxFilter(size)))) / nb
    recall = area(ImageChops.multiply(ba, bb.filter(ImageFilter.MaxFilter(size)))) / na
    return 2 * precision * recall / (precision + recall) if precision + recall else 0.0


def edit_distance(a, b):
    row = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        new = [i]
        for j, y in enumerate(b, 1):
            new.append(min(new[-1] + 1, row[j] + 1, row[j-1] + (x != y)))
        row = new
    return row[-1]


def ratio(a, b):
    return a / b if b else None


def summarize(rows):
    sums = {k: sum(r[k] for r in rows) for k in (
        "tp", "fp", "fn", "truth_objects", "predicted_objects", "identity_correct",
        "identity_evaluable", "ocr_edits", "ocr_characters", "ocr_exact", "ocr_evaluable",
        "possible_merges", "possible_splits", "confident_wrong_identity")}
    p = ratio(sums["tp"], sums["tp"] + sums["fp"])
    r = ratio(sums["tp"], sums["tp"] + sums["fn"])
    ious = [v for row in rows for v in row["matched_ious"]]
    boundaries = [v for row in rows for v in row["boundary_f1"] if v is not None]
    times = sorted(row["latency_ms"] for row in rows if row["latency_ms"] is not None)
    return {
        **sums, "images": len(rows), "precision": p, "recall": r,
        "f1": ratio(2 * sums["tp"], 2 * sums["tp"] + sums["fp"] + sums["fn"]),
        "matched_mean_iou": ratio(sum(ious), len(ious)),
        "matched_boundary_f1_1px": ratio(sum(boundaries), len(boundaries)),
        "identity_accuracy_on_matches": ratio(sums["identity_correct"], sums["identity_evaluable"]),
        "ocr_character_error_rate_on_matches": ratio(sums["ocr_edits"], sums["ocr_characters"]),
        "ocr_exact_accuracy_on_matches": ratio(sums["ocr_exact"], sums["ocr_evaluable"]),
        "negative_images": sum(r["truth_objects"] == 0 for r in rows),
        "negative_images_with_false_positives": sum(r["truth_objects"] == 0 and r["fp"] > 0 for r in rows),
        "latency_samples": len(times),
        "p95_latency_ms": times[math.ceil(len(times) * .95)-1] if times else None,
    }


def evaluate(dataset, predictions, root, *, split="test", threshold=.5):
    require(type(threshold) in (int, float) and math.isfinite(threshold) and 0 < threshold <= 1,
            "IoU threshold must be in (0,1]")
    require(isinstance(predictions, dict) and predictions.get("version") == 1, "Prediction version must be 1")
    require(predictions.get("dataset_sha256") == digest(dataset), "Predictions belong to a different dataset revision")
    run = predictions.get("run")
    require(isinstance(run, dict) and bool(text(run.get("id"), "run id")), "Prediction run identity is required")
    require(run.get("kind") in ("synthetic", "model"), "Run kind must be synthetic or model")
    if run["kind"] == "model":
        for field in ("model_revision", "pipeline_revision"):
            require(bool(text(run.get(field), field)), f"Missing {field}")
        require(run.get("protocol") in ("sam_fixed_box", "find_end_to_end"), "Declare the evaluation protocol")
        require(isinstance(run.get("model_sha256"), str) and re.fullmatch(r"[a-f0-9]{64}", run["model_sha256"]),
                "Record the model checkpoint or multi-model manifest SHA256")
    rows = predictions.get("samples")
    require(isinstance(rows, list), "Prediction samples must be a list")
    by_id = {}
    for row in rows:
        require(isinstance(row, dict) and row.get("id") not in by_id, "Duplicate/invalid prediction sample")
        by_id[row.get("id")] = row
    chosen = [s for s in dataset["samples"] if s["split"] == split]
    require(bool(chosen), f"No samples in {split}")
    require(set(by_id) == {s["id"] for s in chosen}, "Predictions must include every selected image exactly once, including empty results")
    results = []
    for sample in chosen:
        truth = sample["annotation"]["objects"]
        predicted = by_id[sample["id"]].get("objects")
        require(isinstance(predicted, list) and len(predicted) <= 255, "Invalid predicted objects")
        size = (sample["image"]["width"], sample["image"]["height"])
        require(size[0] * size[1] * (len(truth) + len(predicted)) <= 64_000_000,
                "Raster evaluation budget exceeded; use a reviewed smaller benchmark image")
        ids = [o.get("id") for o in predicted if isinstance(o, dict)]
        require(len(ids) == len(predicted) and len(set(ids)) == len(ids), "Duplicate prediction object IDs")
        for obj in predicted:
            for field in ("identity", "ocr"):
                if field in obj:
                    text(obj[field], field, 4000 if field == "ocr" else 200)
            confidence = obj.get("confidence", 0)
            require(type(confidence) in (int, float) and math.isfinite(confidence) and 0 <= confidence <= 1,
                    "Confidence must be finite and between zero and one")
        gt = [mask_for(o, size, root) for o in truth]
        pred = [mask_for(o, size, root) for o in predicted]
        scores = [[overlap(a, b) for b in pred] for a in gt]
        pairs = matching(scores, threshold)
        latency = by_id[sample["id"]].get("latency_ms")
        require(latency is None or (type(latency) in (int, float) and math.isfinite(latency) and latency >= 0),
                "Latency must be a finite non-negative number")
        row = dict(id=sample["id"], tags=sample.get("tags", []), tp=len(pairs),
                   fp=len(pred)-len(pairs), fn=len(gt)-len(pairs), truth_objects=len(gt),
                   predicted_objects=len(pred), matched_ious=[scores[i][j] for i, j in pairs],
                   boundary_f1=[boundary_score(gt[i], pred[j]) for i, j in pairs],
                   identity_correct=0, identity_evaluable=0, ocr_edits=0, ocr_characters=0,
                   ocr_exact=0, ocr_evaluable=0, confident_wrong_identity=0,
                   possible_merges=0, possible_splits=0, latency_ms=latency)
        for i, j in pairs:
            a, b = truth[i], predicted[j]
            if a.get("identity"):  # Empty means identity is not annotated, not "unknown".
                correct = a["identity"] == b.get("identity")
                row["identity_evaluable"] += 1
                row["identity_correct"] += correct
                row["confident_wrong_identity"] += not correct and b.get("confidence", 0) >= .8
            if "ocr" in a:
                expected, actual = a["ocr"], b.get("ocr", "")
                row["ocr_evaluable"] += 1
                row["ocr_edits"] += edit_distance(expected, actual)
                row["ocr_characters"] += len(expected)
                row["ocr_exact"] += expected == actual
        # Diagnostic heuristics, not primary quality scores.
        row["possible_merges"] = sum(sum(area(ImageChops.multiply(a, b)) / max(area(a), 1) >= .5 for a in gt) > 1 for b in pred)
        row["possible_splits"] = sum(sum(area(ImageChops.multiply(a, b)) / max(area(b), 1) >= .5 for b in pred) > 1 for a in gt)
        results.append(row)
    tags = sorted({tag for row in results for tag in row["tags"]})
    return {
        "version": 1, "evaluator": __version__, "dataset_id": dataset["id"],
        "dataset_sha256": digest(dataset), "prediction_sha256": digest(predictions),
        "split": split, "iou_threshold": threshold, "run": run,
        "synthetic": run["kind"] == "synthetic" or any(s["provenance"]["source_type"] == "synthetic" for s in chosen),
        "summary": summarize(results),
        "slices": {tag: summarize([r for r in results if tag in r["tags"]]) for tag in tags},
        "images": results,
        "limits": [
            "IoU >= threshold, class-agnostic maximum-cardinality matching; not COCO AP.",
            "Identity/OCR metrics are conditional on matched objects; inspect missed objects separately.",
            "Boundary tolerance is one pixel at the stored image resolution.",
            "Merge/split counts are overlap heuristics. Latency is supplied by the runner, not measured here.",
            "Small or synthetic benchmarks cannot establish production model quality.",
        ],
    }


def html_report(report):
    esc = lambda v: html.escape(str(v))
    summary = "".join(f"<tr><th>{esc(k)}</th><td>{esc(round(v, 4) if isinstance(v, float) else v)}</td></tr>"
                      for k, v in report["summary"].items())
    rows = "".join(f"<tr><td>{esc(r['id'])}</td><td>{r['tp']}</td><td>{r['fp']}</td><td>{r['fn']}</td><td>{esc(', '.join(r['tags']))}</td></tr>"
                   for r in report["images"])
    slices = "".join(
        "<tr><td>"+esc(tag)+"</td>"+"".join(
            "<td>"+esc("Unmeasured" if values[key] is None else
                       round(values[key], 4) if isinstance(values[key], float) else values[key])+"</td>"
            for key in ("images", "recall", "precision", "f1"))+"</tr>"
        for tag, values in report["slices"].items())
    notice = "SYNTHETIC SOFTWARE TEST - NOT MODEL PERFORMANCE" if report["synthetic"] else "Offline benchmark - review sample coverage before interpreting results"
    return f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>FindEZ vision evaluation</title><style>body{{font:16px system-ui;color:#282622;background:#faf9f6;max-width:1000px;margin:40px auto;padding:20px}}table{{border-collapse:collapse;width:100%;margin:20px 0}}td,th{{text-align:left;padding:9px;border-bottom:1px solid #ddd}}aside{{padding:16px;background:#fff0ca}}small{{overflow-wrap:anywhere}}</style>
<h1>FindEZ vision evaluation</h1><aside>{notice}</aside><p>Dataset: {esc(report['dataset_id'])}. Run: {esc(report['run']['id'])}.</p>
<small>Dataset SHA256: {esc(report['dataset_sha256'])}</small><h2>Results</h2><table>{summary}</table>
<h2>Conditions</h2><table><tr><th>Condition</th><th>Images</th><th>Recall</th><th>Precision</th><th>F1</th></tr>{slices}</table>
<h2>Images</h2><table><tr><th>Sample</th><th>Matched</th><th>Extra</th><th>Missed</th><th>Conditions</th></tr>{rows}</table>
<h2>Interpretation</h2><ul>{''.join('<li>'+esc(x)+'</li>' for x in report['limits'])}</ul></html>"""


def compare(baseline, candidate, policy):
    for field in ("dataset_sha256", "split", "iou_threshold", "evaluator"):
        require(baseline.get(field) == candidate.get(field), f"Comparison {field} differs")
    require(baseline.get("run", {}).get("protocol") == candidate.get("run", {}).get("protocol"),
            "Comparison protocols differ")
    reasons = []
    if policy.get("approved") is not True:
        reasons.append("Threshold policy is a draft; set thresholds before evaluating candidates.")
    if baseline.get("synthetic") or candidate.get("synthetic"):
        reasons.append("Synthetic evidence cannot qualify a model for production.")
    minimum = policy.get("minimum_images")
    require(type(minimum) is int and minimum > 0, "minimum_images must be positive")
    if candidate["summary"]["images"] < minimum:
        reasons.append("Insufficient evaluation images.")
    rules = policy.get("rules")
    require(isinstance(rules, list) and bool(rules), "Comparison needs explicit metric rules")
    results = []
    for rule in rules:
        metric, direction, tolerance = rule.get("metric"), rule.get("direction"), rule.get("allowed_regression")
        require(direction in ("higher", "lower") and type(tolerance) in (int, float) and math.isfinite(tolerance) and tolerance >= 0,
                "Invalid comparison rule")
        slice_name = rule.get("slice")
        source_a = baseline["summary"] if slice_name is None else baseline.get("slices", {}).get(slice_name, {})
        source_b = candidate["summary"] if slice_name is None else candidate.get("slices", {}).get(slice_name, {})
        a, b = source_a.get(metric), source_b.get(metric)
        ok = type(a) in (int, float) and type(b) in (int, float) and math.isfinite(a) and math.isfinite(b)
        if ok:
            ok = b >= a-tolerance if direction == "higher" else b <= a+tolerance
        results.append({"metric": metric, "slice": slice_name, "baseline": a, "candidate": b, "passed": bool(ok)})
        if not ok:
            reasons.append(f"Metric failed or is unmeasured: {metric} ({slice_name or 'overall'})")
    required = policy.get("required_slices", {})
    require(isinstance(required, dict), "Invalid required slices")
    for tag, count in required.items():
        require(type(count) is int and count > 0, "Slice minimum must be positive")
        if candidate.get("slices", {}).get(tag, {}).get("images", 0) < count:
            reasons.append(f"Insufficient coverage for {tag}")
    return {"eligible_for_human_review": not reasons, "automatic_promotion": False,
            "metrics": results, "reasons": reasons,
            "next_step": "Human review of per-slice regressions, provenance, runtime and rollback is still required."}

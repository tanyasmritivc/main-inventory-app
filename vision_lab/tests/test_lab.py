import copy
import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path

from PIL import Image
from PIL.PngImagePlugin import PngInfo

from findez_vision.artifacts import assemble, export_sam, verify_snapshot, withdrawal_impact, write_json
from findez_vision.cli import main
from findez_vision.data import Invalid, authorize, digest, file_hash, load_dataset, mask_for, read_json, safe_file, validate_dataset
from findez_vision.demo import create_demo
from findez_vision.evaluate import compare, evaluate, html_report, matching
from findez_vision.experiments import plan


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = create_demo(Path(self.tmp.name)/"demo")
        self.data = load_dataset(self.root/"dataset.json", verified=True)
        self.ledger = read_json(self.root/"grants.json")
        self.good = read_json(self.root/"predictions-good.json")
        self.bad = read_json(self.root/"predictions-merged.json")

    def write(self, name, data):
        path = self.root/name
        path.write_text(json.dumps(data))
        return path

    def cli(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = main([str(a) for a in args])
        return code, out.getvalue(), err.getvalue()


class ValidationTests(Fixture):
    def test_demo_is_valid_but_is_explicitly_synthetic(self):
        self.assertTrue(authorize(self.data, self.ledger, "evaluation"))
        self.assertTrue(all(s["provenance"]["source_type"] == "synthetic" for s in self.data["samples"]))

    def test_cross_split_capture_group_blocked(self):
        self.data["samples"][1]["group_id"] = self.data["samples"][0]["group_id"]
        with self.assertRaisesRegex(Invalid, "cross dataset splits"):
            validate_dataset(self.data, self.root)

    def test_cross_split_physical_object_blocked(self):
        for s in self.data["samples"][:2]:
            s["physical_object_ids"] = ["same_motor"]
        with self.assertRaisesRegex(Invalid, "cross dataset splits"):
            validate_dataset(self.data, self.root)

    def test_same_object_within_same_split_allowed(self):
        for s in self.data["samples"][:2]:
            s["physical_object_ids"] = ["same_motor"]
            s["split"] = "train"
        validate_dataset(self.data, self.root)

    def test_identical_image_in_another_split_blocked(self):
        self.data["samples"][1]["image"] = copy.deepcopy(self.data["samples"][0]["image"])
        with self.assertRaisesRegex(Invalid, "cross dataset splits"):
            validate_dataset(self.data, self.root)

    def test_same_decoded_pixels_different_encoding_blocked(self):
        first, second = self.data["samples"][:2]
        target = self.root/second["image"]["path"]
        with Image.open(self.root/first["image"]["path"]) as im:
            im.save(target, compress_level=0)
        second["image"]["sha256"] = file_hash(target)
        self.assertNotEqual(first["image"]["sha256"], second["image"]["sha256"])
        with self.assertRaisesRegex(Invalid, "cross dataset splits"):
            validate_dataset(self.data, self.root)

    def test_hash_mismatch_blocked(self):
        self.data["samples"][0]["image"]["sha256"] = "0"*64
        with self.assertRaisesRegex(Invalid, "checksum"):
            validate_dataset(self.data, self.root)

    def test_missing_review_and_model_provenance_blocked(self):
        for field, value in (("reviewer", ""), ("label_origin", None), ("status", "draft")):
            with self.subTest(field=field):
                data = copy.deepcopy(self.data)
                data["samples"][0]["annotation"][field] = value
                with self.assertRaises(Invalid):
                    validate_dataset(data, self.root, verified=True)

    def test_customer_data_not_enabled(self):
        self.data["samples"][0]["provenance"]["source_type"] = "customer"
        with self.assertRaisesRegex(Invalid, "not enabled"):
            validate_dataset(self.data, self.root)

    def test_paths_and_symlinks_blocked(self):
        for path in ("../demo/dataset.json", "/etc/passwd", "images\\scene_0.png", "missing.png"):
            with self.subTest(path=path), self.assertRaises(Invalid):
                safe_file(self.root, path)
        (self.root/"linked.png").symlink_to(self.root/"images/scene_0.png")
        with self.assertRaisesRegex(Invalid, "symlink"):
            safe_file(self.root, "linked.png")

    def test_metadata_rejected(self):
        sample = self.data["samples"][0]
        path = self.root/sample["image"]["path"]
        with Image.open(path) as image:
            exif = Image.Exif()
            exif[315] = "private metadata"
            image.save(path, exif=exif)
        sample["image"]["sha256"] = file_hash(path)
        with self.assertRaisesRegex(Invalid, "metadata"):
            validate_dataset(self.data, self.root)

    def test_png_text_metadata_rejected(self):
        sample = self.data["samples"][0]
        path = self.root/sample["image"]["path"]
        metadata = PngInfo()
        metadata.add_text("Description", "private information")
        with Image.open(path) as image:
            image.save(path, pnginfo=metadata)
        sample["image"]["sha256"] = file_hash(path)
        with self.assertRaisesRegex(Invalid, "metadata"):
            validate_dataset(self.data, self.root)

    def test_invalid_polygon_geometry(self):
        polygons = (
            [[0,0],[64,0],[5,5]],
            [[1,1],[2,2],[3,3]],
            [[0,0],[10,0],[0,10],[10,10],[8,4]],
            [[0,0],[10,0],[10,10],[0,0]],
            [[0,0],[float("nan"),0],[10,10]],
        )
        for polygon in polygons:
            with self.subTest(polygon=polygon), self.assertRaises(Invalid):
                mask_for({"id": "object", "polygons": [polygon]}, (64,48), self.root)

    def test_overlap_rejected_for_ground_truth(self):
        annotation = self.data["samples"][0]["annotation"]
        annotation["objects"][1]["polygons"] = annotation["objects"][0]["polygons"]
        with self.assertRaisesRegex(Invalid, "overlap"):
            validate_dataset(self.data, self.root)

    def test_binary_masks_and_holes(self):
        image = Image.new("L", (64,48), 255)
        image.paste(0, (10,10,20,20))
        path = self.root/"mask.png"
        image.save(path)
        obj = {"id": "hole", "mask": {"path": "mask.png", "sha256": file_hash(path)}}
        self.assertEqual(mask_for(obj, (64,48), self.root).getpixel((15,15)), 0)
        image.putpixel((0,0), 5)
        image.save(path)
        obj["mask"]["sha256"] = file_hash(path)
        with self.assertRaisesRegex(Invalid, "only 0 and 255"):
            mask_for(obj, (64,48), self.root)

    def test_duplicate_json_keys_and_nonfinite_numbers(self):
        for value in ('{"a":1,"a":2}', '{"a":NaN}', '{"a":Infinity}'):
            path = self.root/"bad.json"
            path.write_text(value)
            with self.assertRaises(Invalid):
                read_json(path)


class PermissionTests(Fixture):
    def test_revoked_expired_future_wrong_purpose_foreign_asset_and_unreviewed(self):
        now = datetime.now(timezone.utc)
        cases = [
            ("revoked_at", now.isoformat()),
            ("expires_at", (now-timedelta(days=1)).isoformat()),
            ("granted_at", (now+timedelta(days=1)).isoformat()),
            ("uses", ["ocr_training"]),
            ("asset_sha256", []),
            ("sensitive_content_reviewed", False),
            ("approved_by", ""),
            ("rights_basis", "scraped"),
            ("source_type", "owned"),
        ]
        for key, value in cases:
            with self.subTest(key=key):
                ledger = copy.deepcopy(self.ledger)
                ledger["grants"][0][key] = value
                with self.assertRaises(Invalid):
                    authorize(self.data, ledger, "segmentation_training", now=now)

    def test_review_does_not_erase_model_assisted_label_restrictions(self):
        self.data["samples"][0]["annotation"]["label_origin"] = "model_assisted"
        self.assertTrue(authorize(self.data, self.ledger, "evaluation"))
        with self.assertRaisesRegex(Invalid, "license"):
            authorize(self.data, self.ledger, "segmentation_training")

    def test_unverified_training_label_blocked(self):
        self.data["samples"][0]["annotation"]["status"] = "draft"
        with self.assertRaisesRegex(Invalid, "verified"):
            authorize(self.data, self.ledger, "segmentation_training")

    def test_duplicate_or_missing_grant_blocked(self):
        for grants in ([], self.ledger["grants"]*2):
            with self.assertRaises(Invalid):
                authorize(self.data, {"version":1, "grants":grants}, "evaluation")


class EvaluationTests(Fixture):
    def test_perfect_and_merged_predictions_have_different_scores(self):
        good = evaluate(self.data, self.good, self.root)
        bad = evaluate(self.data, self.bad, self.root)
        self.assertEqual(good["summary"]["f1"], 1)
        self.assertEqual(good["summary"]["matched_mean_iou"], 1)
        self.assertEqual(good["summary"]["identity_accuracy_on_matches"], 1)
        self.assertEqual(good["summary"]["ocr_character_error_rate_on_matches"], 0)
        self.assertEqual(bad["summary"]["possible_merges"], 1)
        self.assertLess(bad["summary"]["f1"], good["summary"]["f1"])
        self.assertIsNone(good["summary"]["p95_latency_ms"])

    def test_matching_handles_greedy_trap(self):
        pairs = matching([[.9,.7],[.8,.1]], .5)
        self.assertEqual(pairs, [(0,1),(1,0)])

    def test_empty_predictions_and_negative_false_positive(self):
        p = copy.deepcopy(self.good)
        p["samples"][1]["objects"] = p["samples"][0]["objects"][:1]
        p["samples"][0]["objects"] = []
        result = evaluate(self.data, p, self.root)["summary"]
        self.assertEqual((result["tp"], result["fp"], result["fn"]), (0,1,2))
        self.assertEqual(result["negative_images_with_false_positives"], 1)
        self.assertIsNone(result["matched_mean_iou"])

    def test_prediction_revision_coverage_and_provenance_required(self):
        variants = [
            {**self.good, "dataset_sha256": "wrong"},
            {**self.good, "samples": self.good["samples"][:1]},
            {**self.good, "samples": self.good["samples"]*2},
            {**self.good, "run": {"id":"run", "kind":"model"}},
        ]
        for p in variants:
            with self.assertRaises(Invalid):
                evaluate(self.data, p, self.root)

    def test_nonfinite_confidence_and_latency_rejected(self):
        for name in ("confidence", "latency_ms"):
            p = copy.deepcopy(self.good)
            target = p["samples"][0]["objects"][0] if name == "confidence" else p["samples"][0]
            target[name] = float("nan")
            with self.assertRaises(Invalid):
                evaluate(self.data, p, self.root)

    def test_identity_and_ocr_errors_counted(self):
        self.good["samples"][0]["objects"][0].update(identity="wrong", confidence=.95, ocr="M13")
        result = evaluate(self.data, self.good, self.root)["summary"]
        self.assertEqual(result["confident_wrong_identity"], 1)
        self.assertEqual(result["identity_accuracy_on_matches"], .5)
        self.assertAlmostEqual(result["ocr_character_error_rate_on_matches"], 1/3)

    def test_html_escapes_untrusted_labels(self):
        self.good["run"]["id"] = "<script>alert(1)</script>"
        html = html_report(evaluate(self.data, self.good, self.root))
        self.assertNotIn("<script>", html)
        self.assertIn("&lt;script&gt;", html)

    def test_synthetic_cannot_pass_even_approved_policy(self):
        report = evaluate(self.data, self.good, self.root)
        policy = {"approved":True, "minimum_images":1, "rules":[{"metric":"f1", "direction":"higher", "allowed_regression":0}]}
        result = compare(report, report, policy)
        self.assertFalse(result["eligible_for_human_review"])
        self.assertFalse(result["automatic_promotion"])
        self.assertIn("Synthetic", " ".join(result["reasons"]))

    def test_comparison_rejects_different_benchmark(self):
        report = evaluate(self.data, self.good, self.root)
        with self.assertRaisesRegex(Invalid, "differs"):
            compare(report, {**report, "dataset_sha256":"other"}, {})

    def test_slice_rules_and_unmeasured_metrics_block_comparison(self):
        report = evaluate(self.data, self.good, self.root)
        candidate = copy.deepcopy(report)
        candidate["slices"]["two_objects"]["recall"] = .5
        policy = {"approved":True, "minimum_images":1,
                  "rules":[{"metric":"recall", "slice":"two_objects", "direction":"higher", "allowed_regression":0},
                           {"metric":"p95_latency_ms", "direction":"lower", "allowed_regression":0}]}
        result = compare(report, candidate, policy)
        self.assertTrue(all(not metric["passed"] for metric in result["metrics"]))

    def test_fixed_box_cannot_be_compared_to_end_to_end(self):
        report = evaluate(self.data, self.good, self.root)
        candidate = copy.deepcopy(report)
        report["run"]["protocol"] = "sam_fixed_box"
        candidate["run"]["protocol"] = "find_end_to_end"
        with self.assertRaisesRegex(Invalid, "protocols differ"):
            compare(report, candidate, {})


class ArtifactTests(Fixture):
    def export(self):
        target = self.root/"export"
        export_sam(self.root/"dataset.json", self.root/"grants.json", target)
        return target/"snapshot.json"

    def test_export_has_no_test_images_and_preserves_instance_ids(self):
        snapshot = self.export()
        data = verify_snapshot(snapshot, self.root/"grants.json")
        self.assertEqual([s["id"] for s in data["samples"]], ["scene_0","scene_1"])
        self.assertFalse((snapshot.parent/"JPEGImages/scene_2").exists())
        with Image.open(snapshot.parent/"Annotations/scene_0/00000.png") as im:
            self.assertEqual(set(im.tobytes()), {0,1,2})
            # The official PalettisedPNGSegmentLoader converts to P before reading IDs.
            self.assertEqual(im.convert("P").tobytes(), im.tobytes())

    def test_unauthorized_export_writes_no_directory(self):
        self.ledger["grants"][0]["revoked_at"] = datetime.now(timezone.utc).isoformat()
        self.write("grants.json", self.ledger)
        with self.assertRaises(Invalid):
            self.export()
        self.assertFalse((self.root/"export").exists())

    def test_export_rechecks_current_permission_and_reports_withdrawal(self):
        snapshot = self.export()
        self.ledger["grants"][0]["revoked_at"] = datetime.now(timezone.utc).isoformat()
        ledger = self.write("withdrawn.json", self.ledger)
        with self.assertRaisesRegex(Invalid, "withdrawn"):
            verify_snapshot(snapshot, ledger)
        result = withdrawal_impact(self.ledger, "synthetic_demo", [snapshot])
        self.assertEqual(len(result["affected_snapshots"]), 1)

    def test_snapshot_tampering_incomplete_inventory_and_extra_files_rejected(self):
        snapshot = self.export()
        original = read_json(snapshot)
        for modify in ("hash", "inventory", "extra"):
            with self.subTest(modify=modify):
                data = copy.deepcopy(original)
                if modify == "hash":
                    data["files"]["train.txt"] = "wrong"
                elif modify == "inventory":
                    del data["files"]["train.txt"]
                else:
                    (snapshot.parent/"unexpected.txt").write_text("not in snapshot")
                snapshot.write_text(json.dumps(data))
                with self.assertRaises(Invalid):
                    verify_snapshot(snapshot, self.root/"grants.json")
                (snapshot.parent/"unexpected.txt").unlink(missing_ok=True)
        snapshot.write_text(json.dumps(original))

    def test_assemble_rejects_duplicates_and_leakage_without_partial_output(self):
        output = self.root/"assembled"
        with self.assertRaises(Invalid):
            assemble([self.root/"dataset.json"]*2, output, "combined")
        self.assertFalse(output.exists())
        first = {**self.data, "samples":[self.data["samples"][0]]}
        second = {**self.data, "samples":[copy.deepcopy(self.data["samples"][1])]}
        second["samples"][0]["group_id"] = first["samples"][0]["group_id"]
        a, b = self.write("first.json", first), self.write("second.json", second)
        with self.assertRaisesRegex(Invalid, "cross dataset"):
            assemble([a,b], output, "combined")
        self.assertFalse(output.exists())

    def test_assemble_copies_self_contained_dataset(self):
        output = self.root/"assembled"
        assemble([self.root/"dataset.json"], output, "combined")
        data = load_dataset(output/"dataset.json", verified=True)
        self.assertEqual(len(data["samples"]), 4)
        self.assertFalse((output/"grants.json").exists())

    def test_plan_blocks_unverified_server_facts(self):
        snapshot = self.export()
        job = self.write("job.json", {"mode":"sam_segmentation_experiment", "production_access":False})
        result = plan(job, snapshot, self.root/"grants.json")
        self.assertFalse(result["ready_for_operator_review"])
        self.assertGreaterEqual(len(result["blockers"]), 7)
        self.assertFalse(result["training_executed"])

    def test_cli_workflow_and_revocation(self):
        dataset, ledger = self.root/"dataset.json", self.root/"grants.json"
        self.assertEqual(self.cli("validate", dataset, "--verified", "--ledger", ledger)[0], 0)
        report = self.root/"report.json"
        self.assertEqual(self.cli("evaluate", dataset, self.root/"predictions-good.json", "--ledger", ledger, "--output", report)[0], 0)
        self.assertTrue(report.with_suffix(".html").exists())
        snapshot = self.export()
        revoked = self.root/"revoked.json"
        self.assertEqual(self.cli("revoke", ledger, "synthetic_demo", "--output", revoked, "--snapshot", snapshot)[0], 0)
        code, _, error = self.cli("verify-snapshot", snapshot, "--ledger", revoked)
        self.assertEqual(code, 2)
        self.assertIn("withdrawn", error)

    def test_ingest_removes_metadata_and_grant_requires_attestation(self):
        source = self.root/"owned.jpg"
        exif = Image.Exif()
        exif[315], exif[274] = "private", 6
        Image.new("RGB", (20,30), "red").save(source, exif=exif)
        output = self.root/"owned"
        self.assertEqual(self.cli("ingest", source, output, "--id", "owned", "--group", "session1", "--split", "train")[0], 0)
        data = load_dataset(output/"dataset.json")
        self.assertEqual(data["samples"][0]["image"]["width"], 30)
        grant = output/"grants.json"
        args = ("grant", output/"dataset.json", grant, "--reviewer","Tanya","--purpose","evaluation")
        self.assertEqual(self.cli(*args)[0], 2)
        self.assertFalse(grant.exists())
        self.assertEqual(self.cli(*args, "--attest-owned-and-sensitive-content-reviewed")[0], 0)
        self.assertTrue(authorize(data, read_json(grant), "evaluation"))


if __name__ == "__main__":
    unittest.main()

# Dataset, annotation and prediction contract v1

JSON files are UTF-8. Duplicate keys and non-finite JSON numbers are rejected.
File paths are relative to the dataset JSON directory; absolute paths, traversal
and symlinks are rejected. File fingerprints use SHA256.

## Dataset

The `demo` and `ingest` commands generate complete examples.

```json
{
  "version": 1,
  "id": "owned_pilot",
  "samples": [{
    "id": "drawer_001",
    "group_id": "drawer_session_a",
    "physical_object_ids": ["motor_001"],
    "split": "train",
    "tags": ["small_objects", "overlap"],
    "image": {
      "path": "images/drawer_001.png",
      "width": 640,
      "height": 480,
      "sha256": "REPLACE_WITH_ACTUAL_FILE_SHA256"
    },
    "provenance": {"source_type": "owned", "grant_id": "owned_pilot"},
    "annotation": {
      "status": "verified",
      "source": "human",
      "label_origin": "independent_human",
      "reviewer": "Tanya",
      "reviewed_at": "2026-10-19T12:00:00-07:00",
      "objects": [{
        "id": "motor_001",
        "label": "Motor",
        "polygons": [[[10,10],[100,10],[100,80],[10,80]]]
      }]
    }
  }]
}
```

This is a schema illustration, not a usable dataset until real files, hashes and
correct labels are supplied. IDs contain ASCII letters, numbers, `_` and `-`,
start with a letter/number and have at most 80 characters.

### Image and split rules

- JPEG/PNG only, at most 16 million pixels and 32 MB per file. Ingest strips
  metadata and normalizes rotation. Photos needing redaction must be redacted
  before ingest and manually checked afterward; this tool has no automatic PII detector.
- `train`, `validation` and `test` are explicit assignments.
- A capture `group_id`, physical object ID, identical file or identical decoded
  RGB pixels cannot span splits. Similar/compressed/rotated views that are not
  exact duplicates still require correct group IDs and human duplicate review.
- The split is stable across revisions. Do not move a difficult test example
  into training and keep advertising the same test result.
- Tags describe conditions. Suggested tags: `overlap`, `small_objects`,
  `reflective`, `transparent`, `low_light`, `unfamiliar`, `tiny_text`, `negative`.
  Tag counts are not proof that a sample represents the intended population.

### Label rules

Draw **visible-instance** masks: only pixels visible in the image, not an
imagined complete shape behind another object. Label every target object.
The first benchmark must define its target-object policy before annotation.
If a scene cannot be exhaustively labeled under that policy, keep it draft or
rejected; v1 does not implement ignore regions.

- `objects: []` in a verified scene means a deliberately reviewed negative.
- Polygons use original-image pixel-center coordinates:
  `0 <= x <= width-1`, `0 <= y <= height-1`. Do not append the first point again.
  The rasterizer fills boundaries inclusively. Polygon lists are unions, not holes.
- Self-crossing, zero-area, repeated-point and overlapping ground-truth masks
  are rejected. Different predicted masks may overlap because that is a model error
  worth measuring.
- For holes or intricate contours, replace `polygons` with
  `"mask": {"path": "masks/object.png", "sha256": "..."}`. The mask is a source-size
  grayscale PNG containing only 0 and 255. Holes are 0. Binary masks are read-only
  in the browser polygon editor.
- `label` is a short descriptive category. `identity` is an optional verified
  exact identifier, or the explicit string `unknown` if that is the benchmark's
  correct answer. Omit identity when it has not been independently annotated.
- `ocr` is an optional exact visible transcription. Omit it when unannotated.
  An explicit empty string means the reviewer verified that there is no text.
  The browser's blank OCR field omits annotation; use JSON for an explicit
  no-text reference.
- `source` records the review source. `label_origin` records how the label
  originally arose: `independent_human`, `synthetic_authored`, or `model_assisted`.
  Reviewing a model output does not make its origin independent.

An inventory record corrected by its owner might identify an object but say
nothing about its exact pixel boundary. Never convert such an edit into a
segmentation label automatically.

## Prediction interchange

The GPU operator or a later FIND adapter produces this structure:

```json
{
  "version": 1,
  "dataset_sha256": "CANONICAL_DATASET_DIGEST",
  "run": {
    "id": "baseline_001",
    "kind": "model",
    "protocol": "find_end_to_end",
    "model_revision": "operator-recorded-model-manifest-v1",
    "model_sha256": "ACTUAL_CHECKPOINT_OR_MULTI_MODEL_MANIFEST_SHA256",
    "pipeline_revision": "EXACT_SOURCE_COMMIT"
  },
  "samples": [{
    "id": "test_001",
    "latency_ms": 1234.5,
    "objects": [{
      "id": "predicted_001",
      "mask": {"path": "predictions/baseline_001/test_001/object_001.png", "sha256": "ACTUAL_MASK_SHA256"},
      "identity": "unknown",
      "confidence": 0.4
    }]
  }]
}
```

Supply all selected split images exactly once, including `objects: []` for
zero detections. Masks are relative to the dataset root. Copy returned
prediction masks into a **new run directory** under that root; do not overwrite
source images or annotations. The canonical dataset digest is computed by
`findez_vision.data.digest`, not the raw JSON file hash.

`sam_fixed_box` and `find_end_to_end` are separate protocols. A fixed-box
experiment supplies reviewed object boxes to measure SAM mask quality. It
cannot establish automatic detection/separation recall because it gives SAM
object-location hints. End-to-end FIND must discover objects itself. Never
compare these protocols as if they were the same task.

For multi-model FIND runs, attach an immutable model manifest containing each
checkpoint hash, engine/wrapper commit, quantization, configuration and
preprocessing. `model_sha256` fingerprints that manifest. Include the original
manifest with returned evidence; this evaluator checks the reference format,
not possession or runtime loading of those weights.

Record hardware, precision, batch size, warmup and timing boundary in additional
run fields. Measure GPU latency after synchronization. Report errors and OOMs
separately; never omit failed images to improve a score.

## Evaluation interpretation

- Matching is class-agnostic, maximum-cardinality at a declared IoU threshold.
  IoU measures mask intersection divided by mask union. This is not COCO AP.
- Extra detections count as false positives; missing objects as false negatives.
- Matched mask IoU and boundary F1 are conditional on a successful match.
  Always inspect recall alongside them. One-pixel boundary tolerance depends
  on the stored image resolution.
- Identity and OCR metrics apply to matched objects with annotated references.
  Missing identity is wrong when a verified reference exists. OCR is exact,
  case-sensitive and unnormalized. An unmeasured metric is `null`, not zero.
- Merge/split counts use overlap heuristics and need human interpretation.
- Latency is reported by the prediction producer, not independently timed by
  the offline evaluator. Missing latency stays unmeasured.
- Comparison policies can include `slice` on a rule to check a specific tag.
  Slice minimums only check coverage; add explicit slice metric rules to gate
  regressions. A passing report only qualifies for human review.

## Export and withdrawal

SAM exports contain `JPEGImages/<id>/00000.jpg`,
`Annotations/<id>/00000.png`, `train.txt`, `validation.txt` and `snapshot.json`.
Instance masks are PNG values 1..N, with 0 for background. JPEG conversion and
its parameters are fixed; exported bytes have their own hashes.

Snapshots copy train/validation data only. Their source dataset digest references
the original full manifest; store that original securely for lineage. The
snapshot is immutable by convention and checksum, not cryptographically signed.
A person who can edit both its files and manifest can forge it.

```sh
vision_lab/.venv/bin/findez-vision revoke CURRENT_LEDGER.json GRANT_ID --output REVOKED_LEDGER.json --snapshot EXPORT_DIR/snapshot.json
```

This writes a new ledger and lists affected **supplied** snapshots. Switch
all subsequent checks to that ledger and retire the old copy. It does not
magically invalidate old ledger files, discover remote copies, delete artifacts
or remove influence from trained weights. Production needs the authenticated
revocation workflow described in [PERMISSIONS.md](PERMISSIONS.md).

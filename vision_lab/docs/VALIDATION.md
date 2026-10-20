# Local preparation validation

Date: 2026-10-19. Branch: `feat/vision-lab-local-20261019`.
Scope: isolated `vision_lab/`, its CI workflow and repository documentation.

## Executed locally

Environment: macOS, Python 3.14.6, Pillow 13.0.0, setuptools 82.0.1.
Editable package installation succeeded with dependencies pinned.

- 57 unittest cases, including loopback HTTP integration tests.
- JavaScript syntax check and Python module compilation.
- Synthetic CLI workflow: create demo, validate, evaluate correct/merged
  predictions, export SAM snapshot, recheck snapshot, compare and preflight.
- Actual Chrome UI: initial rendering; edit an object description; save draft;
  enter reviewer and verify; reload and observe persistence; draw a new polygon,
  finish it and save as draft. Browser testing used a separate synthetic dataset.
- Source inspection for transport/process operations: only loopback HTTP,
  local Git metadata checks, macOS HEIC conversion and optional local
  `nvidia-smi` inspection.
- Actual Chrome file picker: imported the supplied 4032 x 3024 HEIC photo into
  an isolated QA dataset, observed the new draft and rendered image, with the
  four existing synthetic samples retained. No remote upload or training grant.

## What the tests exercise

| Area | Evidence |
| --- | --- |
| Data validity | Bad hashes, invalid dimensions/paths, symlinks, EXIF/PNG metadata, bad polygons, overlapping ground-truth masks and binary mask values |
| Split integrity | Capture-group, physical-object, file and decoded-pixel duplicates across splits denied |
| Permission | Missing/duplicate/expired/future/revoked/wrong-purpose grants, uncovered assets, unreviewed sensitive content and unsupported sources denied |
| Label provenance | Drafts cannot train; model-assisted origin survives human review and remains blocked for training |
| Evaluation | Perfect versus merged masks, a greedy-matching trap, missed/extra objects, negative-scene false positives, exact identity/OCR errors, missing and non-finite measurements |
| Comparison | Different datasets/protocols denied; synthetic data, draft policy, insufficient coverage, unmeasured metrics and failed slice rules cannot qualify |
| Export | Train/validation only, per-instance PNG IDs preserved through upstream-style palette conversion, checksums and current permissions rechecked, extra/missing files denied |
| Browser HTTP | Loopback binding, hostile Host/Origin/token rejection, stale-save conflict, history/persistence, invalid save leaves file unchanged, no arbitrary-file route, binary-mask samples read-only |
| Local workflow | Ingest normalizes orientation/strips metadata; assembly copies data and rejects leakage; grant needs attestation; withdrawal invalidates recheck against the new ledger |
| Browser photo import | Preserves existing annotations; normalizes orientation and strips metadata; requires ownership/content check; rejects duplicate photos, unsafe inputs and stale revisions; failed writes remove only the new image; Unicode names remain display text; no training grant |

## Synthetic demonstration

Two held-out synthetic scenes contain two reference objects and one empty scene.
Exact predictions score F1 1.0. A deliberately merged prediction scores F1 0.0
at IoU >= 0.5 and triggers the merge diagnostic. These deliberately simple
values test scoring behavior; they are **not** FindEZ or SAM performance.

The export contains two train/validation scenes and excludes both test scenes.
The draft job preflight lists the missing operator configuration and does not
start a job. Comparison correctly blocks qualification despite improved
synthetic scores.

## Limits and work awaiting inputs

- Confirmed model identities are accepted from Tanya. Loaded weight hashes,
  FIND source/configuration, GPU allocation and environment are still needed.
- No actual SAM, depth, Qwen or OCR inference/training was run.
- No claim of improved recognition, segmentation accuracy or production latency.
- No real-image benchmark or independent human annotation-quality audit yet.
- No private FIND adapter, GPU training recipe or CUDA compatibility claim.
- No recognition/OCR training exporter or automated training scheduler.
- Production consent/collection/deletion remains a documented design; local
  ledger files cannot authenticate users or revoke copies held elsewhere.
- Desktop Chrome interaction checked; no claim of exhaustive browser,
  accessibility or touch-device acceptance for this developer tool.
- The configured CI matrix adds Python 3.11/3.14 on Linux. Remote CI results
  should be read from the actual run; this receipt records local execution.

No backend, website runtime, mobile, production database or GPU-server changes.
No deployment, model promotion, customer-data collection or transfer to the
operator was performed.

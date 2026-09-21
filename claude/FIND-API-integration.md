# FIND pipeline — API integration guide

Version: 2026-09-18 · Service: FIND ingestion pipeline (`find-api`) · Contact: Vinod Rex (owner)

This document is for an app developer integrating the FIND pipeline. It covers connection details, the
input format, every endpoint, the complete output format with field-by-field descriptions, the
coordinate systems, timing and limits, and error handling.

**A note on the source of this file:** the original copy (`~/Downloads/FIND-API-integration.md`) embeds
the live plaintext FIND API key. That copy is confidential. This copy, committed to the repo, has the
key redacted per this repo's own rule in `CLAUDE.md` ("Never print secrets into a chat or a commit").
The real key belongs only in `backend/.env` / the production `.env` as `FIND_API_KEY`, matching how
`backend/app/core/config.py` already reads it. If you need the live key, it is in
`~/Downloads/FIND-API-integration.md` on the machine that has it, or in the production environment file
— never here.

---

## 1. What the pipeline does

You upload one photo of a shelf, bin or bench. The server:

1. **segment** — Qwen3-VL lists the objects it sees (boxes); Depth Anything V2 finds the surface and paints the
   background grey; SAM 2 cuts one mask per physical object (from its own point grid, depth-foreground blobs and the
   Qwen boxes). Each object gets a crop rotated so its long axis is vertical.
2. **extract** — barcode decoding and OCR on every crop.
3. **identify** — Qwen3-VL answers "what is this thing?" for every crop: name, category, vendor and part number if
   printed, confidence, one-sentence reasoning.
4. **measure** — if the photo contains a length reference (a ruler, tape, caliper with printed scale, or an ArUco /
   AprilTag marker of known size) every object gets millimetre dimensions: oriented size, area, outline polygon and
   per-edge lengths. The reference itself is removed from the object list and reported separately.

Typical end-to-end time for a phone photo: 3–8 s (more with many objects, ~1 s per object for identification, up to
six in parallel). Nothing is persisted by the API beyond an in-memory job (6 h TTL); a copy of finished jobs is
archived on the server for debugging.

---

## 2. Connection

| | |
|---|---|
| Public base URL | `http://pipeline.findez.ai/` (HTTP only; no TLS on this host today) |
| LAN base URL | `http://10.20.0.10:8030/` |
| Auth | HTTP header `Authorization: Bearer <API_KEY>` on every `/v1/*` call (`/health` is open) |
| **API key** | Redacted here — see `backend/.env` (`FIND_API_KEY`) or the production `.env`. Never paste the plaintext key into this file, a commit, or chat. |
| Content types | Upload: `multipart/form-data`; JSON bodies: `application/json`; images returned as `image/jpeg` / `image/png` |

A missing or wrong key returns **401** `{"detail": "invalid bearer token"}`.

Quick check:

```bash
export FIND_API_KEY="<from backend/.env>"
curl -s http://pipeline.findez.ai/health | jq .status          # "ok"
curl -s -H "Authorization: Bearer $FIND_API_KEY" http://pipeline.findez.ai/v1/models | jq .
```

---

## 3. Input

| Field | Where | Format | Notes |
|---|---|---|---|
| `image` | multipart file, `POST /v1/jobs` | JPEG, PNG, WebP, BMP | Longest side is downscaled to **4096 px** server-side; recommended 1536–2048 px longest side (an iPhone photo scaled by 0.5). Everything (boxes, crops) is reported in the pixel frame of the **stored** image, whose `width`/`height` come back in the job. |
| `space` | multipart form field, optional | string | Free text stamped on the job (location / bin name). |
| `params` | JSON body of `POST /v1/jobs/{id}/run` (or per-stage endpoints) | object keyed by stage | See §4.3. |

Photo guidance for best results: roughly top-down, objects not overlapping, plain surface, and **a ruler with printed
numbers lying flat next to the objects** if you want millimetres. A 50 mm ArUco marker (DICT_4X4_50) works too and also
corrects perspective.

---

## 4. Endpoints

### 4.1 Create a job

`POST /v1/jobs` — multipart: `image` (file), `space` (optional text) → **202**

```json
{"job_id": "job_8594b6668df44ef7", "state": "QUEUED", "partial": false, "running_stage": null, "filename": "camera.jpg",
 "width": 1536, "height": 2048, "space": "bench", "item_count": 0, "identified_count": 0, "unknown_count": 0,
 "ocr_text_count": 0, "item_error_count": 0, "suppressed_count": 0, "reference_count": 0, "measured_count": 0,
 "timings_s": {}, "errors": [], "created_at": 1789750000.1, "updated_at": 1789750000.1, "completed_at": null,
 "done": false, "nbytes": 812345}
```

Errors: **400** empty upload / undecodable image; **429** job store full (64 jobs / 2 GB) — retry later.

### 4.2 Run the whole pipeline

`POST /v1/jobs/{job_id}/run` — JSON body `{"params": {...}, "stop_after": null}` → **202** (returns the job; work
continues in the background). Then poll `GET /v1/jobs/{job_id}` until `done` is `true` or `state` is `FAILED`.
Poll every 0.5–3 s. `running_stage` tells you which stage is active.

States: `QUEUED → SEGMENTED → EXTRACTED → IDENTIFIED → MEASURED`. `FAILED` only when segmentation itself fails.
`partial: true` means at least one object had a branch error (see `items[].errors`) — results are still usable.

### 4.3 Run parameters

```json
{"params": {
  "segment":  {"background": "depth", "vlm_proposals": "qwen3vl"},
  "identify": {},
  "measure":  {"marker_size_mm": 50.0}
}}
```

| Stage | Key | Values | Default | Effect |
|---|---|---|---|---|
| segment | `background` | `none` \| `depth` | `none` (server) — the tester app sends `depth` | Depth-based background removal before SAM. Best for raised parts on a plain surface; can drop very flat/dark items. |
| segment | `vlm_proposals` | `none` \| `qwen3vl` | `qwen3vl` | Qwen3-VL object boxes as extra SAM prompts (recovers occluded / thin objects, keeps a keyboard as one object). Adds one VLM call (1–7 s). |
| segment | any `isolate.*` field | e.g. `points_per_side`, `min_area_px`, `crop_orientation` (`vertical`\|`horizontal`) | see server config | Advanced tuning. |
| measure | `marker_size_mm` | number | 50.0 | Printed side length of your ArUco/AprilTag markers. |
| measure | `drop_references` | bool | true | Keep the ruler in `items` if false. |
| measure | `enabled` | bool | true | Skip measuring. |

Per-stage endpoints exist for step-by-step control: `POST /v1/jobs/{id}/segment`, `/extract`, `/identify`, `/measure`
with the same `params` (unwrapped, e.g. `{"params": {"background": "depth"}}`) → **200** `{"job", "stage", "report",
"items" (stage-specific subset), ...}`; **409** if the previous stage has not run or the job is busy. Re-running an
earlier stage invalidates later results.

### 4.4 Read results

| Method | Path | Returns |
|---|---|---|
| GET | `/v1/jobs/{id}` | Job status (same shape as §4.1) |
| GET | `/v1/jobs/{id}/result` | **Full result document** (§5) |
| GET | `/v1/jobs/{id}/items/{item_id}/crop.jpg?crop_max=512&masked=true` | The object's crop (long axis vertical). `masked=true` = background painted grey. `crop_max` downsizes the longest side (0 = full size). |
| GET | `/v1/jobs/{id}/items/{item_id}/mask.png` | Binary mask (0/255) in stored-image coordinates. 404 if the item has no mask. |
| GET | `/v1/jobs/{id}/annotated.jpg?max_px=1600` | Stored image with outlines and labels drawn (green = identified, orange = unknown). |
| GET | `/v1/jobs/{id}/image.jpg` | The stored (possibly downscaled) upload. |
| GET | `/v1/jobs/{id}/background.jpg` | What SAM saw after background removal (404 when that step did not run). |
| GET | `/v1/jobs` | All jobs in memory + store stats. |
| DELETE | `/v1/jobs/{id}` | Free the job (409 while running). |
| GET | `/health` | Component readiness, GPU memory, job store (no auth). |
| GET | `/v1/models` | The models behind each stage and whether they are reachable. |

All image endpoints need the bearer header too (do not use a plain `<img src>`; fetch with the header).

---

## 5. Output: the result document

`GET /v1/jobs/{id}/result` → JSON object. Field reference (types in brackets; `?` = may be null):

### 5.1 Top level

| Field | Type | Meaning |
|---|---|---|
| `job_id`, `state`, `partial`, `running_stage`, `filename`, `space` | string/bool | As in §4.1 |
| `width`, `height` | int | Pixel size of the stored image; **all coordinates below are in this frame** |
| `item_count`, `identified_count`, `unknown_count`, `ocr_text_count`, `item_error_count`, `suppressed_count`, `reference_count`, `measured_count` | int | Counters over `items` (references are not counted in `item_count`) |
| `timings_s` | object | Seconds per stage: `segment`, `extract`, `identify`, `measure` |
| `errors` | string[] | Job-level stage errors (usually empty) |
| `created_at`, `updated_at`, `completed_at?` | float | Unix seconds |
| `done` | bool | Pipeline finished for this run |
| `items` | Item[] | One entry per detected object (§5.2) |
| `suppressed` | object[] | Segments dropped because a confidently identified larger object contains them: `{item_id, inside, inside_name, inside_confidence, contained, by, own_name, own_confidence}` |
| `references` | Reference[] | Length references found (§5.5); these items are removed from `items` |
| `scale` | object | The scale used for dimensions: `{method: "ruler"\|"aruco"\|null, reference: item_id\|marker id\|null, mm_per_px?, confidence: "high"\|"medium"\|"low"\|null, assumption: text}` |
| `background` | object? | Background-removal diagnostics: `mode` (`none`\|`depth`), `planes` (inlier fraction per fitted surface), `rejected_surfaces`, `foreground_frac`, `masks_dropped`, `grid_points`, `points_prompted`, `prompted_blobs`, `prompted_masks` |
| `vlm_models` | object | `{key: {model, label, enabled, reachable}}` — currently `{"qwen3vl": {"model": "qwen3-vl-8b", "label": "Qwen3-VL-8B", ...}}` |
| `vlm_primary` | string | Key of the model that fills `identity` (`qwen3vl`) |
| `vlm_model` | string | Model id of the primary VLM |
| `crop_orientation` | string | `vertical` (crops have their long axis vertical) or `horizontal` |
| `stage_reports` | object | Per-stage diagnostics (§7) |

### 5.2 Item (one object)

| Field | Type | Meaning |
|---|---|---|
| `item_id` | string | `it_0001`, `it_0002`, … (numbering is per job; gaps appear where references/suppressed were removed) |
| `bbox` | [x, y, w, h] | Axis-aligned box, stored-image pixels |
| `obb` | [[x,y]×4]? | Oriented (minimum-area) rectangle corners, stored-image pixels |
| `obb_size` | [long, short]? | Oriented rectangle side lengths in px |
| `obb_angle` | float? | Degrees; rotating the image by this angle makes the object's long side horizontal |
| `mask_score` | float | SAM's predicted mask quality (0–1) |
| `low_confidence` | bool | `mask_score < 0.9` |
| `has_mask` | bool | Whether `mask.png` is available |
| `crop_size` | [w, h] | Size of the full-resolution crop in px (the served `crop.jpg` may be downscaled by `crop_max`) |
| `crop_rotation_deg` | float | Counter-clockwise rotation applied to the source to produce the crop |
| `objectness` | float? | Learned object-vs-fragment score (null when the filter is off) |
| `source` | string | Where the mask came from: `sam` (point grid), `fg->sam` (depth-foreground box prompt), `vlm->sam` (Qwen box prompt); suffixes `+split` / `+clean` mean the mask was split into regions / had crumbs removed |
| `proposal` | object? | `{label, box: [x1,y1,x2,y2], by}` when the mask came from a Qwen box (Qwen's own label for it) |
| `barcode` | object? | `{value, symbology, confidence, variant}` if a barcode/QR was decoded on the crop |
| `ocr` | object? | `{text, mean_conf, tier: "bulk"\|"hard", lines: [{text, conf, box: [x1,y1,x2,y2,x3,y3,x4,y4] in crop px}], latency_ms, bulk_text?, bulk_conf?}` — `text` joins the lines with newlines |
| `identity` | Identity? | The primary VLM's answer (§5.3) |
| `identities` | object? | `{vlm_key: Identity}` for every configured VLM (one entry today) |
| `dimensions` | Dimensions? | Millimetre dimensions (§5.4); null when no reference was found |
| `reference` | object? | Set only on reference items (which are moved to `references`) |
| `errors` | string[] | Branch errors for this object, e.g. `ocr_hard: TimeoutException: …` (the rest of the object is still valid) |

### 5.3 Identity

| Field | Type | Meaning |
|---|---|---|
| `model`, `label` | string | Model id / display name |
| `name` | string | Short generic name for a label, e.g. `black plastic bracket`, `14 mm wrench`, `micro servo` |
| `category` | string | One of `fastener, standoff, structure, motion, wheel, motor, electronics, battery, cable, tool, consumable, packaging, game, other` |
| `vendor` | string | Brand only if printed on the item, else `""` |
| `sku` | string | Part number only if printed on the item, else `""` |
| `confidence` | float | 0–1 |
| `unknown` | bool | `true` when the model could not tell (then `name` may be empty and confidence ≤ 0.3) |
| `reasoning` | string | One sentence of visual cues |
| `latency_ms` | float | VLM latency for this object |

### 5.4 Dimensions (millimetres)

Present when `scale.mm_per_px` is set. All values are in **mm**, in the **object frame**: origin at the centre of the
object's oriented rectangle, x along its long axis, y along its short axis. This frame is independent of the image
rotation and of the crop rotation, so edge lengths can be consumed directly.

| Field | Type | Meaning |
|---|---|---|
| `method` | `ruler` \| `aruco` | Which reference kind produced the scale |
| `reference` | string | `it_0001` (ruler item) or `aruco:DICT_4X4_50:7` |
| `confidence` | `high` \| `medium` \| `low` | `high` = label regression and tick pitch agree; `low` = few labels / no tick agreement |
| `unit` | `mm` | Always mm (inch/cm rulers are converted) |
| `mm_per_px` | float | Scalar scale in stored-image pixels (crops are never resized, so it applies to full-size crops too) |
| `perspective_corrected` | bool | `true` only with a marker (homography); with a ruler the scale is one scalar |
| `obb_mm` | [long, short] | Oriented size |
| `bbox_mm` | [w, h] | Axis-aligned box size (image frame) |
| `area_mm2` | float | Mask area |
| `obb_corners_mm` | [[x,y]×4] | Oriented rectangle corners in the object frame |
| `contour_mm` | [[x,y]…] | Mask outline simplified to ~1 mm, object frame, closed polygon (last connects to first) |
| `edges_mm` | float[] | Length of each consecutive outline edge (`contour_mm[i]`→`contour_mm[i+1]`) — **individual edge dimensions** |
| `crop_px_per_mm` | float | Pixels per mm in the **full-size** crop. If you display `crop.jpg?crop_max=N`, multiply by `served_width / crop_size[0]` |
| `frame` | string | Human-readable description of the frame |

Accuracy: with a ruler, the scale assumes objects lie on the same surface as the ruler at a similar distance, viewed
roughly top-down; expect a few percent error and more for tall objects or oblique photos. A marker removes the in-plane
perspective error. No reference → `dimensions: null` and `scale.assumption` explains why.

### 5.5 Reference

Ruler: `{kind: "ruler", id: item_id, name, unit: "mm"\|"cm"\|"inch", mm_per_px, px_per_mm, labels_read, labels_used,
label_step, residual_rms, tick_pitch_px?, tick_expected_px, tick_agrees, rotation_used, confidence}`.
Marker: `{kind: "aruco", id, dict, marker_id, corners: [[x,y]×4], side_px, mm_per_px, confidence: "high", unit: "mm"}`.

---

## 6. Complete example (real output, trimmed)

Ruler photo: a goBILDA ruler next to a small black plastic part. The ruler became the reference and left `items`.

```json
{
  "job_id": "job_b8509d1257c242ff",
  "state": "MEASURED",
  "partial": false,
  "running_stage": null,
  "filename": "camera.jpg",
  "width": 1536,
  "height": 2048,
  "space": "final",
  "item_count": 4,
  "identified_count": 3,
  "unknown_count": 1,
  "ocr_text_count": 1,
  "item_error_count": 0,
  "suppressed_count": 0,
  "reference_count": 1,
  "measured_count": 4,
  "timings_s": {
    "segment": 3.445,
    "extract": 1.639,
    "identify": 1.095,
    "measure": 0.778
  },
  "errors": [],
  "created_at": 1789751337.351884,
  "updated_at": 1789751344.3115785,
  "completed_at": 1789751344.3115826,
  "done": true,
  "nbytes": 867569,
  "items": [
    {
      "item_id": "it_0002",
      "bbox": [458.0, 1122.0, 160.0, 230.0],
      "mask_score": 0.9852,
      "low_confidence": false,
      "crop_size": [183, 264],
      "crop_rotation_deg": 180.0,
      "has_mask": true,
      "obb": [[458.0, 1122.0], [617.0, 1122.0], [617.0, 1350.0], [458.0, 1350.0]],
      "obb_size": [228.0, 159.0],
      "obb_angle": 90.0,
      "objectness": null,
      "source": "fg->sam",
      "barcode": null,
      "ocr": {
        "lines": [{"text": "N", "conf": null, "box": null}, "… "],
        "text": "N",
        "mean_conf": 0.9,
        "tier": "hard",
        "latency_ms": 49
      },
      "proposal": null,
      "identity": {
        "model": "qwen3-vl-8b",
        "label": "Qwen3-VL-8B",
        "name": "black plastic bracket",
        "category": "structure",
        "vendor": "",
        "sku": "",
        "confidence": 0.9,
        "unknown": false,
        "reasoning": "black plastic object with mounting flanges and a visible 'N' marking.",
        "latency_ms": 876
      },
      "identities": {
        "qwen3vl": {
          "model": "qwen3-vl-8b", "label": "Qwen3-VL-8B", "name": "black plastic bracket",
          "category": "structure", "vendor": "", "sku": "", "confidence": 0.9, "unknown": false,
          "reasoning": "black plastic object with mounting flanges and a visible 'N' marking.",
          "latency_ms": 876
        }
      },
      "dimensions": {
        "method": "ruler", "reference": "it_0001", "confidence": "high", "unit": "mm",
        "mm_per_px": 0.059003, "perspective_corrected": false,
        "obb_mm": [13.51, 9.38], "bbox_mm": [9.44, 13.57], "area_mm2": 114.6,
        "obb_corners_mm": [[-6.76, -4.69], [6.76, -4.69], [6.76, 4.69], [-6.76, 4.69]],
        "contour_mm": [[-6.64, -4.34], [-5.28, 4.57], [6.11, 4.1], [5.93, -4.51], "…"],
        "edges_mm": [9.01, 11.4, 8.62, 12.57, "…"],
        "crop_px_per_mm": 16.948,
        "frame": "origin at the oriented-rectangle centre, x along the long axis, y along the short axis; mm"
      },
      "reference": null,
      "errors": []
    },
    "… one entry per object"
  ],
  "suppressed": [],
  "references": [
    {
      "kind": "ruler", "id": "it_0001", "unit": "mm", "mm_per_px": 0.059003, "px_per_mm": 16.948,
      "labels_used": 12, "labels_read": 12, "label_step": 5.0, "residual_rms": 0.298,
      "tick_pitch_px": 17.23, "tick_expected_px": 16.95, "tick_agrees": true, "rotation_used": 180,
      "confidence": "high", "name": "hardware measure ruler"
    }
  ],
  "scale": {
    "method": "ruler", "reference": "it_0001", "mm_per_px": 0.059003, "confidence": "high",
    "assumption": "single scalar scale: objects on the same surface as the ruler at a similar distance, roughly top-down view"
  },
  "background": {
    "mode": "depth", "planes": [0.8392], "foreground_frac": 0.1413, "masks_dropped": 0,
    "points_prompted": 146, "prompted_blobs": 5
  },
  "vlm_models": {
    "qwen3vl": {"model": "qwen3-vl-8b", "label": "Qwen3-VL-8B", "enabled": true, "reachable": true}
  },
  "vlm_primary": "qwen3vl",
  "vlm_model": "qwen3-vl-8b",
  "crop_orientation": "vertical",
  "stage_reports": "{segment, extract, identify, measure} per-stage diagnostics (see §7)"
}
```

---

## 7. Stage reports (diagnostics)

`stage_reports.segment`: `candidates` (`sam`, `prompted`, `vlm`, `dropped_as_background`), `prefilter` (counts of
`tiny`, `background`, `nested`, `duplicate`, `split_disconnected`, `merged_fragments`), `background` (see §5.1),
`vlm_proposals` (`boxes`, `latency_ms`, `error?`), `timings_s` (`masks`, `filter`, `total`).
`stage_reports.extract`: `stats` per branch (`barcode`, `ocr`: ok/failed), `barcodes_decoded`, `ocr_with_text`,
`ocr_hard_tier` (attempted/succeeded).
`stage_reports.identify`: `asked`, `identified`, `unknown`, `failed`, `per_model`, `suppressed`, `suppressed_items`.
`stage_reports.measure`: `references`, `markers`, `rulers`, `candidates`, `measured`, `failed`, `scale`.

---

## 8. Coordinate systems, cheat sheet

- **Image frame**: pixels of the stored image (`width`×`height`), origin top-left. Used by `bbox`, `obb`, `mask.png`,
  `proposal.box`, `references[].corners`, `annotated.jpg`.
- **Crop frame**: pixels of the full-size crop (`crop_size`), after rotating the source by `crop_rotation_deg` so the
  object's long axis is vertical. Used by `ocr.lines[].box`. Served crops scale by `crop_max`.
- **Object frame (mm)**: origin at the oriented-rectangle centre, x along the long axis. Used by everything in
  `dimensions` except `bbox_mm`.

---

## 9. Limits, timing, errors

| Topic | Value |
|---|---|
| Upload | ≤ 4096 px longest side after server downscale; keep files under ~10 MB |
| Job store | 64 jobs / 2 GB in memory, 6 h TTL; delete jobs you are done with |
| Concurrency | One GPU; jobs run sequentially per stage. Expect 3–8 s per photo, +~1 s per object beyond six for identification |
| Rate | No rate limit; a `429` on create means the store is full |
| Errors | `400` bad image · `401` bad/missing key · `404` unknown job/item · `409` stage order / job busy · `429` store full · `503` models still loading (retry after a minute) |
| Determinism | SAM and depth outputs vary slightly run to run (fp16); object numbering may change between runs of the same photo |

---

## 10. Minimal client (Python)

```python
import time, requests, os
BASE = "http://pipeline.findez.ai"
H = {"Authorization": f"Bearer {os.environ['FIND_API_KEY']}"}

job = requests.post(f"{BASE}/v1/jobs", headers=H, files={"image": open("photo.jpg", "rb")}, data={"space": "bin-7"}).json()
jid = job["job_id"]
requests.post(f"{BASE}/v1/jobs/{jid}/run", headers=H, json={"params": {"segment": {"background": "depth", "vlm_proposals": "qwen3vl"}}})
while True:
    j = requests.get(f"{BASE}/v1/jobs/{jid}", headers=H).json()
    if j["done"] or j["state"] == "FAILED":
        break
    time.sleep(1)
r = requests.get(f"{BASE}/v1/jobs/{jid}/result", headers=H).json()
for it in r["items"]:
    idn = it.get("identity") or {}
    dims = it.get("dimensions") or {}
    print(it["item_id"], idn.get("name"), idn.get("confidence"), dims.get("obb_mm"), (it.get("ocr") or {}).get("text"))
crop = requests.get(f"{BASE}/v1/jobs/{jid}/items/it_0002/crop.jpg?crop_max=512&masked=true", headers=H).content
requests.delete(f"{BASE}/v1/jobs/{jid}", headers=H)
```

Swift/Kotlin: same flow; send the bearer header on every request including image fetches. A reference SwiftUI client
lives in the FIND repository under `ios/` (`APIClient.swift`, `APIModels.swift` mirror this document's field names).

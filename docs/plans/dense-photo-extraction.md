# Adaptive crowded-photo extraction

Backend-only update on `fix/dense-photo-extraction`, based on the deployed extraction202 service. Mobile/web consume the same existing extraction contract; no client UI, main-chat logic, save/destination behavior, database schema or model/provider changes.

The overview remains a 1,280-pixel view. For uploaded images larger than 1,400 pixels, dense/partial scenes, eight or more detections, or loose-part groups trigger four to six overlapping views from the original oriented source. Four workers share a bounded close-up deadline, reserving 90 seconds of the existing 240-second extraction budget for identification. Small/simple photos retain one grounding call. Close-up failure preserves overview results and marks the draft partial.

Local close-up coordinates map back to normalized source coordinates before crop generation. Duplicate observations are merged geometrically without adding their counts. Adjacent objects with the same name remain separate; whole views take precedence over cut tile edges. When close-ups resolve an inseparable group into multiple objects, the parent group is removed to avoid counting both, and coverage remains explicitly partial. Final result order and region IDs are independent of concurrent completion order.

Grounding can mark loose-part groups and occluded regions. Those retain unknown quantity evidence even if the detail model guesses a high-confidence count. Saving as-is and optional Review continue through the existing contracts. Labels and dimensions still require visible supporting text; no hidden quantities or dimensions are invented.

Validation so far: 1,542 local backend tests passed; 54 focused tests passed against an isolated overlay of current production sources. Tests cover overlap coverage, oriented coordinate mapping, cross-view deduplication, adjacent identical objects, group replacement, bounded concurrency, deadlines, failed sections and unknown counts. The original DNG stays untouched; a local 3,024 x 4,032 JPEG preview is used for the no-save live inference check. No inventory data is written by that check. Live-photo result and deployment are pending.

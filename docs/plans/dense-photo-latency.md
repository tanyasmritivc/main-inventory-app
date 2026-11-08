# Crowded photo latency

The crowded sample previously took 218.88 seconds and made 29 detail-model calls after overview/close-up grounding. Dense scans now use up to four numbered crops in a 2x2 contact sheet, preserving the former 620-pixel per-crop detail resolution. Six bounded workers read detail batches; six close-up workers cover all portrait sections in one wave. Scans below eight accepted regions retain two-crop batches. No detected-item limit is introduced.

Grounding coverage, coordinate mapping, duplicate merging, uncertainty and quantity evidence, original crops, crop storage, model/provider, deadlines and save/destination contracts remain unchanged. Main Chat and client UI are not changed. The shared backend serves existing web/mobile clients without a new binary.

Validation: 1,566 backend tests passed. New checks cover four-crop colour/index association, second-row identity indices, and six concurrent portrait sections. Existing 24-object coverage and failed-batch preservation checks pass. Live no-save benchmark and isolated production-candidate checks are in progress. Deploy only after the benchmark and five exact-commit CI checks pass; preserve all other production Python files.

# Photo scan timeout repair — November 5, 2026

Production Auto Extract requests failed during Grounding with `httpx.ReadTimeout` after40seconds. An isolated run of the same deployed model and prompts completed grounding in66.9seconds, identification calls in12.6–42.8seconds, and the full eight-item scan in130seconds. Two items remained truthfully unknown. These are individual diagnostic timings, not latency percentiles.

The repair permits110seconds per model call, bounded by a shared240second inference budget across grounding, JSON repair and detail workers. HTTP failures still do not automatically retry an already-paid request. Existing confidence, unknown, quantity, crop, review and explicit-save contracts are preserved. No model/provider change or migration.

Quiet world-chat photo scans emit an SSE comment at most every10seconds. The shipped mobile decoder ignores comments as events but receives the lines, keeping its two-minute idle timer alive without fake progress. This also covers a long JSON repair or uneven detail batches. The deployed proxy has a300second read timeout.

Validation before publication:1,543 backend tests passed, including59 focused extraction and world-photo route checks. New cases cover the110second cap, remaining-budget clamp, exhausted JSON-repair budget, worker context propagation/restoration and keepalive-before-draft ordering without duplicate extraction. The existing no-retry timeout test remains green. Live-source checks and release receipt will be recorded after deployment. No new mobile binary is required for this server-only fix.

# Photo scan timeout repair — November 5, 2026

Production Auto Extract requests failed during Grounding with `httpx.ReadTimeout` after 40 seconds. An isolated run of the same deployed model and prompts completed grounding in 66.9 seconds, identification calls in 12.6–42.8 seconds, and the full eight-item scan in 130 seconds. Two items remained truthfully unknown. These are individual diagnostic timings, not latency percentiles.

The repair permits 110 seconds per model call, bounded by a shared 240-second inference budget across grounding, JSON repair and detail workers. HTTP failures still do not automatically retry an already-paid request. Existing confidence, unknown, quantity, crop, review and explicit-save contracts are preserved. No model/provider change or migration.

Quiet world-chat photo scans emit an SSE comment at most every 10 seconds. The shipped mobile decoder ignores comments as events but receives the lines, keeping its two-minute idle timer alive without fake progress. This also covers a long JSON repair or uneven detail batches. The deployed proxy has a 300-second read timeout.

Validation before publication: 1,543 backend tests passed, including 59 focused extraction and world-photo route checks. New cases cover the 110-second cap, remaining-budget clamp, exhausted JSON-repair budget, worker context propagation/restoration and keepalive-before-draft ordering without duplicate extraction. The existing no-retry timeout test remains green. The same 59 focused checks passed against staged production source. No new mobile binary is required for this server-only fix.

Deployed runtime `ed734e56a3e292b23eb295b38c2a2a979af46626` from PR #318 after all five CI gates passed in run 42155054509. The two-file overlay preserved unrelated live source and passed API/database health checks. Rollback is retained at `/home/ubuntu/findez-scan-timeouts-20261105/backup`.

Two authenticated production HTTPS scans completed on their first attempts in 72.9 and 110.1 seconds, returning eight editable items each (one and zero unknowns respectively). The stream delivered five and nine keepalive comments, with no line gap above 10 seconds. Invalid authentication was rejected. Scans did not write inventory; the disposable account and all 18 test photos/crops were removed. No new mobile binary, schema change or customer database rewrite. These timings show recovery of slow scans, not a general speed improvement; inference can still fail beyond the bounded timeout. Receipt: `docs/photo-scan-timeouts-release.json`.

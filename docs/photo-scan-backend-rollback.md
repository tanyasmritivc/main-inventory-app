# Backend scan rollback - November 5, 2026

At the user's explicit request, restore the backend behavior from before the timeout repair. Keep the new Auto Extract UI in TestFlight 184. No mobile binary, model/provider, database or website changes.

Only `app/services/glm_extraction.py` and `app/api/routes/world_chat.py` are restored from the preserved production backup at `/home/ubuntu/findez-scan-timeouts-20261105/backup`. This removes the longer 110/240-second budgets and scan keepalive comments, restoring the prior 40-second per-call and 100-second inference budget and two detail workers. It restores known previous behavior; it is not a claim that the model's latency has improved.

The four-worker experiment was never deployed and PR #319 is closed. The briefly prepared mobile restore was canceled before build or upload; all 662 non-version mobile files were checked but those local release edits were discarded. Current mobile source remains build 184 unchanged.

Full backend tests, exact backup checksums, health and unrelated-source checks are recorded in the restoration receipt.

Completed: 1,538 backend tests passed. Exact two-file backup hashes restored; API and database health200; invalid authentication401; unrelated source unchanged. See docs/photo-scan-backend-rollback.json.

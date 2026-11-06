# Backend scan rollback - November 5, 2026

At the user's explicit request, restore the backend behavior from before the timeout repair. Keep the new Auto Extract UI in TestFlight184. No mobile binary, model/provider, database or website changes.

Only `app/services/glm_extraction.py` and `app/api/routes/world_chat.py` are restored from the preserved production backup at `/home/ubuntu/findez-scan-timeouts-20261105/backup`. This removes the longer110/240second budgets and scan keepalive comments, restoring the prior40second per-call and100second inference budget and two detail workers. It restores known previous behavior; it is not a claim that the model's latency has improved.

The four-worker experiment was never deployed and PR319 is closed. The briefly prepared mobile restore was canceled before build or upload; all662non-version mobile files were checked but those local release edits were discarded. Current mobile source remains build184 unchanged.

Full backend tests, exact backup checksums, health and unrelated-source checks are recorded in the restoration receipt.

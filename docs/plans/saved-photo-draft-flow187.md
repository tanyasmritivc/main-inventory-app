## November 5 — Saved photo comparison and draft destination creation

Branch `fix/saved-photo-draft-flow` adds an authorized exact-item gallery read for model visual comparison. The model must distinguish matching saved pixels from conflicting labels and unverifiable physical identity; no record is rewritten. Creation-only proposals bind to an unnamed existing draft with its revision. Confirmation selects the receipt Space, and repeated confirmation can recover the same destination. Mobile187 combines this with an explicit save action; original draft IDs, counts, photos, duplicate checks and retry semantics remain intact. Claims about a creation card require an actual action.

Validation: 1,562 backend tests;123 compatible staged-live-source tests (three unrelated existing source-drift cases excluded). Production has a newer broad gallery tool and other local changes; the six-file compatibility patch preserves those. No schema or customer-data change. Deployment pending.

Live reconciliation is retained in `saved-photo-draft-flow-live.patch`. The existing broad world_item_photos tool remains; the new world_compare_item_photo reads one exact authorized gallery. The model probe uses synthetic metadata and mocked storage only. Physical device/network acceptance remains separate from automated tests.

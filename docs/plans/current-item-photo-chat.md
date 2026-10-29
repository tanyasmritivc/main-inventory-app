# Current item photos in chat

The inventory UI showed photos which chat counted as absent. Existing uploaded locators contain `//storage/v1/object/...`; the AI photo parser only accepted `/storage/...`. Normalize leading separators on the configured storage origin, while retaining object-key validation and per-photo authorization. Do not fetch arbitrary URLs.

Fresh primary/gallery catalog reads expose current presence, item creation and photo attachment-event times. Missing timestamps and preserved original-scan events do not imply later attachment. Legacy items.created_at lacks a timezone; the live database timezone is UTC, so comparisons normalize naive values to UTC. Photos added after import remain usable. Metadata pages contain 25 items; vision pages contain four photos, with coverage and next offsets. Failed/unrecognized photo reads never become evidence that no photo exists.

The inventory assistant now has the same photo-reading capability, fixed to its current authorized inventory. Pixel inputs are ephemeral and removed from public traces/history; multimodal calls use the configured vision model. Organization boundaries, saves, tools unrelated to photos and existing clients are retained. No migration or client binary required.

Validation: 1,633 backend tests plus 10 subtests pass. Tests cover double-slash URL acceptance, foreign/traversal denial, later attachment and unknown/original timing, mixed timestamp formats, pagination, no-download metadata, actor/inventory boundary and private pixel delivery. Staged read-only checks against the affected organization found Hardware 298 items:103 with photos,195 without. All 298 paginated once without duplicates; one actual image loaded and GLM described its visible contents. Attachment times compare correctly after UTC normalization. No inventory writes. Release pending.

Follow-up: user clarified they require genuine final-generation streaming, not bounded presentation of an already completed answer. Current stable-delivery policy must be replaced without exposing intermediate tool-call drafts or resets. Mobile search/Ask entry layout is a separate requested lane.

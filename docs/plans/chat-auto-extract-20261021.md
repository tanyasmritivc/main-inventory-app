# Auto Extract in chat — October 21, 2026

## Behavior

Auto Extract is first in the chat + menu. It opens Take photo / Choose photo and
starts FIND after selection. A normal image-only attachment also starts extraction;
a typed photo question remains in the composer until Send and keeps its intent.

Full FIND observations (crops, source frame, identity, quantities, catalog and
uncertainty evidence) become a durable, private conversation draft. Extraction
writes neither inventory nor Review. The draft appears before the model reply.
Chat can refine selection, fields and an exact existing inventory/Space through
world_refine_capture; missing structure uses the established reviewed structure
cards. The draft survives structure confirmation and conversation reopening.

The card edits/selects observations, chooses a writable destination, and requires
Save items. Uncertain observations use the existing durable Review queue; confirmed
observations use the existing capture-save service, including original-gallery
retention, item limits, stable IDs and receipt checks. Possible exact name/barcode/
part-number matches require explicit Save separately or opening the existing item.
Use chat's reviewed edit-item action to update an existing match instead of adding.

A JSONB compare-and-swap on the canonical message prevents stale edits. Beginning
save freezes selection, content and destination; partial/lost responses retry the
same IDs. Receipts distinguish inventory saves, Review and failures and expose
verified item/Space links. No purchases or new AI provider are introduced.

## Compatibility and privacy

The new supports_capture capability is opt-in. Older clients keep their existing
photo-question flow. New clients on an older backend still receive its ordinary
answer, so activate the backend before distributing the new mobile build.

Migration075 adds one service-only permission helper and one guarded branch in
findez_can_read_item_image. It preserves access to canonical actor-private draft
photos beyond the temporary 24-hour upload grant. The path must belong to the
author; organization membership is rechecked. Other users, including organization
owners, cannot read another author's draft. It adds no tables/columns, rewrites no
customer rows, and preserves existing permission branches. Direct client writes
to world conversation payloads remain prohibited by073.

## Validation and delivery

APIe47deb0 / PR154 passes all five CI gates.1255 Python tests plus10subtests,
749 full Flutter tests and32 final chat/config checks, clean analysis,26 native
iOS cases and17 preserved previews pass. Synthetic SQL includes privacy,
revocation, stale writes and migration replay.075 was rehearsed twice on an
isolated fresh restore with91 customer tables unchanged. A configured-model
probe refined selection/quantity while preserving uncertainty, without inventory
writes. Interrupted replies preserve the completed capture draft.

The user explicitly approved075. The guarded publisher activated075/APIe47deb0
at2026-10-21T23:24:51Z after a fresh private backup, preserving102 unrelated
Python files and other database functions. Health/database200 and anonymous
World/private-photo401 pass. No customer QA writes. Apple validated and acknowledged mobile104, source43a9a39 / PR155, delivery
90f1ae5e-6571-4476-8647-3bfe62f40fc6. Signed artifacts and17 previews are preserved
in Documents/FindEZ/AppStore/1.1.0-build104.32+32 device executables,24 privacy
manifests and signatures passed. Processing/tester availability was not polled. Physical-device camera and TestFlight acceptance
remain unverified; no public App Store submission.

All five CI gates pass on mobile43a9a39 (run39693439001) and API759f537.

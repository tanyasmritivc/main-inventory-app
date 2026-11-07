# Mobile Space and background continuity, build197

The preceding web item-info and printable-label release is already deployed
separately. This change preserves parent inventories when a Space is deleted.
Confirmed inventory mutations invalidate visible readers, including a second
refresh if a mutation arrives during a read. Workspace navigation refreshes
inventory counts when opened and after returning from an inventory.

Space capture reuses the main extraction photo/progress components. The selected
Space is read-only during review and is checked again before save. A deleted or
renamed initiating Space raises an error instead of silently recreating it.

iOS owns assistant POST exchanges through file-backed background URLSession
uploads. Chat and extraction share the existing event decoder and explicit Stop
behavior. Account-context guards remain in place. Temporary payloads are private,
excluded from backups, and removed after completion/cancellation. A new engine
cancels orphaned tasks rather than replaying them into another login.

Because background uploads buffer small responses, a foreground GET mirrors the
same authorized POST bytes. It never invokes another model call or write. The
middleware matches the exact bearer, random stream ID, path and query. Its memory
is bounded to 64 entries, 16 MiB total, 2 MiB per entry and ten minutes. Reader
failure, expiry or a different worker leaves the original upload intact. The
current configured server runs one worker. A future multi-worker deployment may
lose early updates when routed to another worker, but retains final delivery.
No response bodies or credentials are logged or persisted by the mirror.

Welcome uses a draggable bottom sheet and checks eligibility on the first safe
authenticated frame, without the former two-second idle delay. Existing receipt
and per-account suppression rules remain. The requested welcome rollout is to be
raised from 10 to 100 percent after release validation, preserving other campaigns.
The native Settings plan row uses the table's single rounded mask with no clipped
second border. No other Settings layout changes are included.

Validation before release: 1,329 Flutter tests passed (one existing skip), clean
analysis, 805 backend tests passed, and 14 native iOS announcement cases passed,
including swipe-down dismissal, both themes, large text and reduced motion.
A localhost HTTPS fixture demonstrated an early streamed update and complete,
nonduplicated response after simulator screen lock. A separate exchange completed
while another simulator app was foregrounded. Native Settings and Space capture
screenshots were reviewed. The live-backend candidate passed all five new mirror
tests without altering customer data.

Physical-device acceptance remains pending: start chat and photo capture, lock
the phone or switch apps for over a minute, return to the complete result, verify
Stop, force-quit, and ensure Space capture saves to its initiating Space. iOS
scheduling, connectivity and OS termination are not an unconditional completion
guarantee; the simulator is not a physical-device substitute. Production IPA and
TestFlight delivery are recorded separately after Apple acknowledgment.

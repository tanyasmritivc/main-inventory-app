# Mobile utility page polish - October 24

The user supplied Notifications, import inventory selection, chat context (Spaces, Items, Projects, Documents and notes), and Memory screenshots with heavy text, oversized inputs and inconsistent spacing.

Implemented in the mobile lane only: shared secondary-page presentation with explicit app typography, 12-point field corners, 14-point content surfaces and consistent 20-point page margins. Notification summaries have muted metadata and a compact options menu for Refresh, phone settings and test delivery. Mark all as read stays in the header. Import destinations have distinct separated rows. Chat pickers use one scrolling viewport, specific search prompts, clear empty states and selected counts. Memory groups personalization, response style, aliases and management; saved preference details are expandable. Refresh, retry, export and confirmed forget remain available.

Existing API calls, organization/account boundaries, selection limits, source identities, import workflow, notification delivery and preference persistence are preserved. Bottom navigation, native Attach menu, chat/extraction and brand assets are untouched.

Validation: six layout/interaction scenarios cover eight real page widgets in both themes at 1x, 2x and 3.2x text, including 320-point width, retained source selection after filtering and memory export. Sixteen rendered page previews use bundled fonts. Existing notification, context and memory regressions retain writes/errors/account guards and destructive confirmation. Full mobile analysis and coverage suite are release gates. Physical-device acceptance remains unverified.

Branch: fix/mobile-utility-pages-20261024, stacked on released build126. Candidate TestFlight 1.1.1 (127). Delivery status is recorded after Apple acknowledgment; no public App Store submission is requested.

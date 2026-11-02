# Chat layout correction — November 2, 2026

Long conversations expanded the page and pushed the composer below the viewport. The theme also placed a second bubble around each whole user message, while the cookie notice retained its white overlay.

The full-page transcript now scrolls within the available viewport; the composer stays in the flex layout below it. Contextual drawers retain their independent height. Existing reply-following now also applies to full-page chat, pauses when reading earlier messages, and resets when sending or opening a conversation. Only user-message content receives the bubble; labels and actions keep their existing controls outside it.

The cookie notice uses the interior theme and reserves its measured height, including when text wraps. Dismissal releases that space. Public notice styling and legal text/consent behavior are unchanged.

Validation: production build, TypeScript, full lint (warnings only), and all 15 tests in the theme, assistant and cookie-layout suites passed. The new tests cover notice resizing, cleanup and dismissal persistence. Safari checked the exact staged build with an existing review-account conversation in dark and light: transcript scrolling, compact user bubble, visible composer, theme menu and notice dismissal. Review-account System preference restored. No inventory writes or new chat requests were needed. Exact smaller viewport/mobile keyboard and streamed-response interaction were not separately browser-tested.

Published build `ctWIaHTNz5-IyOGQGAzqI` at https://findez.ai and verified its external build ID. All 12 public-page and seven auth checks passed; backend PID, public assets and environment/package/configuration hashes remained unchanged. Previous theme release retained for rollback. See `chat-layout-deployment.json`.

## Subsequent visual cleanup

User requested icon-only History, New conversation, Stop and Send controls, a flat composer without lighting, no visible transcript scrollbar, and restoration of the previous white cookie popup. Implemented with accessible button names and native hover labels; the transcript remains scrollable and keyboard-focusable. Cookie layout reservation remains, adjusted for the original popup spacing. Send/stop handlers and request behavior are unchanged.

Build `WuBumiAAkblC73uGYsn1p` deployed and externally verified. Safari dark/light checks confirmed icon navigation, flat composer and scrolling without a visible scrollbar. Existing review conversation used; no new messages or inventory writes. The stop icon was checked in source; live cancellation was not exercised again for this presentation-only change. All 15 focused tests, full lint (52 warnings, zero errors) and the production build pass. Deployment preservation checks pass; previous release retained. See `chat-cleanup-deployment.json`.

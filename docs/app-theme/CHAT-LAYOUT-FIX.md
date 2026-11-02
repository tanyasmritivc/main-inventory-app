# Chat layout correction — November 2, 2026

Long conversations expanded the page and pushed the composer below the viewport. The theme also placed a second bubble around each whole user message, while the cookie notice retained its white overlay.

The full-page transcript now scrolls within the available viewport; the composer stays in the flex layout below it. Contextual drawers retain their independent height. Existing reply-following now also applies to full-page chat, pauses when reading earlier messages, and resets when sending or opening a conversation. Only user-message content receives the bubble; labels and actions keep their existing controls outside it.

The cookie notice uses the interior theme and reserves its measured height, including when text wraps. Dismissal releases that space. Public notice styling and legal text/consent behavior are unchanged.

Validation: production build, TypeScript, full lint (warnings only), and all 15 tests in the theme, assistant and cookie-layout suites passed. The new tests cover notice resizing, cleanup and dismissal persistence. Safari checked the exact staged build with an existing review-account conversation in dark and light: transcript scrolling, compact user bubble, visible composer, theme menu and notice dismissal. Review-account System preference restored. No inventory writes or new chat requests were needed. Exact smaller viewport/mobile keyboard and streamed-response interaction were not separately browser-tested.

Published build `ctWIaHTNz5-IyOGQGAzqI` at https://findez.ai and verified its external build ID. All 12 public-page and seven auth checks passed; backend PID, public assets and environment/package/configuration hashes remained unchanged. Previous theme release retained for rollback. See `chat-layout-deployment.json`.

# Inventory contextual chat and immediate streaming

Main organization chat keeps its layout, routing and organization boundary. Received safe text now renders immediately with the existing 180 ms new-text fade; the client no longer buffers until persistence or inserts word delays. The server still validates mutation receipts before confirming changes.

Inventory work pages offer a monochrome translucent Ask FindEZ panel. It reuses AssistClient, history, attachments, action review and cancellation without passing worldId. The active inventory determines API requests; stale selections are rejected. The visible label is “Only in [inventory]”. On Space, document and project pages this remains inventory scope, not an unimplemented narrower Space boundary. Account/settings and main organization chat do not receive the launcher. Drafts and component lifecycle are isolated by account and inventory. Closing cancels pending work; scrolling up suspends automatic following.

Validation: 648 web tests across 90 suites, TypeScript, changed-file lint (zero errors; three existing warnings), 23 existing backend boundary/journey tests. Browser-rendered synthetic light/dark desktop and 390 px previews checked panel bounds and readable content. Synthetic screenshots are layout evidence, not production-account acceptance. A stale public-navigation test was updated for the already-removed grey label; public runtime content is unchanged.

Publishing and TestFlight receipts are recorded separately. No schema migration. Main branch remains unchanged.

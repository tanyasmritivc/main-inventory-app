# Web chat cancellation and navigation

Stop cancels the stream reader as well as fetch, ignores late callbacks, and
uses a separate button identity with cancelled click defaults so it cannot turn
into a submit action. The draft remains available for an intentional retry.
This does not roll back operations already confirmed on the server.

World/session boundaries use a quiet themed transition instead of bare text in
the page corner. The organization shell keeps its normal interior skeleton.
Tools uses one inventory selector and ten compact icon cards, preserving existing
routes, archive access and authorization. Selection falls back safely if removed.

The header bell opens an immediate Radix menu containing up to five notifications
and View all notifications. No slide or entrance animation. Loading, empty and
retry states are separate; switching accounts unmounts the menu and discards late
results. Opening the preview does not mark notifications read or send writes.
The full Notifications page remains available, with stable entry anchors.

Validation: 628 tests / 87 suites passed; TypeScript and ESLint checks, production
build, exact-source CI and Safari release checks are recorded in the delivery
receipt. New tests cover Stop without resubmission, stalled-reader abort, queued
completion cancellation, inventory switching, notification retries and account
isolation. Backend group/tool parsing is a separate release. No mobile or schema
changes. Existing self-hosted deployment and pricing are unchanged.

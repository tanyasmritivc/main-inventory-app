# Startup onboarding save recovery

A retained real list/describe trial can block an existing signed-in session on launch. These trials supplied an empty category; the existing bulk-capture service requires name, category and location. The mobile test adapter had accepted the invalid payload. Recent API status codes were 200, which does not establish that the per-item receipts succeeded.

Mobile-only repair: new local templates use Other; the save boundary also repairs legacy empty categories without changing retained draft IDs, quantities, names or existing nonempty categories. Retry uses existing idempotent receipts. Recovery distinguishes a local draft-read failure from an unconfirmed save, maps transport errors through the shared safe formatter, allows continuing to the app while retaining the draft for the next launch, and scrolls at large text sizes. It never discards a failed draft or silently calls it saved.

Regression coverage uses the real required-field rule, retained empty-category drafts, lost responses, partial receipts, another-account rejection, continue without resubmission, reopen after recovery, and unreadable local drafts at large text in dark mode. Full suite, native verification and build148 delivery are in progress. No server/schema changes or public submission.

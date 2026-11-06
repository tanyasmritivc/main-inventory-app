# Progress and choice sheets186

Scan progress uses completed photo preparation/detection/checked-crop/review stages, rather than elapsed-time percentages. Alternate activity wording never advances the bar. Three decorative squares shimmer diagonally and stop under Reduce Motion or an inactive ticker. Existing photo overlays and confidence ordering are preserved.

ChatCaptureCard waits for the streamed summary to complete; normal text renders on every received delta with the existing180ms glyph fade. New live responses may offer an optional compact question sheet from validated answer_context.question. Two to four options, a custom reply, dismissal/reopen, and turn-generation guards preserve control. A selection sends exactly one ordinary chat reply; normal server permissions and confirmation still apply. History loading never auto-opens a question.

Tests: malformed question rejection; narrow320px layout at2x text in both themes; monotonic progress with no elapsed-time advances; reduced motion; capture-before-delta ordering; text visible before done; one selected follow-up; existing streaming/fade and complete regression suite. Native iPhone16e checks passed in both themes with six screenshots, including crop overlays, shimmer, reduced motion and four-choice sheets. Current delivery pending CI, release signing and Apple upload.

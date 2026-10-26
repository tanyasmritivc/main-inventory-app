# Response feedback and chat controls

Implementation only. Production migration, deployment and TestFlight upload are **not authorized for this task**. Three feature lanes: `feat/response-feedback-api`, `feat/chat-message-controls`, `feat/mobile-message-controls`.

## Architecture and behavior

FindEZ uses FastAPI world-scoped SSE chat with actor-private Supabase conversations/messages, durable action receipts, Flutter Ask and Next.js Assist. Existing personalization (081) distinguishes confirmed preferences from opted-in behavioral signals. Existing world creation transactions already persist confirmation receipts.

Assistant replies receive compact copy, rating, regeneration and timestamp controls. Prompts receive copy, retry, edit and timestamp controls. Negative reasons/comments are optional and hidden initially. The existing screens, composer, navigation, typography and cards remain. Creation confirmations say “Created and saved” only after the existing successful receipt. Enter sends on web; Shift+Enter and IME composition retain normal editing. Dispatch immediately clears the composer; failures restore the draft.

Clients retain provisional text until a verified completion, then present the canonical response with the existing presentation animation. JSON completion is accepted once; `[DONE]` is only a transport marker. Cancellation still closes the underlying stream. This prevents provisional/duplicate output from flashing and being replaced by Retry; it does not guarantee provider availability.

World-chat regeneration is read-only on the server, resolves the original authenticated message/prompt and uses fresh read tools. It cannot repeat inventory writes. Regenerated history stays in the original position. Original action IDs remain stored once; regenerated messages reference them, and current cards are hydrated for display. Existing inventory-specific legacy chat obtains feedback IDs, but does not expose successful-answer regeneration until it has an equivalent safe retry contract.

## Persistence and security

Migration **082_response_feedback.sql**, after 081, adds one table and service-only functions. Unique `(user_id,message_id)` provides idempotency. Identical retries return the existing revision; changed ratings require the expected revision. The backend validates the authenticated owner, message role, world membership, rating, reason and optional comment. User/system errors, direct receipt placeholders and empty replies cannot be rated. Client-supplied identities, review labels or execution claims are rejected.

RLS is enabled; anon/authenticated roles have no direct table or RPC access. Only authenticated backend routes using the service role may read/write. Foreign keys cascade conversation/message/account deletion. Private responses use `Cache-Control: private, no-store`. PUT is limited to 30/minute; deletes to 10/minute. Eight allowlisted reason codes are validated in code; storage allows future additive codes without a migration. Comments are capped at 1,000 characters.

GET `/response-feedback?conversation_id=UUID` restores ratings in one batch. PUT `/response-feedback/{message_id}` accepts `{rating:1|-1,reason?,comment?,expected_revision}`. DELETE that path removes one rating; DELETE `/response-feedback` removes all of the caller's ratings. No UI selected state appears until the exact-message server receipt is confirmed. Failed reads never block chat.

## Learning and diagnostics

A rating is satisfaction evidence, never proof of factual correctness. It cannot change inventory, create aliases, save a response-format preference or train weights. Explicit preferences and corrections continue through the existing confirmed personalization workflow.

Opted-in learning uses at most 100 ratings from the last 60 days, scoped to the current personalization generation. A negative reason needs at least three observations and at least half the recent ratings before requesting one of a fixed set of verification checks. Positive ratings contribute to the denominator. At most two checks enter the prompt; raw comments/reasons are never treated as instructions. A single rating and verbosity feedback cannot create a permanent preference. Reset invalidates earlier generations; opt-out disables learning. Optional I/O reuses the existing 500ms-timeout personalization client and fails closed.

Feedback stores minimal server-derived diagnostics plus message/conversation references: pending versus confirmed action receipts, configured model and response version, validation/retrieval observation and bounded operation/result categories. Tool arguments, full results, transcripts and private item contents are not copied. Unsupported facts (clarification, factual correctness, reporting accuracy) stay `not_observed`/`unreviewed`. Actual inventory is authoritative. A rejected operation, missing receipt and user dissatisfaction remain different signals. Partial/mixed receipts are not labeled full success.

## Offline evaluation and operator workflow

No online training, automatic prompt updates or automatic ranking-weight changes. Use a private, authorized export with a consistent time window and one current rating per message:

- Denominator: eligible assistant messages in that window, excluding empty/direct/attachment/error receipts and superseded responses according to the chosen coverage definition. Report whether superseded responses are included; use the same definition across releases.
- Rating export fields: rating, reason, diagnostics, review_status, reviewed_labels. Exclude identities, comments and message contents by default.
- Review relevant authorized receipts privately before assigning correctness labels. Allowed dimensions: intent_accuracy, retrieval_accuracy, operation_success, completeness, groundedness, personalization_quality, response_clarity. Values: correct/incorrect. Mark ambiguous examples excluded. There is no public review-label write endpoint.
- Store reviewed labels through a restricted operator transaction; never infer them from thumbs alone. Fix confirmed recurring defects with synthetic regression cases before prompt/model changes.

From the repo root:

```sh
PYTHONPATH=backend python backend/tools/response_feedback_report.py --input private-export.json --output private-report.json
PYTHONPATH=backend python backend/tools/response_feedback_report.py --baseline reviewed-baseline.json --candidate candidate-results.json --output comparison.json
```

Comparison inputs map the **same stable synthetic/adjudicated case IDs** to measured dimension labels. Changed case sets fail; a correct→incorrect regression exits 2. Run both versions on the fixed cases using the existing provider/test harness before supplying measured results. The command does not itself call models or manufacture labels. Reports include rating coverage/rates, reasons, operation outcomes and model/response-version groups (minimum five ratings per group). Unrated examples are not negative; unreviewed/unsupported labels are excluded. Exports are selection-biased, not estimates of overall model accuracy. Output files use mode 0600 and omit comments/transcripts/identities. Do not publish raw exports.

## Deployment sequence — pending explicit authorization

1. Rehearse 082 on a staging copy with the existing 081 schema, take a backup, and apply 082 before backend publication. The isolated fixture has synthetic users only; it does not migrate production.
2. Deploy API first, then web and mobile. Existing clients tolerate additive completion metadata. New rating writes require 082.
3. The existing personalization worker now invokes `findez_response_feedback_cleanup`: clear comments after 30 days and delete ratings after 180 days. No new scheduler/provider/credential is introduced. Monitor worker failures. Reset removes learning eligibility immediately; full feedback deletion uses DELETE or account deletion.
4. Verify two isolated staging users: rate/change/reload, denied foreign message, confirmation and safe regeneration, feedback network failure, both themes, foreground/restart. Do not rate customer messages as QA.
5. Roll back dependent runtime first if necessary. Leave the additive table in place to preserve feedback; do not drop production data as rollback.

## Verification and limits

Automated coverage includes feedback validation/ownership, revisions and lost-response retry, deletion/retention/RLS, opt-out/generation boundaries, sparse evidence, diagnostic truth distinctions, offline filtering/regression checks, Enter/IME/composer behavior, exact-message controls, persisted selection, stream completion/cancellation and read-only retry. SQL runs on an empty disposable PostgreSQL database and replays migration 082. The CI SQL job includes this fixture.

No real production feedback has been written and no production model evaluation or training has been performed. Live authenticated persistence across released app restarts remains a staging/release check after migration authorization. Legacy replies may have unknown model version or incomplete operation diagnostics. No automatic inspection/correction of an alleged wrong quantity is performed; reviewers correlate existing receipts and tests.

### Verified locally (2026-10-25)

- Backend: 1,526 tests passed, plus 10 subtests; existing dependency/FastAPI deprecation warnings remain.
- Disposable PostgreSQL: migration replay, idempotency, revision conflicts, ownership, RLS/ACLs, opt-out, retention and deletion assertions passed.
- Web: 584 tests passed; TypeScript passed; ESLint has 0 errors and the same 52 existing warnings. Production webpack build passed with public fixture configuration. Turbopack cannot resolve this worktree's external node_modules symlink; webpack is the repository's existing supported check.
- Mobile: Flutter analysis clean; focused chat/feedback/cancellation suite 62 passed, inventory isolation suite 16 passed. Five feedback tests also passed on iPhone 17 Pro simulator (iOS 26.5) using a synthetic API. Full-suite result is recorded in the mobile lane.
- No production migration, runtime deployment, TestFlight upload, real user feedback or inventory mutation was performed.

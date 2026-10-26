# Proactive missing destinations — October 24, 2026

The first strawberries/Fridge message previously produced an unsaved draft and a
question listing unrelated inventories. Destination-creation guidance only applied
to a draft present at the start of the turn; the tool list also stayed frozen after
creating a draft, leaving refinement unavailable until another message.

The API now provides first-turn creation guidance, refreshes draft capabilities
within the tool loop, and rejects duplicate direct additions after drafting even
inside one tool batch. A unique existing Space is reused; a missing Space or
inventory gets a reviewed creation proposal. Explicit parents are retained,
Personal has a simple proposed default, and ambiguous organizational parents get
one short question. Existing capture drafts keep counts/photos/Review evidence,
with destination-only creation and explicit stock saving afterward. A complete
new task can include its items in the creation card. No schema or client changes.

Runtime `a5184f6a3aa329879c2b2775fea51271b843a853`; PR #212 (stacked on #209).
All five CI checks passed in run 40167398942. Local validation: 1,483 tests plus
10 subtests, 452 existing dependency/deprecation warnings. The 83 focused tests
include immediate creation/selection after drafting and same-batch duplicate
addition rejection. No warnings were introduced.

Six real-model synthetic scenarios passed: missing Fridge; existing Fridge;
explicit new Kitchen inventory; missing Fridge under existing Kitchen; ambiguous
organizational parents; and an existing draft needing Fridge. Model prose is not
deterministic; ambiguity still requires a choice. A fixture initially rejected the
valid existing-destination add tool; that test harness was corrected before the
successful existing-destination probe. No production code was relaxed for it.

Published through a three-file hash-checked overlay, preserving 115 unrelated live
source files. API/database health and unauthenticated denial passed, GLM remains
active, and no schema change was made. Rollback and server receipts:
`/home/ubuntu/findez-proactive-destination-20261024`.

Authenticated HTTPS QA using two disposable accounts verified the actual first
message returns a real creation card without a structure or stock write; another
account cannot confirm it; explicit confirmation creates Fridge and saves six
strawberries; replay adds nothing; and the next conversation reuses Fridge without
creating duplicate structure or implicitly changing stock. Both accounts and their
inventories were deleted after QA. No customer records were used. Existing-draft
destination binding and evidence preservation are covered by automated tests and
the real-model creation-only probe; this release did not perform a new native UI
run because no client code changed. No new TestFlight build is required.

Local logs/scripts/receipts: `Documents/FindEZ/Audits/proactive-destination-20261024`.

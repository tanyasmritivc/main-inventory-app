# Model-written Chat

The reported question, "how many wheels do I need for the roadrunner", was
intercepted by a deterministic question interpreter. It searched for "wheel need
roadrunner" and returned a fixed no-match answer before the model ran. This also
affected other inventory, project, preference and photo questions.

Every successful Chat answer now comes from the configured agent model. One
shared sync/event loop supplies current authorized context, conversation history,
explicit preferences and validated tools on every turn. The model decides whether
to retrieve records, explain or clarify and chooses semantic tool arguments.
No keyword router disables tools for planning, and no project/preference/read
shortcut or action formatter replaces model prose. Fixed reply instructions were
removed from the system prompt. Model settings/provider are unchanged.

The retired inventory_questions.py is deleted. Its useful bounded database reads
are retained as inventory_query, a data-only tool accepting explicit terms and
filters. It returns rows, completeness, record counts, known units and unknown
quantities. project_kit_readiness exposes existing authorized requirements and
reservation-aware stock. Evidence cards remain derived from actual reads, never
model prose. Private location aliases are rechecked through authorized Space IDs.

Photo Chat keeps FIND identification and validated identifier/name matching as
structured evidence, then always asks the model to answer the question. No photo
template or optional-explanation fallback remains. Unknown/uncertain observations
remain uncertain; failed generation cleans up only the new preview. The legacy
file-upload Chat also uses the model for all successful image/document replies.

Empty replies, exhausted tool budgets and provider failures raise an error.
HTTP/SSE returns an error instead of a thinking placeholder, canned inventory
answer or saved assistant success. There is no alternate provider or model.
Authorization, schema validation, literal-edit checks and conditional writes
remain server-owned. A false model claim of a requested action without a current
receipt is rejected, never rewritten into a scripted assistant answer. Inventory
and Space deletion, quantities and other unconfirmed operations remain in the
existing reviewed editors. No schema, GPU/FIND configuration or client UI change.

Validation: 990 backend tests and 10 subtests pass. All 127 previous question
fixtures are tested in both sync and streaming paths for actual model invocation
using hermetic model doubles; these are routing tests, not model-quality scores.
Structured retrieval, unknown/partial counts, cross-inventory isolation, current
aliases, stale edits, failed/forged tools, action claims, photo cleanup, history
persistence and empty/error HTTP/SSE contracts are covered. Separately, seven
requests use the actual configured model with synthetic facts, no customer writes:
Roadrunner requirements/stock, broad robotics inventory, recorded location,
deletion refusal, preferences, uncertain photo and an empty-inventory Roadrunner
clarification. The saved fixture needs four
wheels and has two; the model retrieves that project and explains the shortage.
One further actual-model case covers the later screenshot's request to attach a
photo to existing Garage entries. The model receives current edit permissions
and truthful attachment capabilities, addresses that action without a photo/
stock report, and does not infer an empty Space from photo-name matches. Bulk
photo attachment from Chat is not implemented; the model explains the existing
per-item Add photo/Add another gallery flow rather than directing existing-record
attachments to Capture. This is eight evaluated model cases in total, not a
guarantee of all model behavior. Private evidence is in
/home/ubuntu/findez-model-chat-release-20261018.

The main 0d2f38f backend rollout is live after all five CI gates passed. Health,
database, invalid Chat session and anonymous private-photo denial pass. All 86
unrelated Python files are preserved. The first restart attempt lacked sudo,
restored every reviewed source file and left the existing service healthy; the
correct privileged restart then succeeded. The photo-intent follow-up is checked
and published separately from this baseline.

Publish only the reviewed backend files, remove the retired script after checking
its old hash and preserve unrelated dirty VM source. No migration or authentication
change. Verify health/database, invalid-session Chat denial and anonymous private
photo denial after restart. Customer Dashboard and existing stored conversations
are preserved. Reopen or start a Chat turn to receive the model-written behavior;
the existing mobile/web protocol is unchanged.

The standing release instruction also produces signed production beta86 from
the unchanged beta85 native runtime. Reuse the completed 623 mobile tests and
clean analysis; do not repeat them for a build-number-only change. Verify signing,
device binaries, configuration and Apple validation; stop at upload acknowledgment.
Public App Store submission and physical-device acceptance remain separate.

## Final delivery

Final photo-intent runtime 71c0ca4 is published after all five CI gates passed
(39152846348). The two-file guarded overlay preserves 92 unrelated Python files.
Health/database return 200 and invalid Chat session/anonymous photo return 401.
Backups and receipt are private under the -photo-intent release directory.
Apple acknowledged production beta86, delivery a0d40e13-003f-4885-a83b-6c7539f9681c.
31 archive/export device executables, strict signatures, production configuration
and Apple validation pass. Native runtime is unchanged from beta85, so completed
623 tests/analysis are reused. No processing/tester polling or repeated checks.
Availability and physical acceptance remain unverified; public App Store held.

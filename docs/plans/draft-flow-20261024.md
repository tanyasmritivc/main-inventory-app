# Clear draft flow and photo quantities — October 24, 2026

The user reported repeated hierarchy questions, duplicate destination chips, misleading Qty 1 placeholders, and transcript overlap. A follow-up showed photo piles represented as one unit and identical chocolate bars split into rows.

Implemented: one destination choice separated from explicit saving; unknown quantities displayed as missing, with a compact count/omit action on mobile and blank fields on web; no irrelevant draft suggestions; transcript constrained between header and composer. Assistant asks one short relevant question and reuses a named existing Space. A reviewed creation-only plan can bind its confirmed new Space to the existing draft, without saving stock or overwriting a later destination choice.

Photo extraction carries quantity basis/confidence in JSON evidence. Piles cannot be treated as one unit merely because they occupy one detected box. Legacy placeholder reasons remain recognized. Unknown counts require confirmation in chat and photo review. Separate counts merge only for disjoint, confidently counted objects with matching identity and exact normalized visible markings; variant markings, unknown counts, overlap and widely spaced crops remain separate. The grouped crop contains every grouped object. Internal numeric compatibility placeholders remain in the API; clients never display them as known counts. No database schema change.

Preserved: crop/evidence provenance, Review routing, explicit inventory saves, permissions/CAS/idempotence, GLM extraction provider, native bottom navigation, reversed shine and current brand assets.

Validation: API full regression plus focused quantity/creation tests; web full Jest and types/lint; mobile full Flutter/analysis and synthetic iOS draft audit. Runtime delivery and exact final check counts are recorded below after completion. Physical-device acceptance remains unverified.

Lane: API. Branch: `fix/draft-flow-api-20261024`. Runtime delivery complete; details below.

## Delivery evidence

Runtime `737f73139b13063ed374f70f2ce4cf4f5ab1212f`; PR #200; all five exact-runtime CI checks passed in run 40147459385. Published to the self-hosted API with rollback at /home/ubuntu/findez-draft-flow-20261024-v3. API/database health and anonymous denial passed, GLM remains active, and 111 unrelated source files were preserved. No schema migration.

Validation: 1,473 API tests plus 10 subtests passed locally; existing 452 dependency/deprecation warnings remain. Tests cover visible count versus region count, unknown/legacy quantity evidence, same-marking grouping and variant/overlap exclusion, union crops and warning preservation, explicit correction, revision/permission checks, creation binding and phantom-card repair. Full CI includes PostgreSQL permissions and connector checks.

A real-model three-turn fixture used synthetic items and blocked inventory writes: 3 pears, 2 apples and 1 jar were retained; peas stayed unknown until the user confirmed one bag. The named Pantry intent survived the clarification. Once counts were resolved, an actual creation-only proposal was bound to the existing draft. An initial phantom proposal discovered by this probe was fixed with a regression test; the corrected probe returned a real world_create_task card. Receipt binding and stock saving are covered by automated fixtures; no customer inventory was edited for QA. Private probe receipts are in /home/ubuntu/findez-draft-flow-20261024-v2/.

Web counterpart #198 is live from 45af6f2 at /home/ubuntu/findez-web-releases/draft-flow-20261024/frontend (build byC8d2bvI6dGs1MUmdh6L). Its 558 local tests, types/lint, production build and eight staged/live route checks passed; all five runtime CI checks passed in 40146412757.

Mobile counterpart #199 shipped 1.1.1 (126) from 8e40596. Apple acknowledged delivery 373106d3-45e4-4cf0-bb0a-f1dfb14106ac after validation, signing/device-platform/privacy checks. CI passed 850 mobile tests (one intentional skip), with all five runtime checks in 40146414106. Eleven native synthetic draft checks passed. Processing/tester availability was not polled; physical-device acceptance is unverified. Archive and receipts are preserved at Documents/FindEZ/AppStore/1.1.1-build126.

Limits: dense scenes still need count review; model confidence is not calibrated, and the existing eight-candidate cap remains. No silent re-extraction or rewriting of prior photos. Grouping is deliberately conservative: identical category/name alone cannot merge distinct components.

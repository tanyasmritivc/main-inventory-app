# Clear draft flow and photo quantities — October 24, 2026

The user reported repeated hierarchy questions, duplicate destination chips, misleading Qty 1 placeholders, and transcript overlap. A follow-up showed photo piles represented as one unit and identical chocolate bars split into rows.

Implemented: one destination choice separated from explicit saving; unknown quantities displayed as missing, with a compact count/omit action on mobile and blank fields on web; no irrelevant draft suggestions; transcript constrained between header and composer. Assistant asks one short relevant question and reuses a named existing Space. A reviewed creation-only plan can bind its confirmed new Space to the existing draft, without saving stock or overwriting a later destination choice.

Photo extraction carries quantity basis/confidence in JSON evidence. Piles cannot be treated as one unit merely because they occupy one detected box. Legacy placeholder reasons remain recognized. Unknown counts require confirmation in chat and photo review. Separate counts merge only for disjoint, confidently counted objects with matching identity and exact normalized visible markings; variant markings, unknown counts, overlap and widely spaced crops remain separate. The grouped crop contains every grouped object. Internal numeric compatibility placeholders remain in the API; clients never display them as known counts. No database schema change.

Preserved: crop/evidence provenance, Review routing, explicit inventory saves, permissions/CAS/idempotence, GLM extraction provider, native bottom navigation, reversed shine and current brand assets.

Validation: API full regression plus focused quantity/creation tests; web full Jest and types/lint; mobile full Flutter/analysis and synthetic iOS draft audit. Runtime delivery and exact final check counts are recorded below after completion. Physical-device acceptance remains unverified.

Lane: web. Branch: `fix/draft-flow-web-20261024`. Runtime delivery complete; details below.

## Delivery evidence

Runtime `45af6f290acc42db67a1a899e96cc10398f364e0`; PR #198; all five exact-runtime CI checks passed in run 40146412757. Self-hosted website published at /home/ubuntu/findez-web-releases/draft-flow-20261024/frontend. Build ID byC8d2bvI6dGs1MUmdh6L. Eight staged and live routes returned 200; the API process and previous web release were preserved.

Validation: 558 local web tests and types/changed-file lint passed; self-hosted production build passed. Mobile analysis passed and CI completed 850 tests with one intentional skip. The local full mobile rerun stalled after disk exhaustion, so its partial output is not a pass. Eleven native synthetic draft audit tests passed earlier in the turn; the added missing-count widget behavior also passed. No physical device or customer inventory was used for acceptance. Existing dependency/deprecation and launch-placeholder warnings remain.

Final API conversation fixes are delivered separately by PR #200: a live-model fixture exposed a phantom destination proposal; the backend now requires a real structure card even when an inventory draft already exists. The successful three-turn fixture preserved counts 3/2/1, kept peas unknown until the user confirmed one bag, and proposed a Pantry destination without stock writes.

Limits: dense photo counts still require user review; model confidence is not calibrated. The existing eight-candidate cap remains. Existing photos are not silently re-extracted or rewritten. Source grouping is conservative and only joins disjoint objects with matching identity and visible markings.

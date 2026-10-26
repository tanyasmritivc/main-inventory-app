# Clear draft flow and photo quantities — October 24, 2026

The user reported repeated hierarchy questions, duplicate destination chips, misleading Qty 1 placeholders, and transcript overlap. A follow-up showed photo piles represented as one unit and identical chocolate bars split into rows.

Implemented: one destination choice separated from explicit saving; unknown quantities displayed as missing, with a compact count/omit action on mobile and blank fields on web; no irrelevant draft suggestions; transcript constrained between header and composer. Assistant asks one short relevant question and reuses a named existing Space. A reviewed creation-only plan can bind its confirmed new Space to the existing draft, without saving stock or overwriting a later destination choice.

Photo extraction carries quantity basis/confidence in JSON evidence. Piles cannot be treated as one unit merely because they occupy one detected box. Legacy placeholder reasons remain recognized. Unknown counts require confirmation in chat and photo review. Separate counts merge only for disjoint, confidently counted objects with matching identity and exact normalized visible markings; variant markings, unknown counts, overlap and widely spaced crops remain separate. The grouped crop contains every grouped object. Internal numeric compatibility placeholders remain in the API; clients never display them as known counts. No database schema change.

Preserved: crop/evidence provenance, Review routing, explicit inventory saves, permissions/CAS/idempotence, GLM extraction provider, native bottom navigation, reversed shine and current brand assets.

Validation: API full regression plus focused quantity/creation tests; web full Jest and types/lint; mobile full Flutter/analysis and synthetic iOS draft audit. Runtime delivery and exact final check counts are recorded below after completion. Physical-device acceptance remains unverified.

Lane: mobile. Branch: `fix/draft-flow-mobile-20261024`. Runtime delivery complete; details below.

## Delivery evidence

Runtime `8e40596142be213f51730874186c3eb87e06fed4`; PR #199; all five exact-runtime CI checks passed in run 40146414106. Apple accepted FindEZ 1.1.1 (126), delivery 373106d3-45e4-4cf0-bb0a-f1dfb14106ac. Processing and tester availability were not polled. Physical-device acceptance is unverified. IPA SHA-256 45c9284b80a7db787f6cf63d2f0b2301e18537142e5c705c4c2b70a5bac57619. Preserved archive, IPA and receipts: Documents/FindEZ/AppStore/1.1.1-build126. All 32 archive/export native executables, strict signatures, 24 privacy manifests and production configuration passed. Apple validation passed. A cached simulator framework was rejected locally; the clean rebuilt package passed and only that package was uploaded.

Validation: 558 local web tests and types/changed-file lint passed; self-hosted production build passed. Mobile analysis passed and CI completed 850 tests with one intentional skip. The local full mobile rerun stalled after disk exhaustion, so its partial output is not a pass. Eleven native synthetic draft audit tests passed earlier in the turn; the added missing-count widget behavior also passed. No physical device or customer inventory was used for acceptance. Existing dependency/deprecation and launch-placeholder warnings remain.

Final API conversation fixes are delivered separately by PR #200: a live-model fixture exposed a phantom destination proposal; the backend now requires a real structure card even when an inventory draft already exists. The successful three-turn fixture preserved counts 3/2/1, kept peas unknown until the user confirmed one bag, and proposed a Pantry destination without stock writes.

Limits: dense photo counts still require user review; model confidence is not calibrated. The existing eight-candidate cap remains. Existing photos are not silently re-extracted or rewritten. Source grouping is conservative and only joins disjoint objects with matching identity and visible markings.

# Clear draft flow and photo quantities — October 24, 2026

The user reported repeated hierarchy questions, duplicate destination chips, misleading Qty 1 placeholders, and transcript overlap. A follow-up showed photo piles represented as one unit and identical chocolate bars split into rows.

Implemented: one destination choice separated from explicit saving; unknown quantities displayed as missing, with a compact count/omit action on mobile and blank fields on web; no irrelevant draft suggestions; transcript constrained between header and composer. Assistant asks one short relevant question and reuses a named existing Space. A reviewed creation-only plan can bind its confirmed new Space to the existing draft, without saving stock or overwriting a later destination choice.

Photo extraction carries quantity basis/confidence in JSON evidence. Piles cannot be treated as one unit merely because they occupy one detected box. Legacy placeholder reasons remain recognized. Unknown counts require confirmation in chat and photo review. Separate counts merge only for disjoint, confidently counted objects with matching identity and exact normalized visible markings; variant markings, unknown counts, overlap and widely spaced crops remain separate. The grouped crop contains every grouped object. Internal numeric compatibility placeholders remain in the API; clients never display them as known counts. No database schema change.

Preserved: crop/evidence provenance, Review routing, explicit inventory saves, permissions/CAS/idempotence, GLM extraction provider, native bottom navigation, reversed shine and current brand assets.

Validation: API full regression plus focused quantity/creation tests; web full Jest and types/lint; mobile full Flutter/analysis and synthetic iOS draft audit. Runtime delivery and exact final check counts are recorded below after completion. Physical-device acceptance remains unverified.

Lane: mobile. Branch: `fix/draft-flow-mobile-20261024`. Release pending at implementation commit.

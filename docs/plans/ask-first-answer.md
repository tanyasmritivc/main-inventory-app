# First-answer inventory context

The deterministic read path treated a purpose such as "for FTC robotics" as
mandatory words in every item record. A broad inventory question therefore
returned a generic no-match sentence before the normal conversational path ran.
The same service handles mobile and web, including SSE.

Purpose-based browsing now keeps item and location filters separate from the
purpose. Broad replies group current records by saved category with varied saved
examples, instead of listing twenty nearly identical fasteners. Specific item
replies use Markdown bullets so both clients preserve readable line breaks.
It returns current authorized saved records and explicitly says that
suitability for the purpose has not been verified. It does not infer compatibility,
game requirements or purchases. Exact identifier searches remain strict.

An empty selected inventory is distinguished from an unsuccessful filtered search
with a bounded scoped existence check. The first reply explains the current
inventory and offers switching inventories, the saved name/location or Capture.
A failed read stays unavailable; a truncated read stays partial. No cross-inventory
search, provider change, schema change, customer-data write or mobile/web UI change.

Validation: all 831 root Python tests pass, plus 10 subtests. Fourteen new cases
cover the reported first question in sync/SSE, an empty inventory with inaccessible
records elsewhere, requested items/locations, generic purpose wording, exact IDs,
bounded partial results, failed existence reads, compact grouped replies and a
real HTTP SSE viewer request.
The five initial reproductions failed before the patch. Synthetic fixture runtime
was 7.30 seconds for the full suite; this is not production provider/network latency.
Existing authorization, planning and unsafe-write regressions remain green.

Runtime file: backend/app/services/inventory_questions.py.
Regression file: backend/tests/test_physical_memory_questions.py.
The first one-file overlay passed live health/db/anonymous-access checks and
preserved all 91 unrelated Python files. Live Safari verified first-question
retrieval in a populated authorized inventory. Final grouped-reply polish is
pending activation. The previously reviewed migration 053
is not part of this release and remains separately awaiting production approval.

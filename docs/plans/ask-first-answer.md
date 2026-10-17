# First-answer inventory context

The deterministic read path treated a purpose such as "for FTC robotics" as
mandatory words in every item record. A broad inventory question therefore
returned a generic no-match sentence before the normal conversational path ran.
The same service handles mobile and web, including SSE.

Purpose-based browsing now keeps item and location filters separate from the
purpose. It returns current authorized saved records and explicitly says that
suitability for the purpose has not been verified. It does not infer compatibility,
game requirements or purchases. Exact identifier searches remain strict.

An empty selected inventory is distinguished from an unsuccessful filtered search
with a bounded scoped existence check. The first reply explains the current
inventory and offers switching inventories, the saved name/location or Capture.
A failed read stays unavailable; a truncated read stays partial. No cross-inventory
search, provider change, schema change, customer-data write or mobile/web UI change.

Validation: all 830 root Python tests pass, plus 10 subtests. Thirteen new cases
cover the reported first question in sync/SSE, an empty inventory with inaccessible
records elsewhere, requested items/locations, generic purpose wording, exact IDs,
bounded partial results, failed existence reads and a real HTTP SSE viewer request.
The five initial reproductions failed before the patch. Synthetic fixture runtime
was 7.84 seconds for the full suite; this is not production provider/network latency.
Existing authorization, planning and unsafe-write regressions remain green.

Runtime file: backend/app/services/inventory_questions.py.
Regression file: backend/tests/test_physical_memory_questions.py.
Self-hosted one-file deployment is pending. The previously reviewed migration 053
is not part of this release and remains separately awaiting production approval.

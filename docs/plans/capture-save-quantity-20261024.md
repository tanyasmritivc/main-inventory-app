# Capture saving and counted units

The Save to Space action accepts identified, counted items into inventory and saves
unknown identities or uncounted items into the chosen Space's Review section.
Missing quantity no longer disables this action. Blank counts remain unknown;
the internal Review placeholder is never added to stock. The selected Space
initializes each destination. Its Review entry opens the existing editable record.
This follows the user's clarification that unknown records belong in the Space's
Review section, rather than a review tag on ordinary inventory.

Quantity is a text field with an editable counted unit, before collapsed model
evidence. Supported estimates remain editable. The action says Save to Space,
not Keep N in Review, so a number of draft records is not presented as a unit count.
Existing pending records resolve through the Review endpoint, with no duplicate
bulk insertion. Per-row failures and stable capture request IDs remain intact.
Unaccepted chat drafts and other Review entry points retain their behavior.

The separate backend change adds optional quantity_unit/quantity_note evidence.
It preserves supported visible counts at 0.5-0.9 model confidence as estimates,
rather than replacing them with 1. Stronger counts retain their visible basis.
Package quantities are distinguished from individual contents. The prompt counts
remaining visible tablets/filled pockets, excludes empty pockets, and does not
use dosage or printed original capacity as remaining stock. Hidden contents and
uncountable piles stay unknown. These scores are model estimates, not calibration.

## Verification

Mobile runtime: c4bc448ad2bd0832702b037d6bd1c55f1a1067c3, PR208.
Clean Flutter analysis, 879 host tests with one optional skip, and all five CI jobs
passed (40161030215). Tests cover unknown saves, editable quantity/unit, invalid
counts, cancellation, legacy-review receipts, and inventory/Space filtering.
Native iPhone 17 Pro/iOS 26.5 synthetic QA verified known direct acceptance,
blank-count Save, appearance in Pantry Review and tapping through to the editor.
No customer stock was changed. Physical-device/network acceptance is unverified.

Backend runtime: 962dddc3175202a30933166c57178c13fef0e64f, PR209.
All 1480 Python tests plus ten subtests and five CI jobs passed (40160782561).
Guarded two-file publication is live; health/database and anonymous denial passed,
with 116 unrelated source files preserved. No database migration. Rollback:
/home/ubuntu/findez-count-units-20261024.
A real isolated GLM check of the supplied screenshot's photo area returned one
blister strip, with tablet contents explicitly uncounted behind foil, in 14.8s.
This single example is not a general accuracy or latency benchmark.

Signed production 1.1.1 (131) passed archive/export verification for 32 executables,
strict signature, 24 privacy manifests, production configuration and Apple validation.
Delivery receipts are preserved in Documents/FindEZ/AppStore/1.1.1-build131.

Apple accepted build131, delivery 5449a60b-dd02-43cb-9ebe-db151501a2b5.
Processing/tester availability were not polled. IPA SHA256:
d5314b55494109e8178b7ca04afe557e0d931cd73473709597f17628b2a358f9.
No public App Store submission.

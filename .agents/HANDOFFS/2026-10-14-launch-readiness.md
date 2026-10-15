# November 1 launch reliability and remaining gates

Lane: `fix/launch-find-reliability`, based on `3543cb7` from the mobile neutral
controls lane. This is source preparation, not a production deployment or Apple
submission. Preserve Shopify in its separate disabled lane. The user explicitly
defers visual-similarity work because the FIND source is unavailable.

## What the code supports

| Journey | Verified implementation | Practical limit |
| --- | --- | --- |
| Text FIND | Authorized personal/shared/Team inventory retrieval and filters | Stored location is not a recent physical sighting |
| Photo ASK | Real FIND segmentation/identification, crops, OCR/barcode evidence; exact barcode or brand/part matching; tentative name retrieval | No image-to-image embedding search, similarity ranking or verified visual match |
| Multi-object Capture | Multiple detections, editable review, explicit Save, signed uncertain previews, Review resolution, images and destination Space | Detection quality and speed need representative physical-device testing; repeated photos are not automatically the same object |
| Physical memory | Item identity, images, quantity, Space, notes, linked documents, supported events/history | No general last-physically-confirmed field or dedicated movement/confirmation history; nested bins are not a complete client workflow |
| Assist | Authorized inventory/project/history tools, grounded result context, supported inventory mutations | Document metadata/context is supported; do not claim universal full-document retrieval or compatibility knowledge |
| Sharing | Personal/shared Spaces, view/edit permissions, Team roles and invitations | Real multi-account revocation and invitation acceptance remain release gates |
| Onboarding/auth | Four setup answers with account-bound saves; sign-in, signup, recovery and account screens | Physical fresh install, OAuth and fresh recovery links still need acceptance |
| Export/distribution | Web CSV export, iOS App Store and TestFlight paths | Formal insurance reports, referral analytics and customer demonstration results are not verified |
| Billing | This lane adds the requested five-tier monthly/yearly comparison on web and mobile | UI preparation only. Stripe subscriptions, StoreKit purchase/restore, verified entitlements and the new limit policy are not implemented |

Read-only FIND discovery checked the live `/openapi.json` and `/v1/models`:
segmentation, identification, OCR, measurements and crop assets exist, but no
embedding/similarity endpoint is exposed. No photo/job was submitted in that
inspection. Identifier/name matches must not be marketed as visual similarity.

## Reliability changes in this lane

- Capture bypasses legacy name aggregation. Each reviewed object retains its own
  item ID, photo, location and variant data. Imports keep their existing contract.
- Client capture IDs derive owner-bound UUIDs. A retry retrieves actual persisted
  rows, without increasing quantity. Changed details cannot overwrite a saved
  receipt. Old clients without IDs cannot get the same retry guarantee.
- Every input gets an accepted index or failure. Quotas no longer truncate a batch
  silently. A failed quota read is an error, not an empty inventory. A batch
  crossing personal/shared owners is rejected before writes.
- Writes are read back. A lost response after commit can return the saved receipt;
  unconfirmed persistence keeps drafts retryable. No synthetic successful rows.
- Web/mobile remove only confirmed drafts. Stable request IDs survive partial
  retries. Capture/review requests retain the initiating account token. Late web
  responses cannot populate a different account; disposed mobile sessions cannot
  continue a multi-step save.
- Photo answers expose allowlisted match evidence. General inventory rows say
  recorded quantity/location. Missing or invalid counts remain unknown. The
  answer check time is explicitly not a physical confirmation time.
- The confirmation sheet offers reuse of a saved name without pretending it links
  or updates that saved item.

There is no schema migration in this lane. Existing `items.item_id` UUID,
`space_id`, image, identity and quantity fields are reused. Quota admission remains
non-atomic across concurrent requests, so this is not a new commercial entitlement
engine. Stable IDs protect retries of the same capture, not repeated independent
photographs or arbitrary imports.

## Billing preparation and next implementation

Plans follow the user's USD prices: Free; Pro 19/month or 149/year; Team 99/month
or 790/year; Business 299/month or 2490/year; Enterprise custom. The supplied
limits are displayed as planned, not applied to current accounts. The existing
pilot remains unchanged. Paid CTAs are disabled, with real signup/contact/legal
links; no invented Stripe URL, checkout redirect or local entitlement grant.

Before enabling purchases:

1. Configure Stripe recurring products and prices for all paid periods. Replace
   the mounted legacy one-time robotics billing path with an authenticated,
   account-bound subscription checkout. Do not revive the unmounted old Stripe
   router. An arbitrary success URL or Payment Link visit cannot grant access.
2. Implement verified, idempotent Stripe subscription lifecycle handling,
   cancellation, failures, renewals and customer portal. Failed webhook processing
   must be retried, not acknowledged as success. Reconcile provider state.
3. Create Apple subscription products/group and required agreements in App Store
   Connect. Implement StoreKit purchase, pending/cancelled/failed transactions,
   restore and transaction completion with server-verified ownership/expiry.
   Reject another FindEZ account's transaction. Cover revocation/refund/renewal.
4. Reuse a single backend entitlement model across providers. First inspect the
   live profiles/teams schema; prepare any migration for review before applying.
   Model all tiers, seats, item/Space capacities and separate scan/import/share
   quotas. Define fair use before advertising it as an enforced paid policy.
5. Sandbox test purchase -> entitled access -> restore -> renewal -> cancellation
   -> expiry/refund, duplicate events, account switching and offline recovery.
   App Store display prices/terms must come from real StoreKit products. Keep
   native checkout on Apple's purchase path; no web payment link in iOS.

Primary references checked October 14:
[Apple In-App Purchase](https://developer.apple.com/documentation/storekit/in-app-purchase),
[App Store Server API](https://developer.apple.com/documentation/appstoreserverapi),
[Flutter in_app_purchase](https://pub.dev/packages/in_app_purchase),
[Stripe subscription Checkout](https://docs.stripe.com/api/checkout/sessions).
These describe the required integration, not functionality shipped in this lane.

## Next launch milestones and acceptance

1. Deploy this backend candidate first, after authorized production preflight and
   preserved rollback. Then release matching web/mobile clients. Run a disposable
   account through photo -> review -> save -> reopen -> text/identifier lookup.
   Same names in different locations must remain distinct. Force a failed/partial
   save and a lost response; retry must preserve every object exactly once.
2. Validate FIND on real labelled and unlabelled parts, clutter, variants, multiple
   similar objects and poor images. Measure success rate and capture-to-save time.
   Unknown/ambiguous results must stay uncertain. Visual similarity stays deferred.
3. Validate grounded answers: correct accessible item, explicit recorded location,
   no invented timestamp, no stock inference from an image, useful ambiguity and
   unknown paths. A recent edit must never count as a physical sighting.
4. Complete fresh install/onboarding, Google/Apple auth, password recovery, camera,
   library, voice, APNs, low connectivity, sharing/revocation and iPad touch checks.
   Source tests and simulator installation do not replace these checks.
5. Finish billing above before charging. Add privacy-aligned activation metrics:
   first confirmed save, successful repeat find, failed capture/save, onboarding
   abandonment and upgrade completion. Current query logs are not that funnel.
6. Produce the three real drawer/find-by-photo/already-own demos only after the
   demonstrated paths pass. Recruit representative testers and measure repeat
   use, finding time and willingness to pay. No growth or revenue result is assumed.

The native debug build passes with existing Pod target warnings and a parent/
share-extension version mismatch (64 vs 17). The next release archive must set and
verify matching app/extension marketing and build versions. The current debug
installation does not prove this release packaging gate. Plans is visually checked
in Light/Dark and Light is restored. No inventory/answer writes were made.

Public App Store submission remains held. Existing TestFlight build 64 does not
contain this lane or the subsequent neutral-control source. A new tested binary
and review/distribution step are still required.

## Validation for this source candidate

455 backend/API-doc tests and six subtests, 223 web tests, TypeScript, changed-file
lint (three existing Assist warnings), clean Flutter analysis and 362 mobile
tests with coverage pass. The production web build uses fictional service
configuration and a temporary cache-off webpack setting because local disk is
constrained; source config is restored. Do not deploy that build artifact.
The new pricing page is rendered in local Safari; the native simulator is rebuilt
and installed. Physical photo, auth, permission and payment acceptance is pending.

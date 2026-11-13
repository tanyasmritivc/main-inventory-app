# FindEZ for Onshape

Implementation candidate for a read-only Onshape app. Not yet registered,
published, or tested against a real Onshape grant. `registration.json` is a
registration worksheet, not an installable manifest.

## Register the tester app

In Onshape **My Account > Developer > OAuth applications**, or the owning
company's Developer settings, create **FindEZ CAD Intelligence**.

- Permission: `OAuth2Read` only. No write, delete, purchase, or profile permission.
- Redirect URL: `https://www.findez.ai/cad/onshape/callback`.
- Extension name: **Check in FindEZ**.
- Location: **Element context menu**; context: **Assembly**.
- Action type: **Open in new window**.
- Action URL: copy the full `extension.action_url` from `registration.json`.

This supported action opens the existing FindEZ comparison UI in a new browser
window. It does not embed the signed-in site in a third-party iframe or weaken
its frame/cookie policies. First use requires FindEZ login, inventory selection,
and Onshape consent. Later launches remember the inventory in that browser and
automatically check the selected assembly. Browser popup settings may require
allowing Onshape to open the window.

Configure an internal/test store entry and tester subscriptions using Onshape's
Developer settings. Company/Classroom administrators can assign internal users
without a public store entry. Do not advertise public availability before
Onshape review and publication.

## Server activation

Do not put credentials in this repository, browser JavaScript, chat, screenshots,
or logs. An operator must configure these server-only values through the existing
secret-management path:

- `ONSHAPE_CLIENT_ID`: registered app client ID.
- `ONSHAPE_CLIENT_SECRET`: registered app secret.
- `CAD_SECRET_KEY`: persistent Fernet key for encrypted OAuth tokens and signed,
  encrypted review receipts. Losing/rotating it invalidates existing connections
  and receipts. Keep it in the existing protected backup/secret workflow.

Migration `backend/supabase/migrations/086_cad_onshape.sql` must be reviewed and
approved before production application. It adds three CAD-only tables and four
service-only RPCs. It does not alter inventory quantities, Spaces, or existing
inventory columns. Deploy dependent backend code only after the schema is ready
when these settings are enabled. Without registration/configuration, connection
status explicitly reports disabled and CSV/Fusion comparison remains available.

Existing proxy/access logs must redact query strings on the OAuth callback path.
The client removes the temporary authorization code from history on mount and
posts it with the current FindEZ JWT. The one-time state is hashed, actor-bound,
expires in ten minutes, and is consumed transactionally. The callback never uses
an Onshape query-string user ID to select a FindEZ account.

## User instructions

Once installed for a tester, open the intended robot assembly/configuration,
open the assembly tab's context menu and select **Check in FindEZ**. Sign in and
choose the team's inventory on first use. Connect Onshape and approve read-only
access. FindEZ reads the selected revision and shows Covered, Short, Missing,
and Needs review. **Export shortages** downloads uncovered quantities with the
status retained, so uncertain rows are not disguised as verified purchases.

For a wrong match, open **Correct this match**, search that inventory, select the
right item and choose **Remember this match**. **None of these match** persists
a rejection; **Forget saved correction** restores automatic matching. Editors
can change decisions; viewers can compare but cannot change team decisions.
Corrections apply only within that inventory. Changed part identity, changed
inventory identity, or deletion requires review again. Quantity/location updates
do not discard a confirmed identity.

**Disconnect** deletes the locally stored credentials. To revoke Onshape's grant
as well, remove FindEZ authorization in Onshape's account settings. The app does
not claim to revoke the provider grant when only local credentials are removed.

## CSV works without registering an app

In the Onshape assembly BOM panel, choose **Flattened**, include **Name**,
**Quantity**, and **Part number**, and export CSV. In FindEZ choose the inventory,
then **CSV or Excel**, upload, **Review columns**, confirm mapping and total
individual-unit quantities, then **Compare with inventory**. Description and
Material are not identity fields. Existing file limits still apply.

The synthetic fixture in `test_cad_onshape.py` verifies Name/Description ambiguity,
leading-zero part numbers, and total counts using Onshape-style column names.
A real Onshape export is still an acceptance gate, not claimed by that fixture.

## Extraction and safety

The adapter uses the published v16 endpoints:

- `GET /documents/d/{did}/{wv}/{wvid}/currentmicroversion`
- `GET /assemblies/d/{did}/m/{mid}/e/{eid}/bom`

It requests `indented=false`, `generateIfAbsent=true`,
`includeExcluded=false`, `includeTopLevelAssemblyRow=false`,
`respectSubassemblyBomBehavior=true`, `onlyVisibleColumns=false`, and no thumbnails.
Each flat row's quantity is counted once, not multiplied by occurrence paths.
Onshape BOM exclusion and purchased-subassembly settings remain authoritative.
Names and part numbers are used; no geometry, description/material inference,
prices, CAD mutations, or stock writes are involved. Unknown columns/quantities,
ambiguous metadata and duplicate source identities fail safely to CSV review.

Only `cad.onshape.com` is supported initially. Arbitrary URL hosts and enterprise
hosts are not forwarded. Requests do not follow redirects with bearer credentials.
Provider responses are bounded to 5 MiB and 30 seconds; 429 produces a retry delay
instead of a retry loop. Microversion-pinned reads avoid mixing a moving workspace
revision with a later BOM. Inventory remains a fresh nontransactional preview,
with reservations and checkouts deducted once from shared available stock.

## Acceptance before inviting teams

- Register app, apply approved migration, configure server secrets, deploy.
- Complete OAuth with a disposable tester and check cancellation/revocation.
- Open a real assembly with repeated/nested/suppressed/configured components;
  compare Onshape's flattened CSV and direct API totals for the same revision.
- Test missing metadata, purchased subassemblies, non-geometric items and Unicode
  configurations; verify custom/localized property headers fail clearly.
- Confirm a match, recheck a new assembly revision, switch inventory/account, and
  verify decisions stay scoped. Remove/change the item and require fresh review.
- Confirm a second tester on the same editable inventory sees a saved correction,
  while a viewer cannot edit it. Revoke access during a request.
- Export shortages and verify uncertain rows remain marked. No inventory writes.
- Only then distribute tester access. Public store submission follows Onshape's
  launch checklist. No invitations or announcements have been sent.

## Vendor catalogs

Vendor feeds are the next phase. A stable REV feed URL and its reuse terms, and
goBILDA's explicit permitted crawl scope, have not yet been verified. No crawler
or daily job has been started. Do not infer permission from a claimed rate alone.
When supplied, use source attribution and timestamps, bounded fetches, allowlisted
hosts and at most one goBILDA request per second. Catalog records should improve
identity candidates; they must not imply owned stock or override team corrections.

## Official references checked November 12, 2026

- [OAuth and refresh](https://onshape-public.github.io/docs/auth/oauth/)
- [BOM API contract](https://github.com/onshape-public/go-client/blob/master/onshape/docs/AssemblyApi.md#getbillofmaterials)
- [Response schema](https://github.com/onshape-public/go-client/blob/master/onshape/docs/BTBillOfMaterialsInfo.md)
- [Extension actions and parameters](https://onshape-public.github.io/docs/app-dev/extensions/)
- [BOM export and view modes](https://cad.onshape.com/help/Content/Assembly/bill_of_material.htm)
- [API limits](https://onshape-public.github.io/docs/auth/limits/): private apps count
  against the app owner's annual allowance; publicly available App Store OAuth
  applications are exempt from that annual allowance. Endpoint rate limits still apply.
- [App Store process](https://onshape-public.github.io/docs/app-store/)

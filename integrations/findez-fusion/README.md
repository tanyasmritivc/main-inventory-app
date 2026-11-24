# FindEZ Fusion workspace candidate 0.6.0

Search parts with AI and insert geometry already in Fusion without downloading a
STEP file or switching browser tabs. Inventory and global catalog remain separate.
The backend calculates stock from recorded quantities, reservations and checkouts.

To update, stop FindEZ, replace the complete extracted add-in folder, restart
Fusion, and confirm version 0.6.0 in Scripts and Add-Ins before running it.
Native Fusion placement acceptance remains pending. Export FindEZ BOM still works.

HTTPS hostname and chain verification remain enabled. The package includes public
ISRG roots alongside system trust, from these official sources (November 15, 2026):
https://letsencrypt.org/certs/isrgrootx1.pem
https://letsencrypt.org/certs/isrg-root-x2.pem
These are public trust anchors, not private keys or account credentials.

## Install and connect

1. Extract the ZIP. In Fusion, open Utilities > Add-Ins > Scripts and Add-Ins.
2. In Add-Ins, select the local `FindEZ` folder containing FindEZ.py and
   FindEZ.manifest, then Run. Stop the older FindEZ add-in first.
3. In the Design workspace, choose Open FindEZ in Utilities.
4. Click Sign in with FindEZ. Your normal browser opens FindEZ. Sign in there,
   choose Personal or your organization, and select an authorized inventory.
5. Check that the displayed ten-character code matches the one in Fusion.
   Confirm it and click Connect this inventory. Return to Fusion.
6. The connection lasts eight hours. It reads the chosen inventory; editors can
   separately opt in to shared CAD saves and model generation during pairing.
   Disconnect to select another. Reload the connection page to list and revoke
   active sessions. Credentials remain in memory, never the HTML or local disk.

## AI search

AI search is the default for nonempty questions. Try "Find 12 M4 screws" or
"Find bearings for an 8mm shaft." AI interprets terms and constraints; it never
supplies stock records, vendor prices, model geometry or compatibility approval.
Results show matching saved records and missing specifications that need review.
Inventory quantities subtract reservations and checkouts. Catalog parts are not
owned stock. Requested shortages apply to each record separately. Use BOM for the
active assembly. Keyword search remains available if AI cannot answer.

## Insert without leaving Fusion

1. On a part result, choose Choose Fusion model.
2. Pick Current design or Fusion project. Browse project folders in the panel.
   Save the active design to a project first for project browsing.
3. Check the geometry against the selected part and tick the confirmation.
4. Click Insert into design, position with the handles and confirm. Cancel removes
   the new copy. Source components and inventory stock are not changed.

The copy preserves geometry and records the selected part and model source.
Saved FindEZ components appear first for that part in the Current design picker.
Save the design to retain these associations. No geometry is uploaded to FindEZ.

When the server has published a reviewed model for the exact variant, choose
Preview catalog model, check its source and revision, then place it. Other parts
can use existing Fusion geometry. Automatic manufacturer sourcing and nightly
catalog generation remain pending. RexCAD on-demand generation is available from Generate model with explicit CAD writing permission. Other model sources offers an
optional local STEP/F3D importer. Neither copies nor local files are certified by
FindEZ; verify units, dimensions, orientation and compatibility before engineering
use. Insertion does not reserve or consume stock. F3Z/SAT/STL and literal dragging
from the HTML panel into the canvas are not supported.

## BOM and shortages

Open BOM and click Compare current assembly. The add-in sends the current
metadata snapshot directly to FindEZ. It uses the existing conservative matching
and reservation/checkout deductions. Review unknown suppression, partial exports,
name-only matches and local model associations. Refresh after any design or stock
change; this is a snapshot, not a live stock guarantee. Export shortages CSV to
save the result locally. Needs-review rows are included but are not confirmed
purchase requirements. No ordering or automatic design substitution occurs.

The older Export FindEZ BOM toolbar command remains available and independent
of sign-in. Upload its JSON through FindEZ /cad as before. CSV/XLSX web imports
remain available. This workspace does not activate the separate Onshape app.

## Troubleshooting and privacy

If approval expires, start sign-in again. If a request loses permission, disconnect
and reconnect. On a failed disconnect, the panel clears its local session and
explains that server revocation must be retried in the browser; expiry still applies.
HTTP redirects cannot forward credentials to another host. Only the fixed FindEZ
API origin is called. No CAD geometry, file contents or private key is uploaded.
All inventory permissions are rechecked by the backend. Native host testing is
required before treating the candidate as a released Fusion add-in.

## Questions about the open design

In AI search, ask "Do I have the parts required to make this?" or "What is missing
from my current assembly?" FindEZ reads the active assembly metadata and opens
its inventory comparison in the BOM tab. It does not infer parts from the image
or send geometry to the AI. If the active design changes during interpretation,
ask again. Vague questions now ask for clarification instead of reporting a
service failure. BOM > Compare current assembly also works without AI search.

## Save BOMs and generate models (introduced in 0.4.0)

Reconnect and select the optional CAD writing permission. Editing access to the
inventory is required; existing connections remain read-only. Save the design in
Fusion first, then use BOM > Save BOM version. Historical versions and reviewed
match corrections are shared with authorized inventory members. Stock is unchanged.

Use Generate model to send explicit dimensions and units to RexCAD. Answer any
clarification in the panel, refresh status, then review and choose Insert generated
STEP. The file is downloaded automatically through FindEZ and checked by size and
SHA-256. Position the copy and confirm; Cancel removes it. Save your Fusion design
to retain it beyond the provider's seven-day temporary retention. Generated models
are unverified fabricated parts, not manufacturer-certified or owned stock.

My recent generation jobs resumes your own jobs in the same inventory. Retry an
uncertain submission with the same specification to avoid duplicates. No provider
key is stored in this add-in. Drawing uploads, previews, nightly generation and live vendor pricing remain unavailable. Manual quotes and procurement are described below. Native placement requires real Fusion
acceptance; automated host-contract checks do not establish it.

## Slate appearance retained from 0.4.1

Slate-grey panel surfaces, muted blue primary actions, softer tab selection, and
quieter BOM summaries replace the high-contrast black and white blocks. The panel
sets its own background so Fusion’s embedded browser renders consistent surfaces.
Status messages remain visible while you work. Stop FindEZ, replace the complete add-in folder, restart Fusion, and
confirm 0.6.0 before running it.


## Purchasing and planning introduced in 0.5.0

Reconnect and separately enable optional **purchase plans and receiving**. Existing
sessions do not gain this permission. In Purchases, load saved BOMs, select a
version and create a plan from current shortages. Record supplier quotes with exact
variant confirmation, prices per unit, pack size, MOQ, dates and source. Separate
all-unit price breaks with semicolons (`100, 0.08; 250, 0.06`). Live feeds are not
connected. Owners/admins approve plans and record orders placed with vendors.
Editors can receive partial deliveries into existing stock after confirming the
exact part, destination and quantity. Only receiving increases stock. There is no
checkout/payment. Ordered cancellation and returns are not supported yet.

A failed or uncertain change retains its exact request locally for the same
account and inventory. Use Retry the same change. Reconnect to the same account
and inventory to recover it. Never clear local pending data to repeat an uncertain
delivery. No token is persisted. If local storage fails, reconcile on the website.

BOM > Saved BOM versions also offers requirement differences and shared-stock
planning for up to twenty projects. Select one version per project and arrange
priority. Free stock is allocated once, earlier projects first. All existing
reservations/checkouts are excluded; incoming orders are separate. This preview
makes no reservations. Nominal specification conflicts prevent automatic matching.
Known dimensions may use explicit mm/cm/in units; missing evidence needs review.
These checks do not certify strength, tolerances, thread fit or engineering use.

## 0.5.1 purchase-plan error guidance

Creation errors now distinguish no confirmed shortages, unresolved review rows,
and an existing active plan. An empty/fabricated-only or fully covered BOM does
not need a purchase plan. For review rows, compare in BOM, resolve them, save a new
version, and select that version in Purchases. Existing plans are under Load
purchase plans. Quote expiry applies to quote approval, not to every creation
failure. Unknown server errors remain sanitized and uncertain writes retain the
same safe retry behavior. This fix does not bypass purchasing checks.

## 0.6.0 placement and inventory shortcuts

In Inventory, choose a part and select Save part to keep it on this device. The
Inventory parts menu lists saved parts and the most frequently confirmed insertions.
Both lists belong to the signed-in person and selected inventory. Opening a list
refreshes quantities against the connected server. Up to 50 parts can be saved.

For a host acceptance check, use a disposable design and an inventory containing
one recorded test part with a known manufacturer and exact part number. Choose a
STEP model you are authorized to use. Record the Fusion version and OS. Check the
initial X/Y/Z solid extents against Fusion Measure in the same orientation.
Translate and rotate the first copy, then cancel. Compare the assembly and verify
the part is absent. Confirm two copies, compare again, and export the shortages CSV.
With one uncommitted stock unit, expect two required, one assigned and one short.
Verify the recorded stock stays at one and that only confirmed placements appear
under Frequently inserted. Run once on macOS and once on Windows.

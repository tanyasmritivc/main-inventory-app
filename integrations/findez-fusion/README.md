# FindEZ Fusion workspace candidate 0.4.2

Search parts with AI and insert geometry already in Fusion without downloading a
STEP file or switching browser tabs. Inventory and global catalog remain separate.
The backend calculates stock from recorded quantities, reservations and checkouts.

To update, stop FindEZ, replace the complete extracted add-in folder, restart
Fusion, and confirm version 0.4.2 in Scripts and Add-Ins before running it.
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

A catalog record alone is not a CAD model. Parts without geometry still need a
model created or saved in Fusion. Automatic manufacturer model downloads and the
nightly catalog generation are not connected. RexCAD on-demand generation is available from Generate model with explicit CAD writing permission. Other model sources offers an
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
key is stored in this add-in. Drawing uploads, previews, nightly generation,
pricing and procurement remain unavailable. Native placement requires real Fusion
acceptance; automated host-contract checks do not establish it.

## 0.4.2 appearance update

Slate-grey panel surfaces, muted blue primary actions, softer tab selection, and
quieter BOM summaries replace the high-contrast black and white blocks. The panel
sets its own background so Fusion’s embedded browser renders consistent surfaces.
Status messages remain visible while you work. Commands, permissions and CAD behavior are
unchanged. Stop FindEZ, replace the complete add-in folder, restart Fusion, and
confirm 0.4.2 before running it.

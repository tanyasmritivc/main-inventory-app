# FindEZ Fusion workspace candidate 0.2.1

Version 0.2.1 loads the local panel through an escaped file URL, fixing the
Windows path handling that could show "This site can't be reached" on opening.
To update, stop FindEZ, replace the extracted add-in files, restart Fusion, and
confirm version 0.2.1 in Scripts and Add-Ins before running it.

This build adds a docked workspace. Activation requires the matching backend,
web connection page and reviewed device-grant migration. Until those are live,
keep using the existing Export FindEZ BOM command and web upload. Native Fusion
placement has not yet been validated on a real host.

## Install and connect

1. Extract the ZIP. In Fusion, open Utilities > Add-Ins > Scripts and Add-Ins.
2. In Add-Ins, select the local `FindEZ` folder containing FindEZ.py and
   FindEZ.manifest, then Run. Stop the older FindEZ add-in first.
3. In the Design workspace, choose Open FindEZ in Utilities.
4. Click Sign in with FindEZ. Your normal browser opens FindEZ. Sign in there,
   choose Personal or your organization, and select an authorized inventory.
5. Check that the displayed ten-character code matches the one in Fusion.
   Confirm it and click Connect this inventory. Return to Fusion.
6. The connection lasts eight hours and only reads the chosen inventory.
   Disconnect to select another. Reload the connection page to list and revoke
   active sessions. Credentials remain in memory, never the HTML or local disk.

## Browse and insert

Inventory shows recorded on-hand, reserved, checked-out and available quantities.
The location filter uses existing saved location text. Parts catalog is separate:
a catalog listing is not owned stock. Catalog specifications are displayed when
available. Prices and hosted CAD models are not connected in this first stage.

Choose Insert local model, select a STEP (.step/.stp) or Fusion archive (.f3d),
then position it with Fusion's translation/rotation handles and confirm. Scaling
is disabled. Cancel removes the new occurrence. This local file is not uploaded;
its association and geometry are unverified. Check its dimensions, units,
orientation and specifications. The wrapper records the inventory/catalog
identity and file digest; the imported geometry/hierarchy is retained below it.
No stock is consumed or reserved. F3Z, SAT and STL are not supported yet.

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

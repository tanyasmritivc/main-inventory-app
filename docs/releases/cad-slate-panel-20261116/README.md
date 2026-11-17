# Fusion 0.4.1 — slate-grey appearance

User reported harsh black panels against Fusion's grey frame (IMG_3643.DNG).
Use an explicit slate-grey body and related surface/field tones, muted blue primary
actions, underlined selected tabs, softer borders, and quieter BOM summary and
nested match sections. Busy/error messages retain sticky visibility and existing
status semantics. Public website design remains unchanged; only its two CAD
download query versions advance with the documentation links.

No Python/JavaScript behavior, command IDs, permissions, geometry, backend or DB
changes. Version and README updated to 0.4.1; package rebuilt deterministically.
All 12 ZIP entries equal source; executable code/certificates equal prior 0.4.0.
SHA256: 892adf048de38420f991a0355958d70c905be0ab3bb8f7df0b5a7b8711563284.

Checks: 16 panel/docs tests, 33 native contract tests, TypeScript, changed-file
lint, diff whitespace. Text contrast: 10.05 body, 6.02 secondary on surface,
5.28 primary button, 6.00 placeholder. Browser preview checks narrow/wide BOM
layouts with synthetic data. Native Windows Fusion appearance still needs the
user's installed-host check; the browser preview is not native acceptance.

Deployment is a five-file overlay on findez-cad-docs-hub-final-20261116, with
source guards and rollback. Candidate hardlinks are broken before replacing the
ZIP to avoid mutating the active download during staging. Unrelated website work
and old routes retained. No push/external hosting deployment.

To update: stop FindEZ in Scripts and Add-Ins, close Fusion, replace the complete
FindEZ folder with the newly extracted ZIP, restart, confirm 0.4.1 and run it.
Opening the website or refreshing the panel alone does not update local CSS.

Live: /home/ubuntu/findez-cad-slate-20261116/frontend, build S_GRX3XOMJyKaJ0By08hG.
Production build and activation checks passed. Public HTTPS download checksum,
packaged manifest/CSS, and rendered documentation links verified at 0.4.1.
BOM preview checked at 380/720px; generation form checked at 280/380px. Native
host appearance is pending installation on the user's Windows Fusion machine.

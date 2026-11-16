# Fusion workspace 0.2.2

Fixes the acknowledgement feedback loop shown in the user's Windows Fusion photo.
The Qt palette sends replies to sendInfoToHTML back through incomingFromHTML with
action=response. The handler previously tried to parse and dispatch these replies,
then sent an error that elicited another reply. The handler now ignores response
before parsing and acknowledges genuine user-command deliveries through returnData.
Unknown commands still produce an error. No tokens are exposed to the HTML panel.

Autodesk reference:
https://help.autodesk.com/cloudhelp/ENU/Fusion-360-API/files/core_Palette_sendInfoToHTML.htm

## Validation

Seven regression cases failed against the previous implementation, including
recursive response delivery. All 45 targeted Python tests and 10 web tests passed
after the fix. Scoped ESLint, whitespace and production-source Next.js build
passed. The deterministic ZIP was checked member-by-member against source and
then downloaded from the live URL to verify manifest version, fix and SHA-256.
Native Windows Fusion acceptance remains pending the user's retry.

## Release

Download: https://findez.ai/downloads/findez-fusion-workspace.zip?v=0.2.2
SHA-256: f20487ebcd475411161a37d5136944db6f11e6bf323c2ce8d799673bd622ac99
Self-hosted frontend: /home/ubuntu/findez-fusion-022-20261115/frontend
Build: tdP3CerZjT06m_Ht2W-9F
Previous frontend: /home/ubuntu/findez-docs-scroll-20261115/frontend

Production-source snapshot preserved unrelated work and used source hash guards
before activation. Only the CAD documentation/version guidance and workspace ZIP
changed on the server. The ZIP replaced a temporary file atomically so hardlinked
rollback assets retain 0.2.1. Existing immutable web assets were retained.
No backend, database, auth, mobile, public marketing, Vercel or Render changes.
Local commit only to avoid an automatic external hosting preview.

Update: stop FindEZ, replace all extracted add-in files, restart Fusion, confirm
0.2.2 in Scripts and Add-Ins, turn Run on, open FindEZ and retry sign-in.

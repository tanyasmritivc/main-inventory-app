# Fusion connection compatibility and diagnostics 0.2.3

November 15, 2026

## Finding and scope

The user reports the generic could-not-be-reached error before browser sign-in
inside Windows Fusion. The production API is reachable and the exact 0.2.2
pairing request succeeded from this environment. The user's underlying failure
has not been established. Do not describe Windows sign-in as verified or fixed.

The client now supplements system trust with official ISRG Root X1 and X2
certificates. Hostname/chain verification remains required and redirects remain
rejected. Error messages distinguish certificate, TLS handshake, DNS, timeout,
network, damaged installation and invalid JSON without exposing raw exceptions,
response bodies or credentials. No automatic retries of pairing POST requests.

Public certificate sources:
- https://letsencrypt.org/certs/isrgrootx1.pem
- https://letsencrypt.org/certs/isrg-root-x2.pem
- https://letsencrypt.org/certificates/

Certificates are public trust anchors, not private keys. Packager includes them.
Version 0.2.3 retains previous panel acknowledgement and Windows file URL fixes.
All eight website add-in links and version guidance updated; public marketing
changes are limited to download URLs. Added connection troubleshooting to docs.

## Validation

54 Python tests passed, including missing-system-root trust loading, required
TLS verification, failed installation trust loading, safe transport errors,
invalid JSON, existing redirect restrictions, pairing and placement logic.
10 frontend tests and scoped ESLint passed. Live pairing succeeded with only the
packaged CA roots and no system roots. No pairing secrets were printed or saved.
Production-source webpack build passed.

## Deployment

Self-hosted findez-web now runs:
`/home/ubuntu/findez-fusion-023-20261115/frontend`
Build: `JnPxP8K5crwFOuGCCIGTY`.
Prior release: `/home/ubuntu/findez-cad-downloads-20261115/frontend`.

Prepared from active production source; only six guidance/link modules and the
ZIP changed. Source hashes guard activation. ZIP replaced atomically so prior
hardlinked release assets remain intact. Previous service configuration retained
for rollback. Live docs and public marketing links, manifest, certificate bundle
and ZIP SHA-256 verified:
`4956ac0824fd4451f697773a34f701f852d6dc92cd8fd4d6954f4491baf7797e`.

No Vercel, Render, backend, database or mobile deployment. No remote git push,
to avoid external preview automation. User must replace the complete add-in
folder and restart Fusion, confirm 0.2.3, then retry sign-in. If it fails, the new
error code is needed to determine the remaining Windows/network issue.

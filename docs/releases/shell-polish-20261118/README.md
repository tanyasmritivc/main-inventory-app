# Web shell polish — published November 17, 2026

Smaller sidebar wordmark with the mark aligned to the lettering height; brighter
pink Founders Access treatment; distinct header surface in both themes; World
moved into the profile menu. The main chat caption is smaller (24–30px), without
shine, white in dark mode and dark in light mode. Existing composer design and
600px cap remain intact. Standard branding elsewhere is unchanged.

## Validation

- 45 focused tests across four suites passed, including World navigation/menu dismissal.
- ESLint passed for the four modified TypeScript components.
- Production webpack build and TypeScript passed on the candidate.
- Four browser cases: desktop 1440px and phone 390px, light and dark themes.
  Verified caption style, header contrast/border, profile World entry and menu
  bounds, collapsed logo and mobile navigation. No page errors.
- Live service active, eight source/asset hashes matched, two public logo hashes
  matched, new caption CSS served, and public/auth redirect routes returned 200.
  Preserved 537 other source files. Activation also checked API/database health.

Browser checks use Chrome with synthetic data and real sidebar/account/chat
components in a representative shell fixture. This is not signed-in Safari or
physical-device acceptance. The fixture is retained here as text and not deployed.

## Deployment

Active: `/home/ubuntu/findez-shell-polish-20261118/frontend`

Build: `0AzXMvfhNAqLxxPiBZYkf`

Previous: `/home/ubuntu/findez-ask-layout-20261118/frontend`

No backend, schema, mobile or inventory changes. No Git push. Old static chunks
remain available for already-open browsers. `activation.json` identifies the
systemd override; rollback removes that specific override, reloads systemd and
restarts `findez-web`, restoring the previous working directory. Never reset the
production checkout or remove unrelated overrides.

Evidence includes source manifest, activation, live verification, test results,
browser results/screenshots and guarded deployment script.

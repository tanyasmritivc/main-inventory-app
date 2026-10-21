# Ask typography correction — build 101 delivered

The reference has a smaller, lighter heading and regular input text. Mobile Ask
now uses the native iOS display face at24pt/medium with tighter tracking. The
composer uses17pt regular text, and the organization pill and tab labels have
explicit lighter weights. The shared existing typography policy is applied below
the Ask route, so inherited OS Bold Text cannot replace every label with700.
Text scaling and all other accessibility flags remain intact.

Only typography and build metadata change. Background, controls, navigation,
API behavior, organization boundaries and existing customer data are untouched.
The exact proprietary reference font cannot be verified from a screenshot; this
uses native iOS SF system text/display faces to match its visible proportions.

Validation: 35 targeted typography, appearance, world navigation and Chat tests
passed; Flutter analysis clean. All 16 native simulator cases passed in light and
dark themes, including Bold Text, large text/keyboard and navigation/draft checks.
All five CI test jobs passed on source 0e7bf9a (run 39545769323), including
712 Flutter tests (one compiled-config test skipped). Signed production archive
and export checks passed for 32 + 32 iOS executables and 24 privacy manifests;
production configuration and Apple validation passed.

Apple acknowledged upload of 1.1.0 (101), delivery
`1f58c797-1cae-4824-8efb-c9ce90c5ca59`. IPA SHA256:
`f310daea39e7eeefbe87fa6d54fdd16aae1c4e8a7901be86475c5e46d9402f61`.
Artifacts, private receipt and six previews are preserved in
`Documents/FindEZ/AppStore/1.1.0-build101`. TestFlight processing/availability were
not polled; physical-device acceptance remains pending. No public submission.

The separate Vercel web-preview check failed in unchanged Next.js Google font
resolution (`@vercel/turbopack-next/internal/font/google/font`). No frontend files
changed; this does not affect the validated native IPA. Build 101 reuses the
published build 100 API/migration 073; no API/database/customer-data changes.

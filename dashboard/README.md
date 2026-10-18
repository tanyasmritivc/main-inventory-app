# FindEZ private founder dashboard

Separate iOS app: `com.findez.dashboard`, Apple app `6824178526`.
This is the essential founder dashboard, with focused destinations for the later
product vision. It does not claim every proposed business metric is connected.

## Current experience

The October 18 revision uses a light interface, Apple's system display font,
regular body text and light metric numbers. OS Bold Text does not change these
chosen weights, at the founder's explicit request. System text scaling, semantics
and VoiceOver remain enabled. The founder-supplied graph SVG is the icon source.

Phone navigation: Overview, Issues, Customers, More. More groups Business,
Operations and Company destinations. Wider screens have a sidebar. The overview
shows customer growth, recurring revenue, tracked Assist usage, service health,
open issues and one saved or incident-driven priority. Decorative icons and
repeated priority cards were removed.

## Real data and availability

| Area | Connected now | Unavailable until instrumented or connected |
| --- | --- | --- |
| Customers | Auth directory, creation and sign-in timestamps, recorded plan/status, inventory/Space counts and memberships | Reliable last product activity, customer billing history and per-customer feature events |
| Analytics | Account totals, new accounts, daily signup history, saved records, Spaces, Teams, accounts-with-items activation proxy | DAU/WAU/MAU, sessions, onboarding funnel, retention cohorts, platforms, geography and attribution |
| Revenue | Read-only Stripe adapter implemented | Existing credentials are test mode, so actual revenue/subscriptions are unavailable. Costs, cash, profit and forecasts are not inferred |
| AI & FIND | Recorded personal/team Assist and scan quota counters, separately labeled legacy usage | Success, quality, token use, provider expenses, request traces, GPU and queue telemetry |
| Infrastructure | Direct web/backend/database probes, server resources, health history | Provider release feeds, SSL and backup verification, customer API latency and full security monitoring |
| Activity | Registrations and redacted backend diagnostic categories | Complete product, billing and deployment streams |
| Operations | Durable founder issues/priorities, status edits, monitoring incidents and audit records | Campaign attribution, acquisition cost and automatic roadmap integrations |

Every metric carries its source, definition, period and status. Tap a metric for
the definition. Unavailable metrics never become fabricated zeroes. Quota counters
may exclude unmetered pilot usage and are not AI request-success measurements.

## Refresh contract

While open and unlocked, the app requests the full snapshot every 60 seconds,
independently of the selected page. Customers, issues, activity, metrics, source
status and health all come from that response. Open customer detail routes also
observe the newest snapshot. Return to the foreground or unlock triggers an
immediate refresh. Pull-to-refresh and the refresh button are available.

Overlapping requests share one in-flight operation. A failure keeps previous data
and the actual last-success timestamp, and shows an error. Unavailable upstream
sources remain explicitly unavailable. Slow or failed network calls cannot
promise instantaneous delivery. iOS suspends background apps; the app does not
promise a 60-second background polling interval. Server health monitoring runs
separately every minute. The service cache lasts 15 seconds, shorter than the
normal app interval. Neither the service nor web gateway allows HTTP caching.

## Security and deployment

- `mobile/`: separate Flutter app and bundle. Only public Supabase configuration
  and the HTTPS founder gateway are compiled into it. Device-only Keychain
  session storage, device authentication on return and existing TOTP MFA support.
- `service/`: separate FastAPI service, localhost port 8031. Every administrative
  route validates the real Auth token and configured verified founder UUID on
  the server. Customer workspace/organization roles grant no founder privilege.
- `../frontend/src/app/api/founder/[...path]/route.ts`: strict additive gateway
  to that fixed local service. It forwards the access token, never website
  cookies or server credentials. Public API: `https://findez.ai/api/founder/v1`.
- Only the isolated dashboard SQLite store is written for issues, monitoring and
  audit. No customer application tables, schema, backend source or environment
  were modified. Customer account/billing mutations and exports are disabled.
- Email code delivery is limited to the configured founder's existing verified
  address, rate limited and audited. The API never returns the code.
- Diagnostic records omit raw customer content. No inventory contents, passwords,
  provider keys or receipt/document bodies are exposed.

Service release: `/home/ubuntu/findez-dashboard/releases/20261018-v1`.
Data: `/home/ubuntu/findez-dashboard-data`. Systemd: `findez-dashboard`.
The published gateway preserves all 300 existing frontend files by hash and adds
one route. Existing landing pages, customer routes, service configuration and
environment remain intact. Nginx was restored to its original content after
identifying the actual public routing path. Safe activation/auth receipts are in
`verification/`.

## Validation

- Flutter analysis: clean. Twelve tests pass, including exact minute refresh,
  foreground refresh, whole-snapshot replacement, coalescing, failure timestamp,
  open customer detail updates, light mode, Apple font, Bold Text and large text.
- Native iPhone 16e simulator journeys pass: password sign-in with delayed first
  snapshot, canceled unlock/recovery, overview, issue form, Customers,
  grouped navigation and Revenue. Native Keychain write/read/clear passes.
  Screenshots in `verification/ui/` use isolated fixtures, never live customers.
- Service: 12 tests pass. Website: 332 tests in 46 suites pass, including seven
  gateway cases. TypeScript and changed-file ESLint checks pass. Production web
  build passed with the existing real configuration and fonts.
- Real public API: founder 200, anonymous 401, forged token 401, customer directory
  connected, isolated dashboard issue create/resolve successful. The temporary
  QA session was revoked; no sign-in email or customer inventory write occurred.
- Signed release build 1 installed/launched on Tanya's iPhone and she confirmed
  the sign-in screen. The redesigned build 2 also installed and launched successfully. Its visual
  founder acceptance remains pending; simulator checks do not assert a real founder login/Face ID round trip.

## Local commands and release

Use the ignored `mobile/.env` for `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`DASHBOARD_API_URL`. Never place privileged credentials in mobile configuration.

```sh
cd dashboard/mobile
flutter analyze
flutter test
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/dashboard_smoke_test.dart -d <simulator-id>
flutter build ipa --release --dart-define-from-file=.env --export-options-plist=ios/DashboardExportOptions.plist
```

`tools/export_ios.py` can export with the existing Apple API signing identity if
Xcode's account-based export is unavailable. `tools/upload_ios.py` validates the
bundle, version, build, compiled API configuration and internal-only export option
before Apple validation/upload. Signing secrets stay outside the repository.

Build 2 is 1.0.0 with the light design, full refresh and graph icon. The separate
Founder Private internal group contains only the authorized founder. Public links
and external testing are disabled. Upload acknowledgement and processing/tester
availability are separate states. Apple acknowledged build 2 upload and, after the founder explicitly requested
TestFlight availability first, it was assigned to Founder Private. Apple reports
VALID, IN_BETA_TESTING and autoNotifyEnabled true for this build. See
`verification/apple-build2-release.json`. The helper `apple.rb beta-release` is
restricted to build 2 and the founder-only group. Vinod's invitation, private-data
access and future-build notification setup were deferred by the founder; no such
changes were applied. No App Store submission
or Git push is part of this delivery.


## Build 3: post-sign-in blank screen repair

Build 2 tried to construct the selected page before the first authenticated
snapshot existed. `_DashboardShellState._page` dereferenced `api.data!` even
though the outer body had a loading state. A new test reproduced the exact
null-check exception on unmodified build 2 code. The initial simulator journey
started with an already loaded fixture, which did not exercise this transition.

Build 3 guards page construction until data exists, shows a labeled loading state
and a useful retry screen after a failed first request. The privacy cover now
shows a named screen and an authenticated recovery button instead of a blank
color. Device unlock has progress, cancellation/error feedback, a timeout and
single-request protection. Returning to the background invalidates an in-flight
unlock. Founder authorization, Keychain policy, light appearance, graph icon,
font weights and 60-second refresh remain intact. No customer app, backend or
schema change is needed.

The expanded native simulator journey now enters a password through the actual
SignIn widget, holds the HTTP response to verify loading, completes the first
snapshot, cancels device unlock and recovers without relying on a resume callback.
HTTP and biometric results in this journey are isolated test fixtures. The native
Keychain round trip is tested separately. Actual iPhone sign-in/Face ID acceptance
is recorded separately and must not be inferred from simulator results.

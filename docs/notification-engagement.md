# iPhone notification channels

Implementation and test report for the multi-channel upgrade. This release has not been applied to production.

## Architecture audit

The self-hosted API already had an active five-minute systemd timer and a successful worker. The existing PostgreSQL notification queue stores account-local daily keys, inventory events, reservations, provider attempts and optional app feedback. The worker selects one recently registered authorized iPhone and sends through APNs. The app asks for permission after authentication and resolves a tapped notification against the current account and inventory permissions. The existing private founder service verifies the founder identity and enforces MFA when configured.

The original daily selector rotated actionable records over 14 days. Daily delivery used its own slot. Low stock, photo review, expiry, location reminders and opt-in Add/Scan prompts shared event caps. The old app's opened event could also come from the in-app inbox. It did not identify push-only visits or how many records someone updated.

## Implemented channels and defaults

| Channel | Eligibility and destination | Frequency |
|---|---|---|
| Daily | Around 10 AM in the saved time zone. Retains daily account/date deduplication and action rotation. Opens the chosen item, review, Add, Scan or notification inbox. | One per local day. The scheduler reserves room for the enabled daily update. |
| Inventory events | A recorded stock crossing, a newly pending photo review, an approaching recorded expiry or an existing missing-location reminder. A new photo review enters the queue immediately. | Two event slots per local day and five per rolling week. Noncritical events have a 24-hour interval, review alerts a seven-day interval. The same low-stock target has a 24-hour cooldown. A new zero-stock escalation can bypass its earlier noncritical target cooldown. |
| Add and Scan | Explicit opt-in, default personal inventory and a capable iPhone. Recent additions anywhere in the user's personal inventories suppress suggestions for three days. A recent foreground observation suppresses them for an hour. The selector alternates Add and Scan for established inventories. | At most one suggestion per local day. The same category has a two-day cooldown. |
| Discoveries and weekly insights | Independently opted-in deterministic rules find missing locations and missing quantities in personal inventory. Each selects two to four actual records and snapshots the IDs. The app opens the first unfinished record and can continue to the next. | Up to two discoveries per rolling seven days and one weekly insight per rolling seven days. Previously surfaced targets are excluded for seven days. |

A private singleton row in `notification_channel_policy` controls the engagement cap (four per local day), suggestion, discovery, weekly and event limits, cooldowns and the experiment switch. The two-hour spacing applies across noncritical notifications. Critical inventory events retain separate event limits. All channels respect quiet hours and pauses. Opportunities compete by priority within each account. The worker rotates through accounts and rechecks the current permission, target, device, preference revision, preview and budget before submission. A provider timeout with an uncertain outcome does not trigger a blind resend.

## Messages and controls

| Opportunity | Example title | Example body or action |
|---|---|---|
| Daily fallback | What would you like to find faster? | Open FindEZ and choose what you want to keep track of today. |
| Stock | Time for a stock check | Compare a recorded quantity with the shelf. Detailed previews require opt-in. |
| Photo review | Your photo is ready to review | Check the extracted items before saving them. |
| Add | Have you picked up anything new recently? | Record a purchase or part so you can find it later. |
| Scan | One shelf, one quick photo | Open Scan and review what FindEZ picks out. |
| Discovery | Make parts easier to find | With detailed previews, the message gives the actual number of selected records needing a location. |
| Weekly | A quick inventory check | Review saved records with an unknown quantity. |

The iPhone settings separate daily, inventory, photo review, Add/Scan, discovery and weekly preferences. Existing daily consent is copied from the old combined toggle. Discoveries and weekly insights default off. Older clients keep their combined daily/inventory setting. The existing lock-screen, pause and quiet-hour preferences continue to apply.

## Measurement

Queue creation and scheduling are recorded on the existing notification. Provider observations are keyed by notification and attempt number. Accepted, rejected and unknown outcomes are distinct. The new client advertises tap-reporting capability on registration. Opening the inbox from normal app navigation does not count as tapping a push.

The app reports a tap at push handling and a destination visit after the target UI renders. User interaction or a verified write records a start. An explicit review acknowledgement or successful scan with an associated stored item/review receipt can complete the corresponding workflow. Stock, quantity, location, photo resolution and item additions use actual database writes in the actor's authorized personal inventory. Repeated writes to one target count once per notification and action. Group completion requires the entire selected set. Deleted or inaccessible records never earn completion credit.

For a matching write within 24 hours, attribution uses the most recent eligible visit in that inventory. A separate observational counter associates a new personal item with the most recent notification interaction in 24 hours, across categories. Both are attribution rules and do not measure causation. Client telemetry is best effort. A provider acceptance does not prove a visible banner.

The founder dashboard includes a private 30-day report by category and variant, pseudonymous per-account accepted frequency, observed settings disablements, and subsequent disablements associated with the most recent accepted alert in seven days. The count includes changes observed in FindEZ settings. The dashboard distinguishes missing denominators from zero. Tap and push-to-completion rates use accepted pushes on tap-reporting clients. Action completion uses started workflows.

The `add_experiment` switch defaults off. When enabled, the existing first-item and Add opportunities assign accounts consistently to `add-v1/A` (“Give FindEZ one more item to remember”) or `add-v1/B` (“Have you picked up anything new recently?”). The experiment uses the same body, destination, schedule and limits.

## Migrations and validation

The five migrations named `20261125_01_notification_copy.sql` through `20261125_05_notification_reporting.sql` follow the existing daily-actions migration. They extend the queue and preferences, add service-role-only policy, evidence and analytics, and preserve prior records. The same five-minute worker serves all four channels.

The CI database job applies the migration chain to isolated PostgreSQL and runs the original policy/concurrency checks plus channel budgets, deterministic selection, attribution, reporting, timed journeys and capture completion. The customer and founder clients each have Flutter tests. The main API and private dashboard have separate Python suites. Live multi-channel banners, production migrations and client distribution are outside this implementation-only verification.

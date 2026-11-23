# FindEZ demo requests

## Using the workflow

The public form keeps contact details in the browser until the visitor submits the second step. A successful response means the request and both initial emails are in the existing durable inbox. The team notification includes every submitted answer. The visitor receives the approved confirmation. The founder's signature card is appended to the HTML version of demo emails. The plain-text version contains the message and its original sign-off.

In the existing Founder Dashboard, open **More → Business → Demo Requests** on a phone, or **Demo Requests** in the sidebar. Search by name, organization or email. Filter by organization, status or upcoming appointments. Open a prospect to read submitted answers, see mail handoffs, assign an owner, add notes, and review the internal briefing. The AI uses submitted information. The dashboard identifies proposed use cases, questions and pilot assessments as suggestions. Public organization research is disabled. Historical records can be briefed on demand.

1. Under **Meeting**, enter times you have checked on your calendar, a duration, an IANA time zone and a real HTTPS meeting link. Each time must carry its UTC offset or end in Z. FindEZ emails the prospect a private scheduling link.
2. The prospect sees available times in their browser's time zone. Confirmation records the booking and queues an iCalendar invitation for both parties. The same link handles changes and cancellations. Changes invalidate obsolete reminders. A new offer replaces an unbooked offer and rotates its private link.
3. For a confirmed booking, the worker queues reminders 24 hours and one hour beforehand when those times are still in the future. The earlier reminder expires when the final reminder becomes due.
4. Mark a meeting complete after it starts. Draft a general, pilot or no-response follow-up, review the subject and body, and optionally add the briefing's suggested paragraph. Enter a send time or approve for immediate dispatch. Record a prospect's reply to suppress pending no-response outreach. Replies arrive in the configured mailbox and are recorded manually in the CRM.
5. Use **Pilot opportunity** for scope, participants, expected workflow, onboarding and the next agreed action. Use **Pilot Discussion** and **Converted** to record actual pipeline outcomes. A follow-up requires completion and approval. The system schedules at most one active or sent message per scenario per prospect. A pending follow-up can be withdrawn.

## Data and authorization

The FastAPI service uses the existing host-local SQLite inbox at `~/.local/share/findez-demo/inbox.sqlite3`. Version 1 in `backend/app/services/demo_migrations/001_sales.sql` adds sales state, audit events, meetings and follow-ups with foreign keys and indexes. It extends the existing mail queue and preserves historical requests, messages and delivery markers. Application startup applies the versioned migration within a write transaction. Packaging must include the SQL and both template files. Starting the updated API against a production inbox constitutes a migration and requires separate release approval.

The founder API checks bearer credentials against the existing owner, verified email and MFA policy via the loopback dashboard service. Authorization failures and service outages prevent reads and writes. The public scheduling API accepts an opaque capability from a link fragment and receives it in a POST body. Its response contains only the information necessary to manage that appointment. The original email and private scheduling link grant access to the appointment, so only share them with its participants.

## Configuration

| Component | Configuration |
| --- | --- |
| Public website | Existing `NEXT_PUBLIC_API_BASE_URL`. Serve the supplied GIF at `https://findez.ai/email/findez-signature.gif`. |
| Founder dashboard | Existing Supabase session and MFA configuration. The optional Flutter build definition `DEMO_API_ORIGIN` selects the HTTPS core API. The core API expects the existing founder verification service on loopback port 8031. |
| Mail | Existing `BREVO_SMTP_USERNAME`, `BREVO_SMTP_PASSWORD`, `BREVO_SMTP_HOST`, `BREVO_SMTP_PORT`, `SMTP_FROM_EMAIL` and `SMTP_FROM_NAME`. Alternatively use existing `RESEND_API_KEY` and an authorized sender. `DEMO_FOUNDER_EMAIL` overrides the current founder mailbox for notifications, replies and the calendar organizer. SMTP takes precedence when configured. |
| AI | Existing server-side `FINDEZ_AGENT_KEY`, `FINDEZ_AGENT_BASE_URL` and `FINDEZ_AGENT_MODEL`. An unavailable gateway or malformed response yields a labeled template briefing. Confirmation and reminders operate independently of generation. |
| Calendar | The implemented adapter issues RFC 5545 invitations with a persistent per-request event UID and increasing sequence. The founder supplies availability and the meeting URL. It works with calendar clients that accept emailed invitations. Direct Google Calendar synchronization and automatic Google Meet creation have no configured adapter or credentials in this release. Those would require organizer OAuth consent, an authorized calendar, free/busy and event-write access, conference support, and reconciliation of external changes through a provider adapter. |

The mail worker uses retry backoff and records provider handoff errors. After eight unsuccessful attempts, the founder can inspect the message in **Email history** and retry after resolving the provider issue. For an ambiguous timeout, check the sending provider before authorizing another attempt. Stable Message-IDs and unique outbox jobs prevent routine duplicate submissions and sends. SMTP cannot guarantee exactly-once delivery if the provider accepts a message and the process stops before it records acceptance. Run against a shared local inbox on one host with file locking, as in the existing architecture.

## Metrics

Totals and organization counts come from submitted requests. Confirmation rate measures acceptance by the sending provider. Booking rate counts requests that reached a confirmed booking, including subsequently cancelled bookings. Completion rate uses founder-recorded completions among previously booked requests. Follow-up rate measures accepted follow-ups among completed demos. Pilot conversion counts requests with both recorded pilot and conversion statuses among all pilot discussions. Each rate exposes its numerator and denominator. Inbox delivery, opens and physical attendance are not inferred.

## Implementation files

| Area | Files |
| --- | --- |
| Intake and API registration | `backend/app/api/router.py`, `backend/app/api/routes/demo_requests.py`, `backend/app/api/routes/demo_sales.py`, `backend/app/main.py` |
| Storage and workers | `backend/app/services/demo_requests.py`, `demo_sales.py`, `demo_calendar.py`, `demo_briefings.py`, `demo_migrations/001_sales.sql` |
| Mail | `backend/app/services/email_delivery.py`, `backend/app/services/demo_templates/{confirmation.txt,signature.html}`, `frontend/public/email/findez-signature.gif` |
| Web | `frontend/src/components/{demo-booking,demo-scheduler}.tsx`, `frontend/src/app/(marketing)/book-demo/schedule/page.tsx` |
| Founder dashboard checkout | `dashboard/service/main.py`, `dashboard/mobile/lib/{main,dashboard_api,demo_requests}.dart` |
| Tests | `backend/tests/{test_demo_requests,test_demo_sales}.py`, `frontend/src/__tests__/demo-scheduler.test.tsx`, `dashboard/service/tests/test_dashboard.py`, `dashboard/mobile/test/demo_requests_test.dart` |

Local workflow tests use temporary SQLite files, in-memory provider responses, captured email messages and test sessions. They never require a real prospect, a live mailbox, a production migration or distribution of an iOS build.

## Local verification

The demo API suite passed 13 tests, the web components passed two tests, the founder service passed 25 tests and the Flutter dashboard passed 22 tests. Flutter analysis, targeted web lint and the isolated Next.js production build passed. A local Chrome run submitted the public form, booked, rescheduled and cancelled an appointment, and rendered the supplied animated signature at 390 and 1440 pixels. The email signature table and GIF were checked against the supplied ZIP. Live provider acceptance, external calendar-client behavior and on-device iOS distribution were outside this local verification.

The isolated web build used nonsecret local Supabase placeholders. Its existing World page also needed the three-world alias already installed in the web audit checkout. That alias is absent from the current frontend package manifest, so a clean install from this branch alone cannot reproduce the full-site build without it.

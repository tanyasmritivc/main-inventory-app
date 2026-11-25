# Weekly setup reminders

The existing five-minute inventory notification worker checks a separate onboarding campaign after inventory alerts. Each account can use one shared email or push slot every 168 hours. When both are eligible, the first reminder uses email and the next prefers push. If one channel is unavailable the other can use the slot. Quiet hours apply to push. With both channels unavailable the account stays due. Each account receives the introduction on its first reserved cycle, including accounts created months ago. Subsequent messages explain the value of a first item, followed by rotating spreadsheet, photo, Ask and Space suggestions.

## Eligibility and stopping

The first reminder becomes due seven days after signup. The migration includes older accounts and checks existing Spaces, items, capture reviews, nonempty inventory import sessions, positive inventory activity logs, retained personalization events and team inventory activity. A provisioned empty inventory, a search and a failed zero-row upload are insufficient. An account with past activity whose records and history have all been deleted can qualify.

A saved Space, item, qualifying work log, capture review, nonempty inventory import or named team storage location records a durable milestone. Current owners and members of an active organization are suppressed, including members represented through workspace teams. Individual and organization milestones survive subsequent deletion of inventory records. Removing an account deletes its campaign data. The authenticated recipient and their eligibility are checked again before resolving a push to the existing first-item workflow.

The worker reserves a weekly slot under a database row lock and records the channel before handing off to either provider. The final handoff checks eligibility, current verified email or current authorized device, and the saved channel preference again. A timeout, process crash or rejection can cost a cycle. The worker never sends a second message to compensate for an uncertain send. A provider may already be processing a message when an account activates or opts out.

## Configuration and release

1. Apply `backend/supabase/migrations/20261126_weekly_activation.sql` to a database with the existing inventory, organization, connector and notification-policy migrations. Release approval is required for production. Keep the campaign disabled while deploying the API and worker.
2. Set `FINDEZ_ACTIVATION_API_URL` to the HTTPS public API base including any reverse-proxy prefix. Verify a GET opens the unsubscribe confirmation and POST saves the preference. `FINDEZ_ACTIVATION_APP_URL` defaults to the protected Spaces page at https://findez.ai/spaces.
3. Email uses existing authenticated SMTP or Resend credentials and a verified account email. Each message includes HTML, plain text, one-click unsubscribe and a campaign-specific opt-out link. GET is safe for mail scanners. Signed-in users can also GET or PUT their own `/activation/preferences` with an `email_enabled` boolean.
4. For Brevo receipts, register `POST /activation/brevo-events` with bearer authentication matching `FINDEZ_ACTIVATION_BREVO_TOKEN`. Select delivery, opening, unsubscribe, hard bounce and spam events. Verify a test callback includes the original `X-Mailin-custom` correlation header. Resend currently records provider acceptance only.
5. Push uses existing APNs credentials, `FINDEZ_PERSONALIZATION_PUSH_ENABLED=1`, enabled phone alerts and the Add and Scan suggestions preference. Quiet hours, pause, lock-screen privacy and compatible device registration apply. The most recently registered eligible device receives the alert.
6. Review the eligible historical cohort before enabling outreach. Set `FINDEZ_ACTIVATION_ENABLED=1` on both API and worker when authorized. `FINDEZ_ACTIVATION_BATCH_SIZE` limits claims per worker execution (default five, maximum 100; zero pauses dispatch while preserving push taps and feedback).

## Measurement

The service-only `activation_campaign_metrics` view exposes provider acceptance, confirmed Brevo delivery, observable email opens, app-reported push delivery and taps, first Space, first item, other setup and elapsed time from signup to first observed personal activation. A provider accepting a message does not establish device delivery. Email clients can prefetch images or block them. Organization activity suppresses individual reminders without counting as a personal conversion. A milestone after a reminder establishes sequence, not causation. Use the individual reminder timeline for cohort comparisons.

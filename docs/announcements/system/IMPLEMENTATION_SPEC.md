# FindEZ AI Announcement System — Implementation Specification

## Objective

Implement a restrained, reliable announcement system for FindEZ AI that displays the supplied designs at the correct moments after sign-up/sign-in.

The three announcement categories to implement now:
1. **Founders Access** — explain the user's current access and plan status.
2. **Important product updates** — announce major product capabilities or meaningful changes.
3. **Founders announcements** — occasional, authentic company/product milestones or invitations for feedback.

Also support the supplied design variants if they are included in the attached design ZIP:
- Founders Access
- Pricing note
- What's new
- Banner
- Your plan
- Light mode

This is an announcement timing/eligibility task, not onboarding. Do not add onboarding steps, tutorials, or inventory setup flows.

## Required first step: inspect the repository

Before coding, inspect and report:
- Flutter app architecture and auth/sign-in/sign-up flow.
- Next.js/web app if announcement UI should be shared or implemented separately.
- Current plan/access/subscription state and where it is sourced.
- Supabase tables, RLS policies, migrations, and user identity handling.
- Existing modal, bottom sheet, banner, notification, or release-note components.
- Existing analytics/event tracking.
- Current UI theme, typography, spacing, button styles, dark/light theme behavior.
- Existing app routing/deep-link handling.
- Whether server-side announcement configuration is already present.

Do not assume features, plan names, pricing, or subscription status. Use existing implementation and verified product rules. If the app's current plan/access state differs from the screenshot, preserve actual state and ask/flag rather than inventing entitlements.

## Design reference instructions

The user is attaching a separate ZIP containing the popup designs. Treat it as the visual source of truth.

A screenshot reference depicts:
- A dark iOS-like bottom sheet/modal with rounded top corners.
- Heading: “You're in early.”
- A Founders Access card with “Your plan right now” and a “Free” pill.
- Comparison table with columns “Now” and “Free plan”.
- Rows such as Open and search items, See item details, Export your inventory, Ask FindEZ, Add new items, Add from a photo, Import a spreadsheet.
- A reassuring notice: “Nothing you save is ever deleted. We'll tell you before anything changes.”
- Primary “Got it” button.
- Design tabs/variants: Founders Access, Pricing note, What's new, Banner, Your plan, Light mode.

Important:
- Use the attached design ZIP's assets, source, component dimensions, and copy wherever supplied.
- Do not hardcode screenshot-specific plan entitlements unless they are confirmed in the actual product.
- Keep the app's real theme support. Light mode should use the supplied light design or properly adapt tokens—not simply invert colors.
- Preserve accessibility, safe areas, keyboard behavior, scrolling, and responsive layouts.
- Do not add fake “Free plan” restrictions or plan comparison data.

## Announcement categories and timing

### A. Founders Access announcement

Purpose: explain the user's current Founders Access status and set expectations transparently.

**Trigger**
- For a new user: after first successful sign-up and after the authenticated app shell/home screen has loaded successfully.
- For existing users: when Founders Access is first launched to the existing user base, show once to eligible users.
- Do not show over the sign-in/sign-up screen, while authentication is pending, during loading/error states, or before user data/plan status is resolved.

**Frequency**
- Once per user for this specific announcement campaign.
- Track dismissal/seen state server-side or in the existing persistent user profile mechanism so it survives reinstall/device change.
- Do not re-show on every sign-in, app launch, navigation, or widget rebuild.
- If a user closes/dismisses it, mark it seen. If CTA navigates to details, also mark it seen unless the existing product convention says otherwise.

**Content**
- Use the supplied Founders Access design.
- Keep the meaning honest: free during the current Founders Access period / current access terms. Never promise “free forever” or “lifetime access” unless the product owner explicitly confirms that policy.
- The screenshot includes a reassurance that saved inventory will not be deleted and that users will be notified before changes. Implement this exact promise only if the company is willing and technically able to honor it. Otherwise flag it for confirmation before shipping; do not silently promise it.
- The plan comparison must use actual, current entitlements from product config/backend. Avoid static fake comparison values.

### B. Important product updates (“What's new”)

Purpose: communicate a major release or meaningful user-visible capability change.

**Trigger**
- When an announcement is published and the user is eligible, show it on the first eligible app session after the app shell and core user state have loaded.
- Only publish announcements for features/changes that are actually available to that user/platform.
- Use campaign/version IDs, not a global boolean, so each release can be tracked independently.

**Frequency**
- Once per user per announcement ID.
- Recommended guardrail: no more than one non-critical promotional/announcement modal in any rolling 7-day period.
- If multiple product updates are pending, combine them into one “What's new” announcement or queue them for a later eligible session. Never stack multiple modals back-to-back.
- Minor bug fixes, tiny visual changes, and internal changes should not trigger a modal; they can appear in a release notes/What's New page if one exists.

**Dismissal**
- “Got it”, close button, or “Maybe later” should record appropriate state.
- For a dismissible modal, do not repeatedly show it after dismissal.
- If user chooses “Maybe later”, snooze it for a bounded period (e.g. 7 days) and then show only if still relevant, still active, and still under frequency caps. If the design only has a close/Got it button, follow the design and mark as seen rather than inventing controls.

### C. Founders announcements

Purpose: communicate authentic company/product milestones, early-user feedback opportunities, or meaningful roadmap news.

**Trigger**
- Only when a real announcement is published and its audience/time window matches.
- Show on the first eligible session after publication, after app initialization.
- Use the supplied founders announcement design if present; otherwise follow the existing design system.

**Frequency**
- Maximum one founders announcement modal per user every 30 days.
- Prefer roughly one every 1–2 months, and only when there is something meaningful to say.
- No fabricated milestones, fake user counts, fake scarcity, countdowns, or generic weekly “we're growing” pop-ups.
- If a product update modal was shown within the last 7 days, queue the founders announcement for a later session.

**Dismissal**
- Track per announcement ID and user.
- A dismissed announcement should not repeatedly return.
- Allow the user to revisit prior announcements through an existing “What's New”/announcement history page if available; do not invent a large new section unless scoped and approved.

## Global display rules

### Priority
1. Critical service/account notice (if existing system supports it; out of scope to invent critical messages).
2. Founders Access welcome (only if not already seen).
3. Important product update.
4. Founders announcement.

Do not let a lower-priority announcement override or duplicate a higher-priority one.

### Global frequency cap
- At most **one non-critical announcement modal per rolling 7 days per user**.
- Account/security/billing notices that are truly required may bypass this cap if the existing system supports them.
- Founders Access first-time welcome can take precedence, but it should still suppress other promotional modals for the next 7 days.
- Avoid showing a modal if user is in an active critical workflow (e.g. camera capture, file import, upload, item edit, chat response streaming, checkout). Defer until a safe point.
- Do not display two pop-ups in one session. Select the highest priority eligible announcement and queue the rest.
- Do not show a modal on every app foreground or each login.

### Session timing
- After successful auth, wait until:
  1. auth is settled,
  2. profile/plan/access state is loaded,
  3. initial app route is rendered,
  4. no critical loading or active user workflow is in progress.
- Then evaluate eligible announcements.
- Ensure UI doesn't flash or open before the app is visually ready.
- On app resume, do not re-run and show the same announcement; use a session-level guard plus persistent per-user campaign state.
- For existing users, rollout Founders Access with a controlled campaign ID and avoid showing it to users who have already seen/acknowledged it.

## Server/configuration and state

Prefer existing architecture and backend patterns. Avoid unnecessary new tables if a suitable announcement system already exists.

If a new system is needed, consider:
- `announcements`: campaign metadata/content/targeting/status/schedule/expiration/priority/type/CTA/design key.
- `user_announcement_state`: user ID, announcement ID, first shown, dismissed/acknowledged, clicked, snoozed-until.
- A unique constraint on `(user_id, announcement_id)` to prevent duplicates.
- RLS so users can only read announcements they are eligible for and their own state; admin publishing should follow existing secure admin mechanisms.
- Use stable announcement IDs/version IDs, not title text, as keys.
- Avoid storing sensitive user data in analytics.

Potential fields:
- id / campaign_id
- type (`founders_access`, `product_update`, `founders`)
- status (`draft`, `published`, `archived`)
- title/body/CTA label/CTA destination or structured payload
- design variant/key
- published_at / expires_at
- audience/eligibility
- priority
- frequency policy
- platform/locale if already supported
- created/updated timestamps

Do not add an admin dashboard unless the user asks. A seed/config-based announcement publishing path is acceptable if that matches the repo. Document how to publish/disable an announcement.

## CTA and dismissal behavior

- CTA must perform the action its label promises (e.g. open Founders Access details, plan view, or product update).
- “Got it” dismisses and records acknowledgement.
- Close icon must work and have accessible label.
- If the modal contains a comparison table, support vertical scrolling on smaller screens while keeping CTA reachable.
- Avoid dead buttons or fake destinations.
- Preserve existing navigation and modal patterns.

## Design and copy guardrails

- Premium, restrained, minimal FindEZ look.
- Use supplied assets and designs, not generic UI invented by Codex.
- Avoid excessive promotional tone.
- No fake scarcity, countdowns, or urgency.
- No “free forever” claims.
- No claims about future plan pricing unless approved.
- Keep Founder Access and pricing messages transparent.
- Keep copy as close to supplied design as possible; don't rewrite branding without reason.

## Analytics (only if existing analytics are used)

Track minimal events using current analytics conventions:
- announcement_eligible
- announcement_impression
- announcement_dismissed
- announcement_cta_clicked
- announcement_snoozed (if supported)

Include announcement ID/type, platform, and campaign version. Avoid personal inventory data in event payloads.

## Implementation safety

- Do not rewrite authentication.
- Do not change plan entitlement logic or invent pricing.
- Do not modify inventory CRUD, AI chat, scanning, photo extraction, import, or other unrelated features.
- Do not migrate plan entitlements based on a screenshot.
- Do not deploy, publish, or change production settings without explicit approval.
- If required promises or plan data cannot be verified, surface a concise question/blocker rather than making assumptions.
- Add feature flags or a safe disable mechanism if the repo already uses them.
- Avoid duplicate state across local storage and Supabase; choose one source of truth and explain it.
- Keep implementation incremental and report files changed, migrations, and tests.

## Deliverables from Codex

1. Short audit of existing app and announcement/auth architecture.
2. Proposed implementation plan before significant edits.
3. Announcement UI using the attached design ZIP.
4. Correct triggers, audience targeting, campaign IDs, frequency caps, dismissal persistence, queueing, and safe session timing.
5. Database migration only if genuinely needed, with RLS and uniqueness.
6. Tests for the behavior in QA checklist.
7. Final summary:
   - files changed
   - migrations added
   - how announcements are published/disabled
   - verified behavior
   - remaining blockers/credentials or manual steps
   - how to test on device/web

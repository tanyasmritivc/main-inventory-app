WEB FRONTEND ONLY. Add the "Build your world" onboarding to the Next.js web app. It runs right AFTER a new user signs up, before they reach the dashboard. Do not touch backend/, mobile/, the Supabase schema, RLS, env files, CI or deploy config. Do not ssh to or probe production. Work on a new local branch named web-onboarding. Do not push or deploy.

SOURCE OF TRUTH
- frontend/design/web-onboarding-a/reference/web-onboarding.html   working prototype. Open it in Chrome at 1440x900 and at 390x844 and click through both paths ("Just me" and "My team"). It defines layout, copy, motion and the 3D model. Reference only: rebuild it as React components, do not embed or copy it wholesale.
- frontend/design/web-onboarding-a/reference/screens/*.png        key frames at 1440x900 plus one phone frame.
- This mirrors the mobile onboarding (same naming, chips, colours and model). The mobile spec lives in the project doc FIND_ONBOARDING_A.md; where web and mobile differ, this prompt wins.

WHAT IS DIFFERENT FROM MOBILE
- It happens after sign up, so there is no auth step at the end and no "I already have an account" link. The last step's button is "Open my dashboard".
- There is no intro scan screen before a choice. The first step is "Welcome to FindEZ / Let's set up your first inventory." with the scan animation playing in the world panel.
- Desktop layout: app top bar (FindEZ logo, step progress, "Skip for now"), then two columns: the step on the left (max width 470), the world panel on the right (background #F0EEEA) where the isometric model builds. Under 900px wide the world panel stacks on top and the progress bar hides.
- IT MUST FIT ANY SCREEN (copy the prototype's CSS behaviour exactly):
  - Side gutters are fluid, clamp(20px, 4.5vw, 72px), plus safe-area insets. Nothing ever touches the window edge, at any width.
  - Content max width 1400px, centred.
  - On desktop (over 900px) the stage fills exactly the height under the top bar: height calc(100dvh - top bar), min 480px, max 900px, with a bottom padding of clamp(20px, 4vh, 48px). The page does not scroll; if a step is ever taller than the space, only the left column scrolls.
  - Column gap clamp(24px, 4vw, 64px). World panel radius clamp(20px, 2.4vw, 32px). Title clamp(28px, min(3.6vw, 6vh), 56px). Subtitle clamp(15px, 1.25vw, 17px). Vertical gaps use vh-based clamps so short laptop windows still fit.
  - Under 900px: one column, the world panel on top at clamp(240px, 40vh, 380px) tall, the page scrolls normally, never horizontally.
  - The SVG model uses preserveAspectRatio "xMidYMid meet" so it always fits its panel.
  - Check at 1920x1080, 1440x900, 1280x620, 1000x700 and 390x700: no horizontal scroll, nothing clipped, nothing touching an edge.
- NO CONTINUE BUTTONS on the choose, purpose and inventory steps: picking a tile or chip moves on by itself (see AUTO-ADVANCE). Typed names (organization name and "+ Custom") never move on by themselves; they use a small tick button inside the field. The only buttons are "Get started" on the welcome step and "Open my dashboard" on the last step. A visible "Back" text button sits on every step after welcome.
- "Skip for now" (top right) creates nothing and goes straight to the dashboard (the built-in Personal place).

AUTO-ADVANCE (replaces Continue)
- Choose: picking a tile previews it in the world panel, then moves to the next step after 900 ms.
- Organization name: NO timer. The user confirms with the tick button inside the field or Enter.
- Purpose: picking a chip moves on after 1100 ms (time to see the block rise). Inventory: picking a chip moves on after 1900 ms (time to see the tray and cubes drop).
- "+ Custom": opens the text field in place and focuses it, with the same tick button as the organization field. No timer; the tick or Enter moves on.
- While a timer runs, show a thin progress line (96 x 3 px, #E3E0DA track, #E8590C fill) at the right end of the Back row that fills over the delay, so the move never feels random. Picking a different chip or tile restarts it.
- Back cancels any pending timer. Coming back to a step that already has an answer does NOT auto-advance until the user changes the answer.
- Never advance from a step that is no longer showing (guard the timer with the current step).
- prefers-reduced-motion: same delays, no progress line animation.

STEP 0: AUDIT FIRST AND WRITE IT DOWN (frontend/design/web-onboarding-a/AUDIT.md)
- How sign up works today in the web app (the signup page, auth form, what route it redirects to after success, and where session and user id come from).
- The existing frontend calls for creating an organization, a workspace (inside an organization and standalone/personal) and an inventory. Name the file and function for each and the endpoint each one hits.
- How the app decides which place/workspace the dashboard opens (any last-place logic) and how to route to a specific workspace's dashboard.
- If any create call this onboarding needs does not already exist on the frontend AND the backend, STOP and report it. Do not add endpoints, migrations or backend code.

WHEN IT SHOWS
- Only for a signed-in user who has never finished or skipped it AND has no organizations and no workspaces besides the built-in Personal place.
- After sign up succeeds, route to /onboarding instead of /dashboard when those conditions hold. A user who visits /onboarding when the conditions do not hold is redirected to /dashboard. Sign in for existing users is unchanged.
- Mark it finished per user (localStorage key fz_web_onboarding_done_<userId>) on finish or skip. The "has no workspaces" check is the real guard, so someone who already set up on the iPhone never sees it.

FLOW AND COPY (exact copy, no em dashes or en dashes anywhere)
0 Welcome: eyebrow "WELCOME TO FINDEZ", title "Let's set up your first inventory.", subtitle "Three quick questions. Then point your camera at a shelf and FindEZ fills it in for you.", button "Get started".
1 Choose: title "Who's FindEZ for?", subtitle "Pick one to start. You can change it later." Tiles "Just me / Home, garage, desk or dorm." and "My team / A company, lab or team." with their mini models. Note "Starting solo? You can add an organization anytime." No button: picking a tile moves on. Before anything is picked, the world panel shows a dashed outline of the model with "Your world builds here as you answer". Hovering or focusing a tile previews that path faintly; picking it keeps that preview.
Team path:
2 Name your organization: subtitle "Use the name of your company, lab or team.", label "Organization name", placeholder "e.g. Kestrel Labs", helper "Your team will see this. You can change it later." 1 to 60 characters trimmed. A round tick button sits inside the right end of the field (40x40, #111112 with a white check, aria-label "Continue"); it is disabled (#ECEAE6 with a #B3B0A9 check) until the name is not empty. Clicking it or pressing Enter moves on. No timer: people can take as long as they like. The name shows live as a tag on the platform.
3 What's this workspace for?: subtitle "Each purpose gets its own dashboard." Chips R&D, Production, Competition, + Custom (placeholder "e.g. Field service", 1 to 40 characters).
4 Create your first inventory: subtitle "Group your things by team, like hardware or software." Chips Hardware, Electronics, Software, + Custom (placeholder "e.g. Lab supplies").
5 This is your world.: subtitle "Add more workspaces and inventories anytime. Spaces like a parts wall go inside each inventory." Legend rows ORGANIZATION / <name>, WORKSPACE / <purpose>, INVENTORY / <inventory>. Button "Open my dashboard".
Personal path (no organization step): green Personal platform tagged "Personal". Purpose subtitle "Your personal space. Only you can see it." chips Home, Workshop, Studio, + Custom. Inventory subtitle "Group your things, like tools or electronics." chips Tools, Electronics, Household, + Custom. Legend PERSONAL / Only you.
6 Setting up: title "Setting up your dashboard", subtitle "Creating what you picked. This takes a moment.", a checklist that ticks each item as it is created. Then route to the new workspace's dashboard.

VISUALS (match the prototype)
- Geist 400/500/600 and Geist Mono 500 (reuse the site's next/font setup). Background #F7F7F6. Ink #111112, secondary #6B6965, hint #8A8782, borders #E3E0DA, accent #E8590C, accent text #C2410C, selected tile fill #FFF8F3.
- Title (see the fit rules) / 600 / -0.035em. Buttons (Get started, Open my dashboard): height 54, radius 16, #111112; disabled #E3E0DA with #9A978F text. Chips height 40, pill, selected = orange fill with white text. Input height 58, radius 18, focus 2px orange.
- Step change: the new step's content rises 14px and fades in over 0.5s. The world panel never slides; it changes in place.
- The world model: same isometric model and colours as mobile (platform 200x200x22, workspace block 110x110x46 rising with a back-out ease over 0.7s when a purpose is picked, ghost dashed workspace spots fading in 1s later, inventory tray 70x70x12 over 0.6s, seven cubes dropping with a stagger of 0.12s). Tags for organization (or Personal), purpose and inventory follow the model. Camera eases (ease in-out cubic, 0.8s) between the per-step framings in the prototype's CAMS table. Render it as an SVG component driven by requestAnimationFrame; do not push per-frame values through React state.
- Changing a chip updates the model in place (no second block or tray).
- prefers-reduced-motion: no camera moves, drops or bounces; jump to the final state.

DATA
- Nothing is created until "Open my dashboard". Keep the answers in a pending object { path, orgName?, purpose, inventory, createdIds } in localStorage (key fz_web_onboarding_pending_<userId>) saved on every change, so a refresh resumes at the same step with the same answers.
- On "Open my dashboard", using the EXISTING frontend create calls, in order: team path: organization, then a workspace named <purpose> inside it, then an inventory named <inventory> inside that workspace. Personal path: a standalone workspace owned by the user named <purpose>, then the inventory inside it. The built-in Personal place is not changed.
- Idempotent: store each new id in createdIds before the next call; on retry skip what already exists. If a call fails, show one error line under the checklist, "We couldn't finish setting up. Try again.", with a "Try again" button, and keep the pending object.
- When everything exists: clear the pending object, set the done flag, set last place to the new workspace if that logic exists, and route to that workspace's dashboard.

DO NOT
- Change the dashboard, inventory screens, sign in, sign up form fields or providers.
- Add a backend endpoint, migration or Supabase change.
- Use robotics competition as the default example. Use the exact chips above.

ACCEPTANCE
1. tsc --noEmit, eslint and the existing tests pass.
2. Tests for auto-advance (tiles and chips move on after the delays above, restart on change, cancelled by Back, no advance on revisit until changed; typed names never move on until the tick or Enter) and for the pending setup: resumes after reload at the right step; creates org, workspace, inventory once and in order; retry after a failure does not duplicate; personal path creates a standalone workspace and inventory; skip creates nothing; a user with existing workspaces is redirected away from /onboarding.
3. Run next dev, sign up a fresh test account locally, and capture both paths at 1920x1080, 1440x900, 1280x620 and 390x844 at the same moments as reference/screens. Save to frontend/design/web-onboarding-a/out/ and compare side by side with the prototype; fix differences in layout, type, colour, copy and the model.
4. Report: the audit, every file created or changed, which existing create calls you used, and anything you could not match.

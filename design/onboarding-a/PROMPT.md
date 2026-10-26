# Codex prompt: replace the mobile onboarding with "Build your world"

Setup: put this whole `onboarding-a` folder in the repo at `design/onboarding-a/`. Then paste everything inside the block into Codex (GPT-6.1 Sol, high). Run it on a new branch, mobile lane only.

```
MOBILE ONLY. Replace the current first-run onboarding in the Flutter app with the new "Build your world" onboarding described below. Do not touch backend/, frontend/ (web), Supabase schema, or any API.

SOURCE OF TRUTH
Open these before writing any UI. They define the look, layout, copy and motion of each step; how the user moves through it is defined by "IT IS INTERACTIVE" below. Where this text and the references disagree on looks, the references win; list every difference in your final message.
- design/onboarding-a/reference/onboarding-team.mp4       the full "My team" path, 31 s
- design/onboarding-a/reference/onboarding-personal.mp4   the full "Just me" path, 26 s
- design/onboarding-a/reference/team/*.png                key frames, team path (1170x2532, iPhone 16e at 3x)
- design/onboarding-a/reference/personal/*.png            key frames, personal path
- design/onboarding-a/reference/auth-returning-user-CURRENT.png   the current auth screen, unchanged
- design/onboarding-a/reference/prototype/onboarding.html the animated prototype. Open it in a browser to inspect timing, geometry and colors (append #personal to the URL for the personal path). It is a reference only: implement natively in Flutter, do not embed a web view and do not copy its code.

IT IS INTERACTIVE (read this before the references)
The videos and the prototype are scripted walkthroughs of a user going through the flow. The grey circles are that user's taps and the typing is simulated. Build a real, interactive onboarding:
- Nothing advances on a timer except the intro (about 3 s, and a tap skips it). Every other step waits for the user.
- The user really picks a tile, really types the organization name with the iOS keyboard, really taps chips or "+ Custom" and types their own, and taps Continue to move on.
- The animations in section 3 are reactions to those actions: the platform morph plays when Continue is tapped on the choose step, the name tag updates on every keystroke, the block rises when a purpose is selected, the tray and items drop when an inventory is selected. Changing a selection updates the model and its label (the block or tray re-settles with the same ease, it does not stack a second one).
- The prototype's overall timeline (when each tap happens) is demo pacing only. Use the per-animation durations in section 3, not the video's timing between steps.
- Do not draw the grey touch circles, and do not add auto-play, a "watch demo" mode, or a progress timer.
- The user can go back with the iOS edge swipe at any time and change earlier answers; the model updates to match.

READ FIRST
Find the current onboarding / first-run flow and everything it touches: search for onboarding, tutorial, showcase, tutorial_controller, usage_onboarding, first launch flags, and the code that decides what screen shows after launch. Find the existing auth screen and the existing create flows / API calls for organizations, workspaces and inventories, and the last-place logic (key last_place_<userId>) if it exists. Reuse them. Report what you found before changing anything.

DO NOT
- Do not change the inventory screens or anything inside an inventory.
- Do not change the auth screen's layout, fields, buttons, providers or behavior. Only its headline and subtitle change, depending on how the user arrived (section 6).
- Do not add a FindEZ logo at the top of the onboarding steps. The logo appears only in the intro (centered) and on the auth screen.
- Do not add an endpoint or migration. If something below needs an API that does not exist, stop and tell me.
- No em dashes or en dashes in copy, comments or commit messages.
- No robotics-competition-first examples. FindEZ serves labs, companies, larger robotics companies and competitions; use the exact chip copy below.

1. NAMING (use these words everywhere in the onboarding)
- Organization: the company, lab or team. Optional.
- Workspace: the purpose. Each workspace has its own dashboard.
- Inventory: the team or group of things (hardware, software, tools).
- Space: a physical spot inside an inventory (a parts wall). Not part of onboarding.

2. VISUAL SYSTEM
- Fonts: Geist (400, 500, 600) and Geist Mono (500), bundled as assets (reuse them if already bundled).
- Background #F7F7F6 on every onboarding screen (matches the auth screen).
- Text: primary #111112, secondary #6B6965, hint #8A8782, mono label #9A978F.
- Title block: top 100, side padding 24. Title 34 / w600 / letter spacing -0.035em / line height 1.04. Subtitle 15 / line height 1.45 / #6B6965, 12 below the title.
- Primary button: height 56, radius 18, #111112 fill, white 17 / w600. Disabled: #E3E0DA fill, #9A978F text. Side inset 24, bottom 56 (bottom 96 on the choose step).
- Chips: height 38, radius full, white, 1px #E3E0DA inside border, 14.5 / w500 / #3F3D39, gap 8, wrap. Selected: #E8590C fill, white text. Chip row sits 136 above the bottom.
- Text field: height 58, radius 18, white, 1px #E3E0DA; focused 2px #E8590C; placeholder #B3B0A9; caret #E8590C; 18 / w400.
- World tags (labels on the 3D model): pill height 30, white 96%, 1px #E3E0DA, soft shadow (0, 4, 12, #111112 at 6%), 13 / w500, 8px colored dot.
- Touch targets at least 44. Contrast at least 4.5:1 for body text.

3. THE 3D MODEL ("your world")
Draw it with a CustomPainter. Isometric projection: screenX = cx + s * (x - y) * cos30, screenY = cy + s * ((x + y) * 0.5 - z). Each box draws three faces in this order: left (+y face), right (+x face), top.
- Platform (organization, or "Personal" on the personal path): 200 x 200 x 22 at the origin.
  Team: top #FFFFFF, left #D6D1C9, right #E7E3DC, top edge outline 1.4 #E8590C, front base edges 1.0 #E8590C at 35%.
  Personal: top #FFFFFF, left #CFE0D4, right #E2EEE6, outline #3E9B63.
  Soft shadow: radial ellipse under the platform, rx 240 s, ry 120 s, #111112 at 10% fading to 0.
- Workspace block: centered at (-20, -20), 110 x 110 x 46, sitting on the platform (z 22). Top #DDE7FB, left #A3B8E2, right #C2D2F1. Rises from height 0 with a back-out ease (overshoot 1.5) over 0.7 s when a purpose is chosen.
- Ghost workspace spots: two dashed 56 x 56 squares on the platform top at (62, -50) and (-50, 62), #8A8782 at 60%, dash 4/4, fade in 1.0 s after the block lands. They say "you can add more".
- Inventory tray: 70 x 70 x 12 on top of the block. Top #FCE3D3, left #D99A76, right #EDBB9C. Back-out ease 0.6 s when an inventory is chosen.
- Items: seven small cubes (12 to 16 units) drop into the tray from 80 units above with a small bounce, staggered 0.12 s, starting 0.8 s after the tray lands. Positions and colors are in the prototype (CUBES).
- Tags on the model: organization name (or "Personal") at the platform's front corner, workspace purpose above the block, inventory name above the tray. They follow the camera.
- Camera (cx, cy, s), moves with ease-in-out-cubic:
  morph from the tapped tile's mini icon (s 0.36 at the icon center) to (195, 500, 0.8) over 0.8 s;
  keyboard up while naming: (195, 360, 0.6);
  workspace step: (195, 490, 0.9); inventory step: (195, 480, 1.0);
  "This is your world": (112, 520, 0.62) with the legend on the right;
  exit: (150, 120, 0.12) while the model fades out and the auth screen fades in.
- Transitions are never page slides. Step text fades out (0.35 s) and the next step's title rises 14 px while fading in (0.5 s, ease-out-cubic). The model stays on screen and changes.
- Reduce Motion on: no camera moves, no drops or bounces; crossfade between final states.

4. FLOW AND COPY (exact copy)
Step 0, Intro (about 3 s, then fades): grey dots appear, an orange scan line sweeps top to bottom and drops small orange detection squares on the dots it passes. The FindEZ logo (the real logo asset, centered) rises with the line "Everything you own, remembered."

Step 1, Choose (02-choose-*.png):
- Title "Who's FindEZ for?" Subtitle "Pick one to start. You can change it later."
- Tile "Just me": "Home, garage, desk or dorm." with a mini blue workspace cube.
- Tile "My team": "A company, lab or team." with a mini platform, block and tray.
- Tiles: side inset 24, height 132, radius 24, white with 1px #E3E0DA; selected 2px #E8590C and #FFF8F3 fill; title 22 / w600, description 14 #6B6965.
- Note: "Starting solo? You can add an organization anytime." (13.5, #8A8782)
- Button "Continue" (disabled until a tile is chosen). Link "I already have an account" (15, #6B6965) at the bottom.
- On Continue, the chosen tile's mini model grows into the full platform (camera morph) while the other tile and the text fade.

Team path:
Step 2T, Name your organization (03, 04, 05):
- Title "Name your organization". Subtitle "Use the name of your company, lab or team."
- Field placeholder "e.g. Kestrel Labs". Helper under the field (13, #8A8782): "Your team will see this. You can change it later."
- When the field is focused, the field and helper move up above the keyboard and the camera zooms out (section 3). The name appears live as a tag on the platform.
- Continue enabled when the trimmed name is 1 to 60 characters.
Step 3T, Workspace purpose (06): title "What's this workspace for?", subtitle "Each purpose gets its own dashboard.", chips "R&D", "Production", "Competition", "+ Custom". Choosing one raises the block and labels it.
Step 4T, Inventory (07): title "Create your first inventory", subtitle "Group your things by team, like hardware or software.", chips "Hardware", "Electronics", "Software", "+ Custom". Button "Create inventory". Choosing one drops the tray and items.
Step 5T, This is your world (08): title "This is your world.", subtitle "Add more workspaces and inventories anytime. Spaces like a parts wall go inside each inventory." Legend on the right (mono label + value): ORGANIZATION / <org name>, WORKSPACE / <purpose>, INVENTORY / <inventory>. Button "Continue".

Personal path (no organization step):
Step 3P, Workspace purpose (personal/06): title "What's this workspace for?", subtitle "Your personal space. Only you can see it.", chips "Home", "Workshop", "Studio", "+ Custom". The platform is the green Personal platform tagged "Personal".
Step 4P, Inventory (personal/07): title "Create your first inventory", subtitle "Group your things, like tools or electronics.", chips "Tools", "Electronics", "Household", "+ Custom". Button "Create inventory".
Step 5P, This is your world (personal/08): same title and subtitle as 5T. Legend: PERSONAL / Only you, WORKSPACE / <purpose>, INVENTORY / <inventory>.

"+ Custom" chip: replaces the chip row with a text field in the same spot (same field style, keyboard up, camera as when naming). Placeholders: workspace "e.g. Field service", inventory "e.g. Lab supplies". 1 to 40 characters, trimmed. A "Done" on the keyboard confirms and the model updates.
Back: iOS edge swipe goes to the previous step and keeps what was entered. No visible back button.

5. HAND-OFF TO AUTH
After "This is your world" -> Continue, the model shrinks toward the logo position and fades while the existing auth screen fades in (0.6 s, rising 16 px). From here everything is the existing auth screen and existing behavior.

6. AUTH HEADLINE (the only change to the auth screen)
- Arrived from the onboarding: headline "Your dashboard is ready", subtitle "Create an account or sign in to open it."
- Arrived from "I already have an account" (or any other entry, like sign out): keep the current "Welcome back" / "Sign in to your inventory."
Pass the variant as a parameter; do not duplicate the screen.

7. DATA: SAVE THE SETUP ONLY AFTER SIGN-IN
- While onboarding, nothing is sent to the server. Keep a pending setup locally (shared_preferences or the storage the app already uses): { path: "team" | "personal", orgName?, workspacePurpose, inventoryName, createdIds: {} }. Save it after every step so it survives the app being killed; reopening resumes at the step the user left.
- After auth succeeds (sign up or sign in), create in order using the existing create flows: team path: organization -> workspace inside it -> inventory inside the workspace. Personal path: a standalone workspace owned by the user (not in an organization; it appears under WORKSPACES in the place switcher) -> inventory inside it. The built-in Personal place is not changed.
- Idempotent: store each created id in createdIds before the next call; on retry skip what already exists. If a call fails, show one retryable error state ("We couldn't finish setting up. Try again.") and never lose the pending setup.
- If the account already has organizations or workspaces (someone onboarded, then signed in to an old account), show a sheet once: "Add <org name or purpose> to your account?" with "Add it" and "Skip". Skip discards the pending setup.
- When done: clear the pending setup, set last_place_<userId> to the new workspace (if that logic exists), and open that workspace's dashboard.
- Show the onboarding only when there is no session and onboarding has not been completed on this device. "I already have an account" skips it entirely and goes to auth with the "Welcome back" copy.

8. REMOVE THE OLD ONBOARDING
Remove the old onboarding screens and their entry points. Keep any tutorial or spotlight code only if something else still uses it; list what you removed and what you kept.

ACCEPTANCE CRITERIA
1. flutter analyze is clean and existing tests pass.
2. Unit tests for the pending setup: persists across restart; resumes at the right step; creates org -> workspace -> inventory once in order; retry after a failure does not duplicate; personal path creates a standalone workspace and inventory; existing-account sheet Add and Skip; cleared after success; "I already have an account" never creates anything.
3. Widget test: the auth screen shows "Your dashboard is ready" from onboarding and "Welcome back" otherwise.
4. On the iPhone 16e simulator, record both paths and capture screenshots matching every file in reference/team and reference/personal (same moments). Save them in design/onboarding-a/out/ with the same file names. Compare side by side: layout, sizes, colors, fonts, copy and the 3D model must match. Only real data and the status bar may differ. Fix and re-shoot until they match, then paste the pairs in your final message.
5. Manual: go through both paths by hand on the simulator, typing your own organization name and using "+ Custom" at least once; nothing advances without a tap except the intro. Change a chip after selecting one and confirm the model updates instead of duplicating. Kill the app mid-onboarding and reopen, it resumes. Turn on Reduce Motion, it crossfades. VoiceOver reads every tile, chip, field and button.
6. List every file you created, changed or deleted.
```

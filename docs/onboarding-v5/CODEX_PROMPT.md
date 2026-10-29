# Codex prompt: onboarding v5, questions before sign-up (Flutter)

This replaces every earlier onboarding prompt (Option A, chat-first, sample scan, v3 and v4).

The onboarding now runs **before sign-up** and ends at the sign-up screen:

1. welcome
2. four one-tap questions
3. create account
4. a short confirmation

There is no logo in onboarding and nothing about the home screen. After sign-up, the answers are saved to the new account.

Before you run this, put these files into the repo:

| File | Goes to |
| --- | --- |
| `findez-onboarding-v5.html` | `docs/onboarding-v5/findez-onboarding-v5.html` (the reference prototype; open it in Chrome and tap through it) |
| `walkthrough.mp4` | `docs/onboarding-v5/walkthrough.mp4` (watch it for timing) |
| `onboarding-v5-flow.png` | `docs/onboarding-v5/onboarding-v5-flow.png` |

Then paste everything below the line into Codex from the repo root.

---

MOBILE (FLUTTER) ONLY. Replace the first-run flow with the pre-sign-up onboarding in `docs/onboarding-v5/findez-onboarding-v5.html` and `docs/onboarding-v5/walkthrough.mp4`. They are the source of truth for layout, copy, motion and timing. Rebuild in Flutter; do not embed the prototype.

## Scope (strict)

- Do NOT change the FastAPI backend, the Supabase schema, RLS, the Next.js web app, env files, CI or deploy config.
- Reuse the existing auth methods (Apple, Google, email). Show only the methods the app supports today.
- Do not change the main app (Ask, Spaces, More). After the confirmation, go to whatever screen the app opens today after sign-up.
- Remove earlier onboarding code (Option A, chat-first, sample scan, v3, v4, the onboarding 3D WebView) only where nothing else imports it.
- Signed-in users never see onboarding.
- Do not add features beyond what is listed here.
- Work on a new branch `feat/onboarding-v5`. Do not push.

## Flow and copy

Use the exact text below. There is **no logo** on any onboarding screen.

### 1. Welcome

- "Memory for physical things." (34pt, 500, centred)
- "A few quick questions, then FindEZ is set up for you." (15.5pt, secondary)
- Bottom: a black "Get started" button and "Takes about 20 seconds." under it.
- At the very bottom: "Already have an account? **Sign in**". It opens the existing sign-in screen directly and skips the questions.

### 2. Questions

The header is shared and stays put across all four questions:

- a round back button;
- a thin progress bar that fills to 25%, 50%, 75% and 100% (800ms);
- "Skip" on the right.

Behaviour:

- One tap selects an answer. The selection holds for 650ms so it is seen, then the next question arrives.
- Skip leaves that answer empty and moves on. Back returns to the previous question with its answer still selected.

**Q1. "What are you organizing?"** / "FindEZ sets up the first space for it."

A list of cards, each with an icon tile, title and subtitle:

| Title | Subtitle | Value |
| --- | --- | --- |
| Home | Closets, garage, kitchen | `home` |
| Workshop or garage | Tools, parts, bins | `workshop` |
| Robotics team | Parts, kits, pit cart | `robotics` |
| Lab or classroom | Equipment and supplies | `lab` |
| Business | Stock, supplies, assets | `business` |

**Q2. "Who will use FindEZ?"** / "Sharing is set up to match."

The same card list as Q1:

| Title | Subtitle | Icon | Value |
| --- | --- | --- | --- |
| Just me | A private inventory | person | `solo` |
| Me and my household | Family or roommates | house | `household` |
| A team or class | A club, lab, class or robotics team | two people | `team` |
| A company or organization | Shared across departments or sites | box | `org` |

Store the value only. Do not change sharing or permissions from this answer in this task.

**Q3. "What should FindEZ help with most?"** / "Pick the one that matters most right now."

A text-only list:

| Option | Value |
| --- | --- |
| Finding things when I need them | `find` |
| Knowing what is running low | `counts` |
| Keeping track of shared or borrowed items | `shared` |
| Buying things I already own | `dupes` |
| Getting started from scratch | `setup` |

**Q4. "How did you hear about FindEZ?"** / "This helps a small team know what works."

Wrapping pills: Instagram, TikTok, App Store, Friend or teammate, FIRST or robotics community, Search, Other. Values: `instagram`, `tiktok`, `appstore`, `friend`, `first`, `search`, `other`.

### 3. Create your account

- "Create your account" / "Your answers are saved to it."
- A small summary card listing the answers given, with these labels: Organizing, Used by, Main need, Heard from. Skipped answers are left out, and the card is hidden if every answer was skipped.
- "Continue with Apple" (black), "Continue with Google" and "Continue with email" (white with a 1px line), then "Free to start. Nothing is shared without permission."
- While auth runs, a small spinner fades in on the right of the tapped button. Nothing else changes.

### 4. Confirmation

- A black circle whose tick draws itself.
- "You're all set" / "Account created. Your answers were saved to it."
- After about 1.5s, continue to the app's normal post-sign-up screen.

## Saving the answers

- **Before sign-up:** keep the answers on the device with shared_preferences (key `findez_onboarding`), as `{use_case, used_by, main_need, heard_from, completed_at}`. Write it on every answer so nothing is lost if the app closes.
- **After sign-up succeeds:**
  1. Write the answers to the new account with Supabase user metadata: `supabase.auth.updateUser(UserAttributes(data: {'onboarding': {...}}))`. This needs no schema change.
  2. If the app already has a profile row with a free-form JSON column it can update, also write them there. Do not add columns.
  3. Only after the write succeeds, clear the local copy.
  4. If the write fails, retry on the next app launch while signed in.
- **If the person signs in to an existing account** from the welcome screen, discard the local answers and do not overwrite that account's metadata.
- **Analytics** (existing logger):
  - `onboarding_started`
  - `onboarding_answer` (question, value or `skipped`)
  - `onboarding_signup_shown`
  - `onboarding_completed` (auth method)

## Visual style

- White and black only: ink `#0B0B0C`, secondary `#5E5F64`, tertiary `#9A9BA0`, lines `#ECEBE8`, soft grey `#F5F4F1`. Font: Inter (400, 500).
- **Selected states:**
  - cards get a 1.5pt ink outline;
  - the icon tile turns ink with a white icon;
  - the round check fills ink and its tick draws itself (450ms);
  - the other options fade to 40%.
  - Selected pills (Q4) turn solid ink with white text.
- **Backdrop:** one persistent widget behind every step. It uses soft blurred colour fields with fine grain (peach `#E9C3A8`, dusty blue `#B9C8DA`, lilac `#D7CBDD`) fading to white at the bottom. The fields drift to a new position and opacity on each step over 1.4s, and never cut.

## Motion

- One curve everywhere: `Cubic(0.32, 0.72, 0, 1)`.
- **Enter:** opacity 0 → 1, translateY 14 → 0, blur 6 → 0, 680ms, with elements one after another 55ms apart (35ms for the Q4 pills).
- **Leave:** opacity 1 → 0, translateY 0 → −10, blur 0 → 4, 340ms, 18ms apart.
- **Step change:** the new step starts entering 200ms after the old one starts leaving. No page routes, slides or cuts. One stateful widget swaps step content in a `Stack`, while the header and backdrop stay in place.
- **Reduce Motion:** instant changes, with no blur and no drift.

## Check before you finish

- `flutter analyze` passes with no new warnings.
- On a fresh install in the simulator:
  - go through welcome, the four questions and sign-up;
  - confirm the answers appear in the new user's metadata in Supabase;
  - confirm the local copy is cleared.
- Skip every question. The summary card is hidden, and sign-up still works.
- "Sign in" from the welcome screen goes straight to sign-in and saves nothing.
- Record the simulator flow and compare it with `walkthrough.mp4`: no cuts or slides, and the backdrop and header never jump.
- Reduce Motion works.
- Commit on `feat/onboarding-v5`. List the files changed, what was removed, which auth methods are shown, and where the answers are stored.

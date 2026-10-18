# FindEZ web onboarding ("Build your world", after sign up)

The web version of the mobile onboarding. It runs once, right after a new user signs up, and sets up their first organization (team path), workspace and inventory, then opens that workspace's dashboard.

## What is in here

| Path | What it is |
| --- | --- |
| `PROMPT.md` | Paste this into Codex. |
| `reference/web-onboarding.html` | The clickable prototype. Open it in Chrome and click through "Just me" and "My team". |
| `reference/screens/` | Key frames at 1440x900, plus one phone-width frame. |

## Setup (Tanya)

1. Copy this folder into the repo at `frontend/design/web-onboarding-a/`.
2. Open Codex in the repo and paste everything in `PROMPT.md`.
3. Codex writes `AUDIT.md` first: how sign up works, which existing calls create organizations, workspaces and inventories. If one is missing it stops and tells you instead of touching the backend.
4. Sign up with a fresh test account on localhost and go through both paths. Nothing is pushed or deployed until you say so.

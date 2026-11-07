# FindEZ AI — Announcement System Codex Package

## What this package is
A repo-aware implementation brief for Codex to implement FindEZ's post-authentication announcements:
- Founders Access
- Important product updates / What's New
- Founders announcements
- Supporting presentation variants shown in the design reference (Pricing note, Banner, Your plan, Light mode)

## Attach the design ZIP too
The user has created a separate design ZIP containing the announcement UI designs. **Attach that design ZIP to the same Codex task alongside this specification ZIP.**

Codex must inspect the attached design ZIP and use it as the visual source of truth for the announcement UI. The screenshot shared with the user shows a dark iOS bottom-sheet/modal design for Founders Access, including:
- “You're in early.”
- Founders Access / Your plan right now / Free
- a comparison table (“Now” vs “Free plan”)
- note: “Nothing you save is ever deleted. We'll tell you before anything changes.”
- “Got it” CTA
- design variants/tabs named Founders Access, Pricing note, What's new, Banner, Your plan, Light mode.

Do not recreate or reinterpret this design if the design ZIP provides more complete source assets. Follow the supplied designs and adapt them to existing app conventions.

## How to use
1. Open the existing FindEZ repo in Codex.
2. Attach this ZIP and the separate design ZIP.
3. Ask Codex to read `README.md`, `IMPLEMENTATION_SPEC.md`, and `QA_CHECKLIST.md`.
4. Codex should inspect the current app, auth flow, plan/access model, backend, Supabase schema, and existing design system before changing code.
5. Implement in small, reviewable stages. Do not deploy or publish without the user's approval.

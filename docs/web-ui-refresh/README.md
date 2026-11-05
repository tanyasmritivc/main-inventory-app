# FindEZ web app UI refresh: handoff for Codex

**This is a design change only.** No feature is removed and none is added. Everything the web app does today keeps working; it only changes how it looks to fit the new design. The only new things on screen are four small UI additions that use existing actions and data:

- the Founding Access banner;
- Quick start;
- the typing placeholder;
- the Space info line.

**What's in this folder:**

- `CODEX_PROMPT_WEB.md`: the prompt to paste into Codex.
- `findez-web-app.html`: the approved prototype, which plays on its own. It's a visual reference only, and its data is fake.
- `screens/`: home, chat answer, + menu, Spaces, Fastener DB, item panel, Ask FindEZ, Tools, Workspaces and the organisation menu.

**How to use it:**

1. Unzip this folder into the repo at `docs/web-ui-refresh/`.
2. Open Codex from the repo root.
3. Paste everything below the line in `CODEX_PROMPT_WEB.md`.
4. Codex works on `feat/web-ui-refresh` and pushes that branch.
   - It doesn't merge into main.
   - It doesn't deploy, since findez.ai is self-hosted.
   - You review the branch and deploy it yourself.

It's web only. The mobile app, the backend and Supabase aren't touched.

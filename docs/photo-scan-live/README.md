# FindEZ live photo scan and review: handoff for Codex

**This is a UI change only.** The scan, the AI, the backend and saving all work exactly as today. Only the Review extraction card's layout changes:

- **The photo stays on screen while it scans.** Each object gets a numbered outline and its name as it's checked, with real progress.
- **The review list shows the most confident items first,** says in detail what each item is (using only what the scan already returns), and puts unknown items last.
- **It works in light and dark mode,** in the SF Pro system font.

**What's in this folder:**

- `CODEX_PROMPT_TESTFLIGHT.md`: the prompt to paste into Codex.
- `findez-photo-scan.html`: the prototype. It plays a scan; the buttons above it replay the scan, jump to the review, and switch light or dark mode.
- `overview.png`: light mode on the top row, dark on the bottom.
- `screens/dark` and `screens/light`: each step of the scan and the review. `screens/current` holds today's screens.

**How to use it:**

1. Unzip this folder into the repo at `docs/photo-scan-live/`.
2. Open Codex from the repo root on the Mac with your signing and App Store Connect access.
3. Paste everything below the line in `CODEX_PROMPT_TESTFLIGHT.md`.
4. Codex works on `feat/scan-live-review`, runs and adds tests, fixes UI bugs in this flow, and uploads to TestFlight.
   - It doesn't merge into main.
   - It reports which scan data was available and which fallbacks it used.

# FindEZ photo scan redesign: handoff for Codex

**What's in this folder:**

- `CODEX_PROMPT_TESTFLIGHT.md`: the prompt to paste into Codex. It changes the existing scan card in place and uploads the build to TestFlight.
- `findez-photo-scan.html`: the approved design, which plays on its own. It's for reference only.
- `screens/`: scanning, items arriving, done, leaving one out, stopped.
- `assets/grain.png`, `assets/InterTight-Regular.ttf` and its licence: only used if the app doesn't already have them from the Founding Access work.

**How to use it:**

1. Unzip this folder into the repo at `docs/photo-scan/`.
2. Open Codex from the repo root on the Mac with your signing and App Store Connect access.
3. Paste everything below the line in `CODEX_PROMPT_TESTFLIGHT.md`.
4. Codex works on `feat/photo-scan-riso`, pushes that branch, and uploads to TestFlight. It doesn't merge into main.

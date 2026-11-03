# FindEZ Founding Access: handoff for Codex

**What's in this folder:**

- `CODEX_PROMPT_TESTFLIGHT.md`: the prompt to paste into Codex. It builds the sheet in native Flutter and uploads it to TestFlight.
- `findez-founding-access-popup.html`: the approved design, for reference.
- `screens/`: welcome, what's included, Your plan (from Settings), plus two other palettes for comparison.
- `assets/grain.png`: the grain texture for the risograph art.
- `assets/InterTight-Regular.ttf` and `InterTight-OFL.txt`: the title font and its licence.

**How to use it:**

1. Unzip this folder into the repo at `docs/founding-access/`.
2. Open Codex from the repo root on the Mac that has your signing and App Store Connect access.
3. Paste everything below the line in `CODEX_PROMPT_TESTFLIGHT.md`.
4. Codex works on the branch `feat/founding-access-sheet`, pushes that branch, and uploads the build to TestFlight. It doesn't merge into main.

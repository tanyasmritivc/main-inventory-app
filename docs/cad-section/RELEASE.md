# CAD Intelligence landing section

Deployed November 11, 2026 at https://findez.ai/#cad through SSH to the existing self-hosted `findez-web` systemd service. No Vercel, Render, staging site, local preview, duplicate route, or alternate website was created.

## Files and scope

• `frontend/src/components/marketing-dark/page.tsx`: inserts the new component after the existing home hero, preserving its markup and all following sections.
• `frontend/src/components/marketing-dark/cad-intelligence-section.tsx`: supplied copy, sample comparison table, and CTA.
• `frontend/src/components/marketing-dark/cad-intelligence-section.module.css`: scoped supplied section styles and responsive layout.
• `frontend/src/components/marketing-dark/cad-intelligence-motion.ts`: supplied point generation/projection and sequence timings, with effect cleanup, reduced motion, offscreen pause, and tab visibility handling.
• `docs/cad-section/`: supplied archive contents, release receipt, and live Safari screenshots.

The button links to the existing `/cad` page, which is present in the current production source. No page or navigation entry was added. The eight comparison rows are static illustrative data and make no API calls. Both sample-data disclosures remain visible.

## Production release

Built on the server using its existing dependencies and environment with `npm run build -- --webpack`. The initial build stopped safely on insufficient disk space. Only regenerable webpack caches were removed; production server/static output and rollback releases were preserved. The subsequent production build passed compilation, TypeScript, and prerendering before activation.

Activation compared the current live source against the release baseline, allowed exactly four runtime file changes, and preserved 596 other frontend files, including auth, configuration, dependencies, and environment. No backend, Supabase, or mobile changes. Health checks passed after switching the existing service WorkingDirectory. Build identity is recorded in `live/deployment.json`.

## Live checks

• Public HTTPS HTML confirms hero, CAD section, and original solutions section in that order, with the existing `/cad` link and sample-data disclosure.
• Safari responsive views inspected at 1440 and 390 pixels wide. Before/after hero captures confirm the existing first-screen layout. Finished desktop and phone screenshots are in `live/`.
• Upload, row matching, final statuses, and replay were observed on the live page. The phone table remains within its column and status chips stay on one line.

• A 44-second Safari memory trace showed an initial 153.21 MB maximum and approximately 128 MB afterward. The canvas was offscreen for part of that trace. A second recording with the canvas visible was interrupted when Safari was switched to another window. A full minute of continuously visible canvas memory observation is not verified.
• Reduced-motion and cleanup paths were reviewed in source; manual OS reduced-motion emulation was not completed.

## Visual differences

The live page retains its existing fixed navigation, which is absent from the standalone reference. Existing site font files are reused. Browser font rasterization and the canvas's randomized dots/current animation angle can differ from the target screenshots. No substantive design changes were made to the supplied section.

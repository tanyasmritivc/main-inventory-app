Task: Replace the current landing page hero and the screen after it with the new pinned "hero morph" section. Web frontend only.

Source of truth (read all of it first):
- frontend/design/hero-morph/reference/index.html  (open in Chrome at 1440x900 and 1280x720, scroll slowly, hover the photo)
- frontend/design/hero-morph/SPEC.md               (every number, curve, string and colour)
- frontend/design/hero-morph/README.md

Hard rules:
- Web frontend only (frontend/). Do NOT touch backend/, mobile/, Supabase, env files, CI, DNS or deploy config.
- Do NOT ssh to, curl, or probe production or any server. Work locally only.
- No em dashes or en dashes anywhere in copy, code comments or commit messages.
- Do not push and do not deploy. Work on a new local branch named hero-morph.

Step 0. Audit first, then write it down before changing anything:
- Find the component that renders "/" (frontend/src/app/page.tsx and whatever it imports).
- List every landing section in order with its id, its headline and its file.
- Identify these three sections on the current live page:
  1. HERO: the dark full-bleed workbench photo with the scanning lens and the headline "FindEZ gives the physical world a memory."
  2. STATEMENT: "You don't organize your physical world for FindEZ. FindEZ organizes it for you." next to the phone showing the Home screen.
  3. CAPTURE INTRO: "Take a picture. That is it." with the objects found / need a look stats and the workbench photo.
- Save the audit to frontend/design/hero-morph/AUDIT.md.

Step 1. Build the new section:
- One new section, id "hero", that is pinned (position: sticky) for 1300px of extra scroll and morphs from the hero state into the "Take a picture. That is it." state exactly as the reference does.
- Follow the existing landing pattern: markup in a .tsx component, all per-frame behaviour in a separate engine .ts file that exports init(root) and returns a teardown, all CSS scoped under one root class with prefixed keyframes. The engine writes styles directly to elements inside requestAnimationFrame. Do NOT drive per-frame animation through React state.
- Port every formula in SPEC.md with the same constants. Do not simplify timings.
- Copy reference/assets/hero-workbench.jpg to frontend/public/images/landing/hero-workbench.jpg. The detection box coordinates in SPEC.md are percentages of THIS image at 4:3. Do not swap the photo.
- Fonts: use the Geist and Geist Mono already loaded by the site.
- Links: "Try FindEZ on the web" goes to /signup. "Get the iPhone app" goes to https://apps.apple.com/us/app/findez-ai/id6760401697.
- Keep the existing site header as it is. The engine reads the header's real height at runtime (HDR in SPEC.md); do not hardcode 82.
- Narrow screens (under 980px) and prefers-reduced-motion get the static layout from the reference: no pin, no morph, stacked, lens still follows the pointer on non-reduced-motion.

Step 2. Replace, do not duplicate:
- Remove the old HERO and STATEMENT sections from the page.
- The new section's end state IS the "Take a picture. That is it." intro. Remove the old CAPTURE INTRO block (headline, body, stats and its photo) so it does not appear twice. If that old section continues into further beats (for example a detection overlay or the Capture screen screenshot), keep those beats and let them follow directly after the new section.
- Leave every other section, the footer and all routes untouched.
- Keep the old components in place (unused) or move them to a clearly named legacy folder; do not delete files Tanya might want back. Say which you did.

Step 3. Check:
- tsc --noEmit, eslint and the existing jest tests must pass.
- Run next dev and take screenshots at 1440x900, 1280x720 and 390x844, at scroll positions 0, 500, 900 and 1400px, next to the same positions of reference/index.html. Save them to frontend/design/hero-morph/compare/.
- Confirm: the lens follows the mouse over the photo and drifts on its own when the mouse leaves; the six boxes appear one after another on scroll; "Objects found" counts 0 to 6 and "Needs a look" goes 0 to 1 when the gearbox housing box appears; scrolling back counts down; the card question cycles every 4.2s and lights up its box; nothing overlaps at 1280x720.

Report back: the audit, the files you changed or added, what you removed or moved, the check results, and anything in SPEC.md you could not match exactly.

# Hero morph publication

Published on 2026-10-18 after Tanya requested the hero on the actual website.

URL: https://findez.ai/
Build: `ocvFkneLLa0EzDFA14ToX`.
Previous build retained for rollback: `v5w04Y1Ji-mJsffzRYcu8`.
Local branch: `hero-morph`. No Git push was performed.

The user's publication request supersedes the initial local-only delivery for
this frontend change. Backend, mobile, database, environment values, CI, DNS,
proxy and service configuration remain unchanged.

## Preserving the actual current website

Read the running frontend before preparing the release. The live site had newer
landing changes than the original local baseline: a letter-by-letter memory
headline reveal and conditional omission of the old Own and Vision screens from
the homepage. These are preserved. All markup from `#graph` through the footer
matches the pre-publication live source exactly.

The local `landing-lab-engine.ts` and `landing-lab.css` were synchronized with
those existing live files. Neither file was changed in the production overlay.
The legacy component now retains the complete current pre-publication landing
component, preserving `/lab` as well.

Only one existing production source file changed:
`src/components/site/landing-lab.tsx`. Five runtime files were added: the hero
component, engine and stylesheet, the legacy component and the supplied photo.
All 287 other original frontend source/configuration/assets files were verified
unchanged by hash, including the production environment file. Seventy-one older
static build assets were additionally retained for already open browser tabs.

## Smooth handoff verification

The specified 1300px pin and morph curves are unchanged. The finished frame
releases into ordinary scrolling and the existing detection section enters with
its original rounded-card animation and Capture screenshot. The next memory
screen keeps its existing headline reveal.

Chrome checks pass on the isolated production candidate and on the public site
at 1440x900, 1280x720 and 390x844. The checks verify:

- No gap in layout between the hero track and the next section.
- No photo resize or jump across one-pixel steps around the pin release.
- Continuous desktop wheel scrolling across the handoff, with 85 recorded frames
  per size and a maximum 50px scroll step for the simulated 700px wheel input.
- Reverse scrolling returns to the identical pinned photo frame.
- Final counts stay at 6 and 1 during the handoff.
- The retained memory headline reveal completes correctly.
- No horizontal overflow or browser runtime errors.

Nine handoff screenshots and detailed measurements for each phase are in
`publish/candidate/` and `publish/live/`. Each phase passes five grouped checks.
The real production candidate build passed using the existing production
configuration and real site fonts, without the local font fixture.

The final local checks also pass: TypeScript without diagnostics, all 324 Jest
tests in 45 suites, full ESLint with zero errors and 55 existing/generated
warnings, and `git diff --check`. Logs are retained in `publish/`.

## Activation and rollback

The checked candidate was activated with one atomic directory exchange. Only
`findez-web` was restarted. The existing service working directory and all service,
environment and proxy configuration files were verified unchanged. The private
candidate process and local SSH tunnel were then stopped.

Active frontend:
`/home/ubuntu/findez-web-releases/invitation-handoff-20261017/frontend`.

Previous frontend retained intact:
`/home/ubuntu/findez-web-releases/hero-morph-20261018/frontend`.

Rollback consists of exchanging those two directories again and restarting only
`findez-web`. The activation helper also automatically performs that rollback if
its startup or preservation checks fail. No rollback was necessary.

`publish/deployment.json` records the build IDs, paths, preserved-file count and
frontend service status. The original local audit and comparison screenshots
remain available; this document records the later authorized publication.

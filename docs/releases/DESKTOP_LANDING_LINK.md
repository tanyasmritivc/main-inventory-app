# Desktop download link on the landing hero

Adds “Download for Mac & Windows” below the home hero chat/signup prompt, linking
to `/desktop` with the existing outlined button style. Other marketing heroes are
unchanged. Source branch: feat/desktop-landing-link, based on the exact live
sections.js revision 49ed0c7e (pre-change SHA256
91f07eabc261ed006cc215657f4f97ed99e49c242513873ddd170a4cbd7ffe5a).

Production build passed. Browser checks at 1440×900, 390×844 and 375×667 verified
that the link is visible without scrolling, no horizontal page overflow occurs,
and clicking it opens the Mac/Windows download page. Mobile screenshot reviewed.

Release copied from `/home/ubuntu/findez-desktop-20261111/candidate-v2/frontend`
to `/home/ubuntu/findez-desktop-hero-20261111/frontend`; only sections.js changes.
All desktop installers, callback fixes and unrelated production changes retained.
Service override: `zzzzzzzz-desktop-hero.conf`. Removing only that override and
reloading/restarting findez-web restores the previous release. No backend/mobile
or database changes.

## Follow-up: Plans & access in footer

Moved Plans & access from desktop and mobile marketing navigation into the Product
footer, preserving its /pricing destination. Candidate release:
`/home/ubuntu/findez-footer-plans-20261111/frontend`, copied from the desktop hero
release with only sections.js replaced. No desktop download changes.
Production build passed; live browser checks at 1440px and 390px confirmed no
Plans & access link in either navigation and a working footer link to /pricing.
Service override: zzzzzzzzz-footer-plans.conf; remove only that override to roll back.

## Follow-up: Download in navigation

Moved Download for Mac from the home hero into desktop navigation beside Sign in
and into the small-screen menu. Existing outlined style and /desktop destination
are preserved. Production build and browser checks at 1440, 1120, 1024 and 390px
pass: placement, no navigation overlap/page overflow and two Mac download cards.
Desktop/mobile screenshots reviewed. Live HTML verifies nav/menu placement and
no hero download link. Only sections.js changed in the production overlay.
Release: /home/ubuntu/findez-desktop-nav-20261111/frontend. Rollback: remove only
zzzzzzzzzzzz-desktop-nav.conf, daemon-reload and restart findez-web.

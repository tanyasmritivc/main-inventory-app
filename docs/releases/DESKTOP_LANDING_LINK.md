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

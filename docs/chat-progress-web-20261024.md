## October 24 — Chat activity and current echo branding live (PR196)

Runtime d537e3018a194c6e44765cfdf55690085567325a is live on the self-hosted website.
Actual activity has a two-second left-to-right soft shine and expandable history;
Reduce Motion shows static text. Light/dark appearance and disclosure were checked
in a local component preview. Text captures are labeled Inventory draft.
The user's latest ZIP round/ artwork and matching standalone app-icon-*-2.svg
are canonical. Browser/touch/social/legacy assets and metadata versions are updated;
all 15 live public assets match the supplied exports. Search caches refresh separately.

557 tests /77 suites, TypeScript, scoped lint (3 existing warnings), production
server build and eight route checks pass. All five runtime CI jobs passed
(40143400021). Build 7YIcfO0FBtR_GUUnTaHy7 is active. Old web release preserved and
backend PID unchanged by publication. No auth/navigation/database changes.
See docs/chat-progress-web-20261024.md and docs/brand-echo-current-20261024.

The ShinyText loop adapts the user-provided React Bits source (https://reactbits.dev):
cosine easing,120-degree40% soft band and2-second period. Only the requested loop
mode is implemented; hover/follow-pointer/glow unused options are not shipped.
CSS is scoped. History contains actual status events, capped30, reset per turn.

Manual acceptance: send text/Auto Extract, open the down-chevron, observe real
stages; check light/dark,390px/desktop and Reduce Motion. Nothing in the activity
panel is private model reasoning. A draft remains unsaved until explicit Save.

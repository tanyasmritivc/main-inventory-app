## October 24 — Chat activity disclosure (candidate)

Web-only feat/chat-progress-web-20261024 adapts the supplied React Bits shimmer
for actual server status messages, with a native details disclosure, theme support,
Reduce Motion, offscreen/hidden-tab pause and no animation-frame React rendering.
Text capture cards say Inventory draft. No navigation or auth changes.
557 Jest tests /77 suites and TypeScript pass. Changed lint has only3 existing
assist-client warnings. Local build compiled but lacks Supabase build environment;
production-configured server build and publication pending. Backend activity and
text drafts are delivered in their separate API lane.

The ShinyText loop adapts the user-provided React Bits source (https://reactbits.dev):
cosine easing,120-degree40% soft band and2-second period. Only the requested loop
mode is implemented; hover/follow-pointer/glow unused options are not shipped.
CSS is scoped. History contains actual status events, capped30, reset per turn.

Manual acceptance: send text/Auto Extract, open the down-chevron, observe real
stages; check light/dark,390px/desktop and Reduce Motion. Nothing in the activity
panel is private model reasoning. A draft remains unsaved until explicit Save.

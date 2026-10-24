## October 24 — Shiny chat activity and draft labels (candidate beta124)

Mobile-only feat/chat-progress-mobile-20261024 adds native Flutter soft status
shine and a compact down-chevron with actual received activity. Dynamic text,
light/dark and Reduce Motion supported; animations dispose and stop offscreen.
Fallback status no longer masquerades as assistant reply text. Text drafts are
labeled Inventory draft. Navigation bar and its movement are unchanged.
849 Flutter tests pass (one optional skip), analysis clean. Signed1.1.1(124) built
with production configuration. CI, archive checks and Apple upload pending.
Backend batching/draft-first behavior and web are separate release lanes.

Manual device checks: Auto Extract and ordinary chat progress; expand/collapse;
light/dark; font setting; Reduce Motion; leave/reopen chat; attachment retries.
The shimmer matches the supplied React Bits two-second soft sweep using ShaderMask,
not a web view or new dependency. Public activity only, no model chain of thought.
Physical-device acceptance is unverified until performed on a real iPhone.

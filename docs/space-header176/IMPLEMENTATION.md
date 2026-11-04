# Space header and SF Pro - build176

The latest screenshots replace the expanded Space title/breadcrumb with a centered compact title and centered item/unit counts. The title fades over the first100pt of scrolling; navigation stays available. Full-width blur remains under the status bar/navigation and pinned search/sort. Counts and status pills scroll away with content.

SpacePalette resolves immutable colours from the inherited appearance instead of forcing Dark. This covers the Space list, item info, action/sort sheets and scoped Ask. Review/Low quantity retain light-grey pills with dark text and selected semantics. Move/Ask explicitly bypass the global glass background builder, using opaque grey stadium buttons and contrasting labels in each theme. New space uses the same opaque-grey treatment; navigation layout is preserved. The Space Ask mark is tinted for contrast.

All app-owned Flutter text uses CupertinoSystemText, iOS SF Pro. Explicit Inter Tight, VoiceInter and GeistMono overrides and bundled font declarations are removed. Existing sizes/scaling remain. Text is regular throughout except semantic Markdown h1-h6 in AI answers, which use semibold; inline strong body spans remain regular. Voice, scan and Founding Access retain their behavior. Main Ask controller/composer/layout are unchanged. No backend, web, API, database or public App Store submission change.

## Verification

- Focused Space/typography/Founding Access/photo-scan/voice regressions:64 passed before the additional heading/open-sheet appearance checks.
- Full Flutter suite:1,356 passed, one existing skip. Analyzer clean. Native iOS:24 broad Space cases,12 typography/chat cases and3 final Light/Dark/System cases passed. The first full run exposed two obsolete Jakarta font loaders; removing those loaders fixed the setups and the full rerun passed.
- Ten final screenshots are retained in verification/. Reviewed the header, scrolling blur, actions and live System transition. All five exact-source CI gates passed (run41762643253). Archive/export verified33 device executables each, strict signing,27 privacy manifests, production configuration and system-font packaging. Apple validation and upload passed.
- Native screenshot checks cover compact/scrolling headers and opaque item actions in Light/Dark/System. System switches while the page and item sheet are open.
- Existing tests cover all seven sorts, part-first names, inline writes and failed drafts, photos, quantity, move, scoped Ask, keyboard, large text and protected swipe dismissal.
- No real customer data or production API is used by these fixtures. Physical iPhone/VoiceOver acceptance remains unverified.

Apple acknowledged TestFlight1.1.2(176), delivery d43dbc9d-223f-424f-a546-4550133eeaaa. Processing and tester availability remain pending/unpolled. No public App Store submission. Source 871fb57ca13d7d647024ec3b2d36a309d22ac7d1. See testflight176-receipt.json. Private build/signing material is kept outside the repository in `projects/findez-space176-private`.

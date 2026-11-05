# Mobile scan and Space consistency — build 180

The main Ask Auto-extract action now opens the iOS Camera/Photo Library action sheet. The custom explanatory popup is removed. Selection completes after dismissal before the existing image picker is invoked. Cancellation and presentation failures retain the originating chat and draft.

Scan and review surfaces use the app’s Light/Dark/System colours, regular SF Pro, a 20pt status heading, 16pt body/control text and semantic captions. The existing plain scan line and clean gradient remain. Review/Retake controls use solid fills. Scan content now shares the full-screen chat viewport beneath the fading top/bottom blur; measured insets keep the end of the card reachable above the composer, including with a keyboard.

Known photo results sort by descending identity confidence, with unknown/unidentified/generic names last and stable ties. The server’s original row indices are preserved for selection, editing, and saving; visible badge numbers follow the same sorted order in preview and review. The preview and review use the same order. Confidence sorting changes presentation only, not selection defaults or inventory writes.

The home bell and history now use equally sized 22pt SF Symbols on iOS; composer actions share 22pt sizing. Space detail uses a local 15pt body/control size and 12pt captions. Other surfaces retain the global 16pt default and intentional headings. Accessibility text scaling is preserved.

## Verification

Focused tests cover native source results/cancellation/errors, light/dark appearance, confidence ranking and original-row edits, full-screen scrolling and final review reachability, keyboard/larger text, local Space sizing, and home icon parity. The real UIKit sheet was operated in iPhone 16e Simulator: Camera, Photo Library, and outside-tap cancellation all returned correctly; light/dark appearance was inspected. No real photos or inventory data were written by this fixture.

The full Flutter suite passes 1,378 tests with one existing skip. The final light-mode and visible-numbering corrections additionally pass all 36 scan/capture regression tests. Analyzer is clean. Native visual audits, exact-source CI, and signed production package/upload results will be recorded in the release receipt. Physical iPhone camera/library acceptance remains unverified. Public App Store submission is unchanged.

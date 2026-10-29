# Inter throughout mobile

User requested Inter across all mobile pages. Shared Material themes and AppTypography use the existing bundled Inter asset; page-specific Jakarta/Geist overrides, including labels and AI Markdown, now use Inter. Native inventory list/search/header/footer text registers the same Inter-Regular face through CoreText and retains UIFontMetrics scaling. Existing sizes, weights, colors, layout and semantics are retained. Logo artwork and OS-owned authentication, permission and camera UI remain platform/graphic assets.

The font license is included, and regular/medium/semibold entries use the variable Inter font. No runtime font download, web/API/schema change or main-branch update. Release number: 1.1.1 (154).

Validation: 1,204 host tests passed with one existing skip; clean Flutter analysis. Existing typography checks assert Inter for headings, body, toolbar, buttons, hint and input in both themes, retaining scaling and semantics. Initial host layout failures came from missing Inter metrics (Ahem substitution); the shared test setup now loads the actual bundled font, and the full suite passes. Nine native iOS checks passed, including both themes, scaling, chat and narrow layouts. All five exact-source CI gates (40818486949), strict signing, 34 archive/export device binaries, 26 privacy manifests, production config and bundled font/license verification passed.

Apple acknowledged TestFlight1.1.1(154), source `088950f7ab1a53b33d1fcc9e3fdbae64caadacc1`, delivery `59e983a4-81ed-4d08-b968-d495545cfe71`. IPA and archive retained in the build154 release directory. Processing/tester availability was not polled; physical-device acceptance remains pending. Main remains unchanged. Receipt: `mobile-inter-release.json`.

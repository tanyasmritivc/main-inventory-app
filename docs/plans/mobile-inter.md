# Inter throughout mobile

User requested Inter across all mobile pages. Shared Material themes and AppTypography use the existing bundled Inter asset; page-specific Jakarta/Geist overrides, including labels and AI Markdown, now use Inter. Native inventory list/search/header/footer text registers the same Inter-Regular face through CoreText and retains UIFontMetrics scaling. Existing sizes, weights, colors, layout and semantics are retained. Logo artwork and OS-owned authentication, permission and camera UI remain platform/graphic assets.

The font license is included, and regular/medium/semibold entries use the variable Inter font. No runtime font download, web/API/schema change or main-branch update. Release number: 1.1.1 (154).

Validation: 1,204 host tests passed with one existing skip; clean Flutter analysis. Existing typography checks assert Inter for headings, body, toolbar, buttons, hint and input in both themes, retaining scaling and semantics. Initial host layout failures came from missing Inter metrics (Ahem substitution); the shared test setup now loads the actual bundled font, and the full suite passes. Native iOS validation and TestFlight delivery pending.

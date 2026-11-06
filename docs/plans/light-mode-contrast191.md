# Light-mode contrast — build191

White page/card/input fills and translucent half-point boundaries made the light
interface difficult to distinguish. Use opaque #F3F3F5 surfaces and #E9E9ED inset
surfaces on the existing white page, #B8B8BF neutral separators and #85858A field
outlines. Keep native Chats/Settings presentation and all dark-mode treatments.

Shared World/Utility themes, composer, content/glass controls and extraction
surfaces now use these roles. Legacy explicit neutral borders across inventories,
item details/editors, scanning, sharing, documents, teams and profile pages use
adaptiveBorder; dark values are resolved exactly as before. Photo content,
printed labels, colored status borders, text and scrims are not remapped.

Validation: 53 focused checks and all 1,293 Flutter tests passed (one existing
skip); analysis is clean. Regression checks measure the composited field edge
(3:1), placeholder text (4.5:1) and minimum light outline width. The native iOS
integration audit passed in both themes, including narrow/large-text/keyboard
Ask layouts, attachment menus, item fields and photo choices. Retained screenshots
were visually reviewed. Native Chats/Settings sources match build190.

All five CI gates passed at the runtime commit. Signed production lib/main.dart
archive/export passed platform, privacy, signature and configuration checks.
Apple validated and acknowledged TestFlight1.1.2(191) upload. See
light-mode-contrast191-release.json. Processing/tester availability and physical
acceptance remain pending; no processing polling or public App Store changes.

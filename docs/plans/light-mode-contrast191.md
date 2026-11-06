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

Validation: focused 53 tests passed. Existing theme/composer tests now measure
composited control-edge contrast (3:1), placeholder contrast (4.5:1) and minimum
light outline width. Full 1,293 tests passed (one existing skip); analysis is clean. Native visual
review is in progress.
Run integration_test/light_contrast_audit_test.dart filtered to Ask layout,
lower item info and photo chooser to retain native Flutter frames for review.
Release must use lib/main.dart with production defines. Upload TestFlight191 and
stop at Apple's acknowledgment; processing/device acceptance remain separate.

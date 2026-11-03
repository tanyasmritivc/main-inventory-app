# Auto Extract on iPhone

The photo flow uses the supplied prototype's local palette, system typography,
rounded sheets, scanning sweep, progressive item tiles, edit controls, searchable
Space selection and saved receipt. Normal chat, other screens, text/spreadsheet
drafts, backend endpoints and dependency versions are preserved. The shared
composer accepts optional extraction-only placeholder/Stop settings.

Existing world-scoped extraction, revision PATCH and confirmation save calls are
retained. Typed draft corrections use the same edit PATCH; ambiguous matches go
to normal chat. A successful save remembers its account/world-scoped destination;
it is checked against the current editable directory before reuse. New Space uses
the existing inventory-context resolution and create call. Undo appears only when
the receipt has every saved item ID and no Review entries. It uses the existing
scoped delete and retains successful deletions during a partial retry. It does
not undo items outside that receipt.

Adaptations to actual data and existing capabilities:

- No bounding boxes: the current extracted-item contract has no geometry.
- No fabricated detected-item events or progress percentage. The sweep runs while
  the real request is pending; returned rows reveal 120ms apart.
- Actual image URLs supply crops. A photo placeholder appears when no crop exists.
- No demo recent photos are shown; the app has no recent-photo collection.
- Numeric confidence below 0.6 starts left out, with explicit inclusion available.
  Missing confidence does not imply uncertainty. Unknown quantities still require
  the existing explicit quantity confirmation before saving.
- Existing category/brand/part-number editing is retained under More details.
- The app's existing alternate Keep uncertain items in Review action remains.
- Light appearance places the prototype's dark extraction content on a local dark
  surface for readable contrast, without changing the app theme.
- Saved details remain available. Undo is hidden for incomplete/mixed receipts.
- Physical camera/model acceptance is not established by fixture or simulator tests.

Runtime files: `mobile/lib/features/chat/chat_page.dart`,
`mobile/lib/features/chat/chat_capture_card.dart`,
`mobile/lib/features/world/world_composer.dart`, and the new
`mobile/lib/features/chat/auto_extract/` widgets. The old shared extraction loader
is untouched because the photo flow now renders inline. Tests and a test-only
photo fixture, this reference package, release notes and the build-number increment
are included for the explicitly authorized TestFlight delivery. No public App
Store submission change is part of this release.

## Photo-sheet correction after build 170

The photo, edit and Space sheets now use Flutter's standard modal bottom-sheet
route with a uniform 32% dimming barrier. The previous full-page backdrop blur
and translation are removed. Sheets reserve visible dismissal space above the
card, respect safe areas and keyboard insets, and scroll on short screens. Photo
actions stack at narrow widths or larger text sizes. Camera/Library results and
root-navigator ownership remain unchanged.

Auto Extract text now consistently uses regular (400) system type, including
headings, item names, form fields and button labels, matching the app's existing
regular-text policy and the user's follow-up request. The source-picker copy is
shorter and describes reviewing items before saving.

`test/extract_photo_sheet_test.dart` checks light/dark, 320pt at 2.6x, keyboard
reachability, nested navigation, source results, cancellation and rendered font
weight. `integration_test/extract_photo_sheet_audit_test.dart` runs the same
checks on iOS and captures layout images.

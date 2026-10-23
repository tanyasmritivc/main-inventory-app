# Mobile shell and Space refinement

Scope: Flutter only, branch fix/mobile-fluid-shell-20261022, beta 1.1.1 (115).
No backend, schema, Google connector, or external AI pipeline changes.

## Implemented

- Chat history is a route-owned, dismissible grey bottom sheet using the same modal
  presentation as account settings. Search, loading/retry, selected-chat navigation,
  New chat and confirmed swipe deletion remain functional. Composer stays mounted.
- Bottom navigation is narrower and lower, with three equal touch regions and a
  continuous glass capsule transition. Reduced motion disables its animation.
- Settings uses plain grouped rows instead of boxed sections. Feedback/profile/
  notification actions lose decorative arrows; actual nested settings retain them.
- Spaces header exposes search on demand, with no avatar. More also has no avatar.
  New space sits above navigation and resolves a writable inventory before using
  the shared manual creation flow. Repeated taps are guarded; viewers cannot create.
- Space detail uses one lazy sliver viewport. Headings, controls and rows scroll
  together, removing the nested-list cutoff. Individual item surfaces preserve
  edit/info/swipe actions; info has a full touch target. Record count is distinguished
  from stock units. Duplicate low-stock badge removed; low-quantity filter retained.
- Chat has a visible slate/plum/warm gradient in dark mode and lavender/peach in light.
- Hold microphone to record; release waits for final recognition, then sends once.
  VoiceOver activation can start/finish recording. Empty/cancelled/error recordings
  never send; native final results have a bounded wait. Existing draft text is
  retained and combined with the spoken message. Native recognizer chooses locale.

## Files and reuse

world_shell.dart and world_composer.dart reuse LiquidSurface and existing navigation.
chat_history_sheet.dart owns history state; chat_page.dart routes the selected chat
and wires voice_capture.dart. account_menu.dart/profile_page.dart retain preferences
and actions. space_directory.dart shares manual creation; inventory_page.dart changes
only presentation/scrolling. Regression tests cover sheet search/navigation, permissions,
manual creation, 1,000-row lazy rendering and voice completion/cancellation/gesture.

## Verification

Validation: 810 host Flutter tests passed, one optional visual test skipped; static
analysis clean. Eight focused voice tests also passed after correcting the native
plugin's cached initialization callback, including the actual plugin lifecycle
with a mocked native channel. Native iOS: 17 initial cases passed and four updated settings/detail
cases passed after the large-text correction. Screenshots inspected in both themes.
Apple acknowledgment will be recorded at release completion. Native visual
captures use synthetic accounts/inventory. Flutter repaint captures omit UIKit-native
attachment buttons; the existing native attachment control is unchanged.
An exploratory full run found a large-text count overflow; it was corrected before
release. Exact device microphone behavior and recognition accuracy still require a
physical iPhone; simulator tests exercise deterministic mocked voice events.

## Manual acceptance on beta 115

1. Open Chat in light and dark mode. Confirm visible gradient and narrower bottom bar.
   Switch Ask/Spaces/More repeatedly; selection glides, icons remain centered. Enable
   iOS Reduce Motion and confirm the selection changes without animation.
2. Tap history. Confirm grey slide-up sheet, swipe-down dismissal, search, open a
   saved chat and New chat. Reopen and cancel a swipe deletion; the chat must remain.
3. Open avatar settings. Check collapsed Appearance, scanning toggle, memory, support,
   legal and account actions. Switch themes and reopen to check persistence.
4. Open Spaces. Avatar is absent; search icon opens search. New space -> choose editable
   inventory -> name -> Save. Verify the new Space appears once in that inventory.
   A viewer must not see New space. More must have no avatar.
5. Open a populated Space. Scroll from controls through items and back. Search/filter,
   sort, low quantity, Review, item details and Add Item should all remain reachable.
   Repeat with large accessibility text and a long item name.
6. Hold the microphone, say "Where is my drill?", release. It should send once without
   pressing Send. Check empty release, permission denial, cancellation and a second
   recording. Verify a typed draft survives cancellation. Test on a physical iPhone.

No new dependencies or model calls. Existing speech recognition, hosting and chat
usage costs remain applicable. Google and unfinished connectors stay hidden.

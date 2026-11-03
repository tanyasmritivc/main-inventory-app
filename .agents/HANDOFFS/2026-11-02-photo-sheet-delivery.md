# Photo sheet layout and regular typography

Branch: `fix/photo-picker-layout-171` over `feat/auto-extract-exact` (build170).
Worktree: `/Users/tanyasmritivictorcharles/projects/findez-voice-composer`.

The screenshot's full-page blur is removed. Auto Extract uses a standard dimmed
bottom sheet, safe-area/keyboard-aware scrolling, a visible outside-dismiss area
and adaptive Camera/Library buttons. All Auto Extract text uses regular system
weight, as requested. Source results, edit/save APIs and inventory scopes remain.

Changed runtime: `mobile/lib/features/chat/auto_extract/extract_style.dart`,
`extract_sheets.dart`, and `extract_widgets.dart`. No backend or web edits.
Validation: Flutter analysis is clean; 1,295 full mobile tests pass with one
existing skip; four native iOS sheet checks pass. The first full runner stalled
while native compilation ran concurrently; the complete standalone retry passed.
Host previews are in `/Users/tanyasmritivictorcharles/projects/findez-photo171-preview`.
Do not rerun completed checks unless the source changes. The host preview uses
the installed system text font but does not load the Cupertino icon font; native
checks use iOS rendering. No physical camera or real photo library was accessed.

## Delivery blocker

The prior release's production defines, export settings and Apple API metadata
under `Documents/FindEZ/AppStore` are absent in this workspace. In particular,
`1.0.7-review-fix/apple-api-metadata.json` and
`1.1.2-build170/production-defines.json` cannot be read because they do not exist.
Apple signing identities and private keys are present, but an issuer/key mapping
and verified current production defines are still needed. Do not substitute the
old main-checkout environment: it points to legacy OpenStack hostnames.

No new IPA was signed or uploaded. `pubspec.yaml` remains 1.1.2+170 until a release
can be prepared from this change. Restore the trusted release configuration,
check Apple's latest build number, increment once, package, verify all device
binaries/signatures/configuration/privacy, validate and upload. Stop at Apple
upload acknowledgement. Public App Store submission is outside this task.
Physical camera/Library acceptance remains a device check.

# Photo sheet layout and regular typography

Branch: `fix/extraction-loading-layout` over `fix/photo-picker-layout-171`,
which builds on `feat/auto-extract-exact` (build170).
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

## Loading follow-up

The follow-up removes raw server counts, fixed 8% progress, duplicate active
photos and empty placeholder tiles. The live loader uses count-free server phases
and indeterminate activity, with a bounded contain-fit image. Extraction and
review reserve header/composer layout space. See the implementation notes for
behavior and regression checks. Final validation: 1,297 full mobile tests pass
(one existing skip), clean analysis and nine native iOS extraction/keyboard checks.
Native screenshots are saved in `projects/findez-loader-preview`; the loading
image and compact keyboard layout were inspected. No production configuration,
API contracts or backend files changed. Release remains blocked as above.

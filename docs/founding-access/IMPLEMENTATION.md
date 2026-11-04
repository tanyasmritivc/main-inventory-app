# Founding Access native sheet

Branch `feat/founding-access-sheet`, based on delivered build171, in the existing checkout. Delivered 1.1.2 (172). No second checkout or main merge.

## Entry points and scope

- `AuthPage` records a local receipt only for a user created during the successful email/Apple/Google authentication request. Duplicate email responses, anonymous users, cached sessions and returning accounts do not acquire a receipt. Email verification can finish later on this device.
- `LaunchAuthGate` uses `FoundingAccessGate` in place of the older plan welcome dialog. `WorldShell` signals when Ask mounts after onboarding and inventory initialization; the sheet waits 500ms. Account changes dispose the pending timer and modal. Local dismissal keys are `founding_access_seen_<userId>` and survive relaunch.
- Settings already links to `PlansPage`. Its new first row is Your plan / Founding Access and opens details directly. Existing plan cards and actions stay in place.
- All sheet text is fixed presentation copy. No billing, entitlement, API, database, inventory, backend or web changes. No Supabase metadata is written by the new feature. Existing authentication requests are unchanged.

## Reused pieces and design

- SharedPreferences provides the per-account local receipt. Existing native auth responses supply identity; no authentication provider or storage package was added.
- The bundled VoiceInter font supplies Inter for this sheet; the supplied Inter Tight Regular and license supply its title. The existing white clove SVG is reused. System typography elsewhere is unchanged.
- There was no reusable mobile risograph artwork or analytics client (only developer logs). `RisoArt` paints the supplied grain tile twice over the gradient and blobs and exposes four palettes. No analytics package or events were added. The supplied noise PNG spans pure black/white unlike the reference SVG noise; the painter centers its tonal range before applying the specified 95% overlay and 80% soft-light passes. The PNG itself is unchanged.
- Native Flutter draws both views; the HTML and reference PNGs remain documentation only. Art is clipped on all four corners, with slow reversible drift. Reduce Motion uses fades and disables drift, scale, slide and animated resizing.
- Content wraps up to 90% of the viewport and then scrolls. The action area stays visible, respects the bottom safe area, and expands with Dynamic Type. Buttons meet 44pt; the grab handle supports downward swipes. The modal traps focus, excludes underlying semantics, supports Escape/backdrop/swipe/button dismissal and labels itself Founding Access.

## Release process

Reuse build171's verified production defines, export options and Apple API metadata from the private release directory. Run focused/full Flutter tests, analyzer, native iOS layout/lifecycle checks and exact-source CI. Clean before production archive to avoid simulator framework contamination. Verify archive/export Mach-O platforms, signatures, app/extension version, privacy manifests, bundled fonts/texture and compiled production defines, then validate/upload with altool. No new certificates, profiles, credentials or dependencies.

The requested What to Test text is saved and verified against build172 using Apple's betaBuildLocalizations API. Public App Store submission is outside this task.

## Validation

Clean analyzer and 15 native iOS scenarios pass. Four viewport configurations (375x667, 390x844, 440x956 and 320x568 at 200% text) and both reduced/normal motion were checked; 12 native screenshots are in `verification/`. Existing Plans tests now scroll to the preserved notice at 260% text after the new row is inserted. All 1,327 Flutter regression tests pass (one existing skip). Eighteen focused Founding Access/Plans checks pass. All five exact-source CI gates passed (41741633856). Apple acknowledged the signed upload, delivery `d5553ee7-a4d2-4fb7-88a2-cda177976f59`; processing is VALID. Tester availability is unverified. See `testflight172-receipt.json` for the binary hash, runtime commit and validation receipt. Native fixtures use synthetic auth identities and local storage, not real account creation or customer inventory. Physical-device acceptance remains separate.


## Changed files

- `mobile/lib/features/founding_access/`: native sheet, palettes/art, local receipts and signup gate.
- `mobile/lib/features/auth/auth_page.dart`, `mobile/lib/main.dart`, `mobile/lib/features/world/world_shell.dart`: signup receipt and Ask-ready hooks.
- `mobile/lib/features/profile/plans_page.dart`: Your plan row.
- `mobile/assets/fonts/InterTight-Regular.ttf`, `InterTight-OFL.txt`, `mobile/assets/textures/grain.png`, `mobile/pubspec.yaml`: supplied assets, registration and build172.
- `mobile/test/founding_access_test.dart`, `mobile/test/plans_page_test.dart`, `mobile/integration_test/founding_access_audit_test.dart`: lifecycle/layout/regression verification.
- `docs/founding-access/`, `.agents/ACTIVE_WORK.md`, `.agents/CURRENT_STATE.md`: supplied reference, screenshots, implementation and release state.

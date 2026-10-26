# Simpler mobile context directories - October 17, 2026

The supporting entry screen now contains a compact workspace selector and one
inventory list. Organizations have a separate directory. People, settings, tasks,
files and activity remain accessible through Workspace options. The opened
inventory dashboard, Scan, Ask, Spaces, auth and onboarding are unchanged.

The workspace picker lists Personal and actual workspaces only. A workspace's
parent organization is a subtitle, not an adjacent selectable organization row.
The organization directory still supports creation, membership and selecting its
workspaces through the existing APIs. No records are renamed or merged by name.

## Deletion behavior

Inventory, workspace and organization confirmations remain mounted during the
request. Failed requests retain the entered name and explicit inventory purge
choice. Busy controls prevent duplicate submissions; no destructive request is
automatically retried. Inventory/organization deletion validates the returned ID
and success receipt. Workspace removal uses the existing deleted receipt.
Caches clear only after confirmed success. Removing the current resource returns
to its parent without reloading the removed resource. A separate refresh failure
does not misreport a completed mutation as a failed deletion.

Existing server guards are preserved: inventory content deletion is explicit,
workspace deletion retains inventories for their owners in Personal, and an
organization must have no remaining workspaces. Permissions are unchanged.

## Evidence

- Full local Flutter suite and required coverage run: 549 passed. Final analysis:
  clean. Coverage artifact: mobile/coverage/lcov.info (generated, not committed).
  Automatic CI used newer Flutter 3.47.7 and exposed an existing settings
  ListTile ink-layer assertion. The Memory row now has a transparent Material
  owner; its appearance/content are unchanged. All 32 profile tests and analysis
  pass after that narrow compatibility change. All five automatic CI jobs pass
  on runtime fed141e (39074361909) and compatibility parent bac43eb
  (39074476105).
- New regressions cover preserved name/purge state after 409, 501 and 502,
  no automatic retry or false success, and exact-name organization deletion.
  Existing workspace return, navigation, creation, roles and large-text cases pass.
- Focused unchanged backend deletion tests: 29 passed.
- Production DELETE routes answered 401 without authentication. Today's journal
  contained successful deletions and protected 409 conflicts, but no matching
  deletion-specific 501/502. The user's historical transient error was not
  reproduced; this change does not claim to eliminate every upstream outage.
- A fresh private production schema/data copy was restored into a network-none
  PostgreSQL 17 container. Twenty-one copied-record function cases passed with
  rollback: 8 empty-only inventory attempts (2 expected 23514 blocks), 8 purges,
  2 workspace removals, 3 organization attempts (2 expected 23503 blocks).
  Restoration used no-owner/no-privileges and accepted only the three expected
  precreated-schema notices; this rehearses runtime constraints, not grant replay.
  No production records were changed and no file/network cleanup could run.
  Private server evidence: /home/ubuntu/findez-deletion-audit-20261017-checked/.
- iPhone 16e/iOS 26.2 native preview: inventory list, workspace picker, separate
  organization directory, all three deletion controls, exact-name enablement,
  purge warning and Cancel visually reviewed. Images are in out/.
  The preview uses a separate com.findez.onboarding.qa bundle and in-memory API;
  it never replaces the signed-in production app or proves live synchronization.
- Simulator compilation initially ran out of disk space; clearing regenerable
  caches allowed the native build to pass. Previous beta79 IPA/archive preserved.
- The first beta80 archive was rejected by Apple because cached simulator
  objective_c.framework entered the device export. The required platform check
  was missed on that first attempt. The rejected package/receipt are preserved
  privately. The clean rebuild verifies all 31 executables in both the archive
  and exported IPA as iOS device binaries, with strict archive signatures. The
  rejected simulator executable is a verified negative check. A disk-limited
  preservation attempt was resumed using byte-identical IPA verification and
  an atomically replaced, CRC-checked archive ZIP.

Real-account deletion on the final phone binary remains manual acceptance; no
customer records were deleted for QA. No new physical/performance claim is made.

## Files and delivery

Directory runtime changes are confined to mobile/lib/features/workspaces/:
workspace_home.dart, hierarchy_page.dart, inventory_actions.dart and
workspace_actions.dart. profile/profile_page.dart adds only a transparent
Material around the settings Memory row for newer Flutter compatibility.
Tests changed in workspace_home_test.dart,
organization_place_flow_test.dart, inventory_directory_actions_test.dart and
workspace_deletion_test.dart. tool/place_preview.dart is a network-free debug
entry point and is never included by lib/main.dart. pubspec.yaml increments to
1.0.8+80. This report, review images and .agents state/decision files record QA.

Branch: fix/mobile-context-directory-20261017, based on 75db5c5.
Its separate compatibility parent (PR 96) uses the installed AnyIO runner for crop tests,
fixing clean-CI collection without adding a dependency. The full backend suite
passes 817 tests and 10 subtests with pytest-asyncio disabled. See
docs/plans/crop-test-runner.md and its separate PR.
No backend deployment or production migration is needed. Candidate migration 053
remains separately pending. The signed release must use lib/main.dart and the
existing production defines. Apple acknowledged TestFlight 1.0.8 (80), runtime
fed141eab744450c5af2ed97ab5018356517f8c8, delivery
30ec26e0-4246-4085-b0cc-42b22bceeb1b. Final IPA SHA-256:
dde1ebd97c5d1c812c5990aa2094b1de7b18a9189969c3614d7d21e00c38b97e.
Private archive, IPA, native verification and Apple receipt are preserved in
Documents/FindEZ/AppStore/1.0.8-build80. Processing and tester availability remain
unverified and were not polled. Mobile review is PR 95; compatibility is PR 96.
The post-runtime parent alignment changes documentation only; no manual
regression checks were repeated after the successful release build.
Rollback is a later mobile build reverting these scoped UI changes; server
deletion safeguards stay in place.

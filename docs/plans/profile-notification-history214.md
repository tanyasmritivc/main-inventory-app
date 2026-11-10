# Profile notifications and Settings history

The main Ask home header now contains the organization selector and profile
avatar. Chat history is reached through the avatar's Settings sheet. Notifications
remain in that sheet. Other page toolbars and chat/scan operations are unchanged.

The avatar uses a small red dot at its upper-right corner whenever the existing
account-level unread count is positive. It refreshes on app resume, incoming push,
the existing 30-second foreground poll, and after Settings closes. Opening
Settings alone does not mark anything read. VoiceOver exposes the unread count.
The history action dismisses Settings before opening the existing scoped history.

Validation and delivery:

. 34 focused notification, native Settings callback, and world-shell checks pass.
. All 1,370 mobile tests pass with one existing skip. Static analysis is clean.
. Native simulator checks passed in both themes, including Settings to history,
  conversation selection, inbox access and mark-all-read clearing the avatar dot.
. All five exact-source CI jobs passed in run42763110311.
. Apple accepted signed TestFlight 1.1.3 (214), delivery
  `d6913e2c-9087-4b4d-b0c0-fc90c642fb86`. Processing is pending and tester
  availability is unverified. Physical device acceptance remains pending.
. Apple validation reported 1.1.2 already approved and closed, so this update
  uses 1.1.3. Public availability was not checked.
. Release receipt: `docs/plans/mobile214-release.json`.
. No backend, web, database, push-policy or existing App Review submission change.

Separate bulk scan investigation:

Two live tests of the existing crowded-parts fixture completed at 241.6 and 240.9
seconds, returning editable drafts with 99 and 70 detected regions respectively.
Unknown identities remained explicit (46 and 36). The second test used the iPhone
2048-pixel upload size and mirrored response protocol; its stream received a final
draft and never went more than 10 seconds without bytes. These are API protocol
tests, not physical iPhone acceptance, and do not reproduce the user's failure.
Temporary QA accounts and images were removed. No inventory items were saved.
The exact device error/background state remains requested. No timeout fix is
claimed and no production runtime was changed for that investigation.

# Native organization and invitation polish

The organization dropdown now uses a UIKit popover with system text, initials,
selection checks and the existing organization, Personal, creation and invitation
actions. It sizes to its content and scrolls within the available screen height.
The main heading is brighter in dark mode with its existing diagonal shine.
Composer hints use explicit 14-point gray system text, frame-based reveal at
32 milliseconds per character and a softer reveal edge. Actual input is unchanged.

An explicit sign-in requests freshly verified Founders Access independently of
campaign suppression. The welcome does not wait for directory or profile loading,
but still waits until any OS notification permission prompt closes and no active
workflow or modal would be covered. The welcome has no timeout, close button or
confirmation button. Swipe down, tap outside or accessibility dismissal closes it.
Manual plan viewing keeps its existing controls. Non-pilot and switched accounts
cannot receive an invented Founders Access claim. Offline access retries are
throttled to 15 seconds. The user explicitly requested this sign-in welcome,
superseding the old server campaign frequency for this welcome only.

Notification invitations now open an expanded UIKit detail sheet. It shows sender,
resource, role, status and a localized expiry date. Existing preview, explicit
accept/decline, account guards, expiry checks and destination validation remain.
The notification feed uses an envelope icon for invitations. Native text uses
Apple system typography; app-owned Flutter text already uses CupertinoSystemText.

Validation: 1,375 Flutter tests passed with one existing skip. Focused tests cover
native menu choices and selection, invitation preview and explicit acceptance,
sign-in welcome persistence, gesture dismissal and account eligibility. The full
suite was repeated after native visual corrections. Initial new-test failure was
a timezone assumption in the fixture, now localized. Static formatting issues
were corrected. Native visual inspection used a network-free disposable iPhone
16e simulator on iOS26.2, not customer accounts. Physical device OAuth, VoiceOver,
push delivery and final TestFlight acceptance remain unverified.

Build 1.1.3 (215) is being prepared. Public App Store submission is unchanged.
No backend, database, web, extraction or chat request behavior changes.

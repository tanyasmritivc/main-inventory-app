# Phone web sign-in verification

Runtime: 2db58539bdb477c3cd272619d9ba9fe71dbbf673. PR262.

Before the fix, iPhone 17 Pro simulator Safari (iOS 26.5) opened Google after one tap on a fully loaded sign-in page. Returning with Safari Back restored disabled Google, Apple and email controls; the email button misleadingly read Signing in. Field focus also zoomed the page because inputs were 13px. This reproduces concrete mobile problems, but does not prove every reported intermittent first-tap failure has the same cause.

The shared web auth form now shows the chosen provider's Opening state immediately, prevents duplicate synchronous requests, restores controls on persisted pageshow, ignores obsolete results, and reads email/password from FormData for autofill. Touch-device fields are 16px and controls are at least 44px tall. Existing provider/callback configuration and app routes are preserved.

Validation: 639 tests in 88 suites; 20 final auth tests; TypeScript; zero changed-file lint warnings. Full lint baseline has 52 existing warnings after the new warning was corrected. Production build and 27 staged route/asset checks passed. All five CI jobs passed (40624592288). Published with 27 live route/asset checks. iPhone Safari verified single-tap Google handoff, Google Back recovery, immediate Apple feedback and Apple Back recovery, and email focus without additional zoom. No authenticated account sign-in was completed. Apple initially returned Invalid web redirect url. After the user signed into Apple Developer, inspection showed only findez.ai and the obsolete https://api.findez.ai/auth/apple/callback registered. Added the existing production authentication domain findez-db.openstack.ftctools.com and https://findez-db.openstack.ftctools.com/auth/v1/callback to Services ID com.findez.app.siwa, preserving the previous entries and primary App ID. Saved registration; a fresh single tap in iPhone Safari now reaches Apple’s Sign in to FindEZ form. No auth-server configuration, key, secret or native capability changed. Saved-password autofill reached the device passcode prompt; no credential was entered and end-to-end account authentication is not claimed.

No API/schema/mobile changes. Two old webpack caches were removed for build space; published build artifacts and rollback source were preserved.

Apple configuration reference: https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web

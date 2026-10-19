# Final mobile delivery — October 18, 2026

Build **1.0.8 (95)**, source `ca5c195`, is installed on the connected iPhone. Apple acknowledged upload `375271f5-080e-429c-9054-8b42518280df`. IPA SHA256: `fac8ef9f74aed838ab89c0b860f5b7de84e2e8bc78353eda7263ceb7ff8854fe`. Signed IPA/archive and receipts are preserved in `Documents/FindEZ/AppStore/1.0.8-build95`. Processing/tester availability were not polled; public App Store submission is held. This supersedes build 94.

## Corrections and verification

Build 95 assigns the native notification-center delegate at application startup. The previous build could register and receive APNs acceptance without correctly handling notification presentation. With Focus off, the user directly confirmed: “Notification arrived.” Camera capture, barcode scanning and Ask microphone input were confirmed by the user on build 94; build 95 changes the native notification startup only.

Plans and paid-plan promotion remain hidden. Native plugin/push registration uses Flutter's implicit-engine callback for UIScene. Privacy/Terms prefer the system browser view with external fallback. Failed support-email launches show the contact address. The share extension inherits Flutter version/build settings instead of carrying the stale 66 value. Native Apple nonce/deletion handling, share-framework privacy manifests and restock loading corrections remain included.

Validation: 659 full Flutter tests; separately enabled production configuration gate; 42 focused legal/profile checks and 5 notification checks; clean analysis. All five final CI gates `39188238121` pass. Archive/export each contain 31 verified iOS device executables; strict signing passes. The 24 privacy manifests, including both share-handler frameworks, purpose strings, matching app/extension build 95, HTTPS endpoints and anonymous client configuration were verified. Apple validation and upload acknowledgment pass.

Physical passes: exact archive install/launch, retained login, QA inventory, Plans hidden, Privacy/Terms opening, support-mail fallback, Memory/Documents/Lent items/Notifications screens. With explicit approval, iOS notification permission/registration and APNs acceptance pass; visible notification arrival now passes too. Warm/cold Safari invitation handoff reaches the app and rejects an invalid code without granting membership. Camera/barcode/microphone happy paths are user-confirmed. Customer Workshop records were untouched; the separate Release QA inventory is retained.

## Remaining acceptance and infrastructure

These are unverified, not passes: camera cancel/denied-permission variants; cold notification tap; fresh Apple/Google login and disposable Apple-account revocation/deletion; fresh password recovery; valid invitation recipient join on the phone; Photos share-extension import; interrupted/offline upload recovery; VoiceOver. Safari's public JPEG share sheet opened, but Mirroring did not advance its horizontal destinations to FindEZ. Unit/backend tests do not replace these physical checks.

Public-launch blockers remain in infrastructure: encrypt the API-to-FIND GPU hop, disable its insecure HTTP override, rotate inference credentials after transport protection, and restrict origin port 8000 to the verified ingress proxy. GPU configuration was preserved under the user's earlier instruction. Auth still has Apple and Google server-side nonce-check bypass flags enabled: the new native Apple nonce is present, but server enforcement requires provider/older-client compatibility testing before a coordinated change. Do not disable flags blindly and risk login failure.

The unsubmitted App Store draft review notes reference build 95. Its previously unset socialMedia age-rating field is now false; all other answers and published metadata were preserved. Privacy labels, remaining age-rating answers and screenshot accuracy still require final owner review. No public submission was made.

Full backend/security evidence and owner checklist: API lane `docs/plans/final-mobile-security-20261018.md` (PR 127). Web fixes: PR 128; mobile: PR 129. No unconditional production-ready signoff.

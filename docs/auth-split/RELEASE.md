# Live auth split design

Deployed on November 11, 2026 to https://findez.ai/signin through the existing self-hosted `findez-web` service. Build and release identity are recorded in `live/deployment.json`.

## Scope

Four runtime files changed:

• `frontend/src/components/site/auth-form.tsx`: presentation classes, brand rendering, and the shared page wrapper.
• `frontend/src/components/site/auth-form.module.css`: scoped dark presentation. Existing light rules remain intact.
• `frontend/src/components/site/auth-split-layout.tsx`: existing Appearance preference and shared layout.
• `frontend/src/components/site/auth-art.tsx`: decorative canvas adapted from the supplied readable source.

Sign-in and sign-up use the same AuthForm and inherit the split layout in dark mode. Forgot password remains the existing action in the sign-in form. Reset password uses a separate component and is unchanged. Embedded AuthForm instances retain their existing layout.

The existing Appearance preference controls the design. Stored dark mode enables it; system mode follows the OS. Light mode and the existing default remain unchanged. Existing Inter and Inter Tight fonts and the existing clove geometry are reused. The plan is called Founders Access, matching the supplied copy.

All authentication handlers, state, validation, provider calls, redirect logic, and error wording are unchanged from the live baseline. The release comparison preserved 593 other frontend files, including environment, configuration, and dependencies. No backend, database, or mobile changes were deployed.

## Deployment and verification

• Production `npm run build -- --webpack` passed, including TypeScript and prerendering. No local preview or extra test suite was run.
• The initial activation automatically rolled back because its health check expected client-rendered text in raw HTML. The corrected health check activated the same build successfully. Both service and public HTTPS sign-in respond successfully.
• Safari responsive views inspected at widths 1440, 860, and 390. Desktop and phone screenshots are in `live/desktop-1440.png` and `live/phone-390.png`. These are genuine Safari captures with its responsive-mode chrome.
• Email focus displays the rose ring. Empty email submission retains native required-field validation. Forgot password and Resend confirmation email retain the existing missing-email message. Sign up opens the existing route and retains all fields and its consent checkbox.
• Google reaches the Google account chooser. Apple opens the native Sign in with Apple sheet. Full credentialed sign-in, callback completion, and delivery of confirmation/reset emails were not exercised. Cancelling the Apple sheet left the existing Opening Apple state until reload; no auth behavior was changed in this design task.
• Safari memory recording ran for 81 seconds with a 1440 by 900 responsive viewport. The visible trace stayed approximately level around 143 to 144 MB, with a reported maximum of 144.02 MB. This is a short page-memory observation, not a long-term leak guarantee. Screenshot: `live/safari-memory.png`.
• Reduced-motion handling and visibility pause are implemented with event listeners and cleanup. Manual reduced-motion emulation and a post-deployment light-mode screenshot were not completed because the user resumed using Safari. The light-mode preservation was reviewed in source.

## Differences from the supplied screenshots

The original Google and Apple icon geometry is retained. Fields remain 16px on touch devices to preserve Safari's existing protection against focus zoom; other fields use the specified 15px. Browser font rasterization and the animation's current frame also vary from the static targets.

## Source baseline

The original commerce checkout was older than the live auth implementation. The delivery branch `design/auth-split-production` uses the existing `copy/photo-scan-timing-web` source baseline, whose AuthForm matches the live source exactly, so its diff contains only presentation changes. Deployment overlaid the four runtime files onto the current live release rather than deploying an older checkout.

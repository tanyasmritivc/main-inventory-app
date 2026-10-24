# Public prompt preview

## Behavior

Submitting the homepage composer morphs its rectangle into a focus-trapped preview
using the existing Radix dialog infrastructure and the Web Animations API. The
presentation reveals description, layout, then exploration; these are local demo
steps, not claimed AI/backend progress. Background landing animation pauses while
open. Reduced motion bypasses morph and staged delay. Closing restores composer
focus; duplicate navigation is guarded and timers/animation are cleaned up.

The preview supports filtering and expandable item details. Save/full-app controls
transition into the existing signup page, where the request is shown. Email and
OAuth callback destinations retain it through onboarding, or existing users can
sign in directly. Completing/skipping setup prefills Ask; it never auto-sends or
creates suggested example stock. Invitation and password-recovery destinations
retain precedence. A bounded 30-minute sessionStorage draft restores words on Back;
blocked/corrupt browser storage does not prevent previewing.

## Scope and limits

- Frontend only; no backend, database, mobile, new dependency or paid model calls.
- Preview parser accepts up to 2,000 characters, explicit digit counts (or a/an),
  named inventory/Space and common location phrases. Shows at most 24 entries.
- Broader prompts use contextual examples with unknown quantities. Unrecognized
  descriptions retain their words and show an empty starter Space. This is not
  general-purpose model understanding, real search, stock verification, BOM
  compatibility checking or photo extraction.
- Save requires authentication and review in the existing Ask workflow. The
  public demo itself is not persisted to the inventory database.
- Query parameters carry the original request through auth, as the landing form
  already intended. Avoid adding analytics that collect prompt URLs. No tokens,
  credentials or frontend-supplied ownership IDs are introduced.
- Chrome may report unused CSS preload advisories around Next route prefetching;
  no hydration/runtime errors were observed in the inspected flow.

## Files

- `landing-v3/StoryA`, `PromptPreview`, `preview.module.css`, `navigation`,
  `LandingV3`, `useScrollProgress`: prompt submission, modal motion, local draft,
  interaction and background pause.
- `lib/landing-preview.ts`: bounded parsing and safe relative auth handoff.
- `site/auth-form`, `preview-handoff.module.css`, onboarding page/component,
  assist page: visible request and continuation through existing auth/setup.
- Four test files cover parser distinctions, quantities, named locations, unsafe
  input, auth destinations, email/OAuth, setup skip/completed paths, cancellation,
  reduced/normal motion, filtering, IME, repeated click and draft recovery.

## Validation

- `npm test -- --runInBand`: 488 passed across 62 suites.
- `npx tsc --noEmit`: passed; final production build also checked TypeScript.
- `npm run lint`: 0 errors, 52 pre-existing warnings, no new warnings.
- `npm run build -- --webpack`: passed with placeholder local Supabase public
  configuration; release also built successfully with preserved server config.
- Chrome UI inspected at 1440x900 and 390x844. Named inventory, Space and counts,
  example project preview, item expansion, filtering, close/edit and signup prompt
  banner verified. Auth account creation uses mocks; no real account was created.

## Manual acceptance

1. At `/`, submit `Create an inventory called Chat QA with a Storage space and add
   10 AA batteries and 2 USB-C cables`. Expect a morph and Chat QA / Storage with
   the two explicit counts, clearly not saved.
2. Filter for batteries, open its details, clear the filter. Edit prompt and
   reopen. Escape closes and returns focus. Background should not scroll while open.
3. Try `Create a space for my robotics project`. Entries must be examples with
   unknown quantities, not verified project stock or compatible substitutes.
4. Try `Where is my drill?` and an unrelated/unrecognized prompt. Neither may claim
   saved results. Blank input should remain in the composer.
5. Choose Sign up to save (or Open full app). Expect a short exit, then signup with
   the original words. Back restores the prompt within the current tab for 30 minutes.
6. With a disposable account, complete email/OAuth signup and setup (or Skip for
   now). Ask should contain the original request ready to review/send. Existing
   account sign-in should do the same. No demo stock should have been created.
7. Enable reduced motion, repeat at 390x844 and desktop, and use keyboard Tab/Escape.
   Expect no morph/delayed reveal; actions and scrolling remain accessible.

## Deployment

Self-hosted `findez-web` only. Candidate overlays must verify touched-file hashes
against Blue Echo runtime and preserve unrelated live files/configuration. Keep
previous release and service drop-in for rollback. No Vercel deployment invoked.

Activated October 24 UTC (October 23 Pacific):

- Runtime commit: `ad13f91515e42f5bfc89a337ff818e50a07cd77e`, PR183.
- All five CI jobs passed: run `40064433580`.
- Live directory: `/home/ubuntu/findez-web-releases/prompt-preview-20261024/frontend`.
- Build ID: `cHXcB07Do-U3qk0tvDwjj`.
- Twelve changed runtime files overlaid after matching their live base hashes;
  357 unrelated files preserved. Two divergent server test files were left intact.
- Twelve candidate/live HTTPS route statuses match the previous release, including
  homepage, auth, public documents, sitemap/robots and authenticated redirect.
- Six favicon/brand assets match exact candidate bytes. Backend PID unchanged.
- Live Chrome 390x844: Chat QA / Storage, AA batteries 10, USB-C cables 2, then
  signup with the complete original prompt verified. No real signup performed.
- Receipt: `/home/ubuntu/findez-web-releases/prompt-preview-20261024/deployment-receipt.json`.
- Previous release: `/home/ubuntu/findez-web-releases/brand-blue-echo-icons-20261023/frontend`.
  To roll back, restore `previous-web-rebuild.conf` from the new release directory
  to `/etc/systemd/system/findez-web.service.d/web-rebuild.conf`, reload systemd and
  restart `findez-web` only. Keep both releases' static chunks for existing tabs.

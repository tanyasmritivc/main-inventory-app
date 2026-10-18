# Build your world: web onboarding

Branch `web-onboarding`, based on the published authenticated-web head `c242920`.
The user subsequently authorized restoring the missing live homepage image, then
explicitly requested pushing and deploying the completed onboarding. This
supersedes the package's original local-only delivery restriction.

## Behavior

Ordinary signup success and email/Google/Apple signup callbacks now target
`/onboarding`. Existing sign-in, provider handlers, form fields, password recovery
and invitation consent destinations retain their current behavior. The protected
route checks authorized organizations/workspaces and account-bound completion
before showing questions. Failed directory reads show retry, not an empty account.

The personal and team paths use the supplied copy, chips, timed selection steps,
explicit name confirmations, Back, skip, persistent answers and SVG world. The SVG
uses a requestAnimationFrame controller with no per-frame React state and stops
redrawing after finite animations settle. Reduced motion draws final geometry.
Route-scoped Geist/Geist Mono and CSS prevent existing global type rules from
overriding this design. Long custom tags fit the panel and expose their full text
in SVG titles.

No data is created before Open my dashboard. The existing accountRequest transport
uses the same four creation operations audited in AUDIT.md. Each receipt is saved
before its dependent call. The personal path creates an owner-only standalone
workspace with program `other`, without changing built-in Personal. Completion
reauthorizes the resulting inventory and opens `/home?inventory=<id>`. Skip only
opens Personal's existing inventory or its directory and marks this account done.

Web Locks serialize setup/skip across tabs. Persisted creation intent and exact
owner/name/parent reconciliation recover lost responses. Explicit rejected writes
can retry. An ambiguous timeout/5xx with no visible resulting record is checked on
retry but never blindly POSTed again. Existing contracts do not provide durable
server idempotency keys; transactional exactly-once behavior after browser storage
loss is outside this web-only change. If another tab/account creates unrelated
workspaces, the eligibility guard prevents a new setup from proceeding.

Workspace creation can seed its own default inventory. If a custom answer exactly
matches that new default's name, onboarding reuses that record to avoid a name
conflict. Other answers create the selected inventory using the existing API.

## Changed files

Runtime:

- `src/components/site/auth-form.tsx`: signup destination only.
- `src/app/onboarding/page.tsx`: verified user, scoped fonts, no-index metadata.
- `src/lib/web-onboarding.ts`: storage, eligibility, API provisioning, locks.
- `src/components/site/onboarding/web-onboarding.tsx`: interactive steps.
- `src/components/site/onboarding/web-onboarding.module.css`: scoped responsive UI.
- `src/components/site/onboarding/world-model.ts`: projected SVG world and motion.

Verification:

- `src/__tests__/auth-signup.test.tsx`: expected post-signup destination.
- `src/__tests__/web-onboarding.test.tsx`: timing, restart/cancellation, typed
  confirmation, reload, skip, existing accounts and read failure.
- `src/__tests__/web-onboarding-data.test.ts`: ordered writes, each-stage retry,
  lost responses, account/parent isolation, default reuse and storage failure.
- This design directory contains the supplied README/PROMPT/reference assets,
  the prerequisite AUDIT.md, this report, local-fixture.mjs and out/*.png evidence.
- `.agents/ACTIVE_WORK.md` and `.agents/CURRENT_STATE.md` record delivery state.

## Validation

- 375 tests across all 48 Jest suites pass.
- TypeScript passes with `tsc --noEmit --incremental false`; the existing local
  incremental cache retained stale missing-peer errors after dependency repair.
- Full source ESLint: 0 errors, 54 pre-existing warnings. All changed files lint
  cleanly. `git diff --check` passes.
- The actual server candidate builds normally with webpack and real production
  configuration/fonts, with no fixtures or replacement fonts.
- Browser QA uses the real Next dev route with a loopback-only synthetic auth/API
  fixture. Personal creation opens its new inventory dashboard. The team path,
  confirmation fields, model and responsive fit were reviewed in Chrome.
- `out/` contains both world recaps at 1920x1080, 1440x900, 1280x620 and 390x844,
  plus phone welcome. Captures can be at device pixel ratio 2; filenames give CSS
  viewport dimensions. The local Next dev badge is absent from production.
- Supplied 1440x900 recap and React recap were inspected together. Geometry,
  palette, hierarchy and copy match the reference; typography uses self-hosted
  Geist. Long names are safely shortened only on model tags.
- A real fresh-account email/OAuth round trip is not claimed. No customer account,
  membership, inventory, photo or database record was created for browser QA.

Local preview (all values are deliberately synthetic, not credentials):

```sh
node design/web-onboarding-a/local-fixture.mjs
NEXT_PUBLIC_SUPABASE_URL=http://localhost:3085 NEXT_PUBLIC_SUPABASE_ANON_KEY=local-onboarding-fixture NEXT_PUBLIC_API_BASE_URL=http://localhost:3085 npm run dev -- --webpack --port 3086 --hostname localhost
```

Open `http://localhost:3085/fixture/enter` for a new disposable synthetic session.
The fixture binds loopback and never contacts external services. It is not part
of the production runtime overlay.

## Release candidate and image repair

The live hero referenced `/images/landing/hero-workbench.jpg`, which returned 404.
The original tracked JPEG on the independent hero-morph branch was intact. With
the user's explicit approval, its exact 450,087 bytes were restored to the active
release and the web service refreshed. The image returns 200 / image/jpeg.
SHA256: `ba9365e2403a700dc4f9ad962fd1f9f8e15cfb6e2cdd07bbd3c9263b9dc39fb8`.

The onboarding candidate is
`/home/ubuntu/findez-web-releases/web-onboarding-20261018/frontend`, copied from
the current active release and overlaid with only the six runtime files above.
A content-hash comparison confirms 296 other src/public files are preserved,
including all independent landing code/assets and the restored JPEG. Receipts
and build log are in its parent directory. Private loopback preview checks pass:
signup 200, image 200 and onboarding 307 to signin with its return path retained.
Activation and final public verification are recorded below after publication.

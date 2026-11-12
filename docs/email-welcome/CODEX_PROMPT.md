# Codex prompt: send the welcome email when someone signs up

Unzip this folder into the repo at `docs/email-welcome/`.

Before pasting, fill in these two lines in the prompt:
- **`POSTAL_ADDRESS`**: AI Robots Inc.'s mailing address, for the footer.
- **`TEST_EMAIL`**: your own inbox, for the test send.

Then paste everything below the line into Codex from the repo root.

---

Add a welcome email that goes out automatically, once, to every new FindEZ user right after they sign up. The design in `docs/email-welcome/` is final. **Build it, send one test to me, then stop and wait for me before turning it on in production.**

- **POSTAL_ADDRESS:** `________________________________`
- **TEST_EMAIL:** `________________________________`

## What's in the folder

- **`email-template.html`:** the finished email.
  - It is table-based, with inline styles, and built for Gmail, Apple Mail, iOS Mail and Outlook.
  - It switches between light and dark mode by itself. Keep the dark-mode CSS and the light and dark logo pair.
  - Keep the layout, copy and styles exactly as they are.
- **`email.txt`:** the plain-text version. Send it alongside the HTML.
- **`assets/`:** keep these exactly as they are, with no re-encoding or resizing:
  - `logo-light.png`, `logo-dark.png`
  - `welcome-hero.gif`
  - `start-snap.png`, `start-ask.png`, `start-cad.png`
  - `mark.png`
- **`preview/`:** how the finished email must look.
  - `preview-light.html` and `preview-dark.html` force each mode.
  - The `.png` files are screenshots, desktop and phone.
- **`findez-welcome-email-preview.html`:** the same email with the images built in, so it opens anywhere.

## Placeholders

| Placeholder | Value |
|---|---|
| `{{ASSET_BASE}}` | `https://www.findez.ai/email/welcome` |
| `{{OPEN_URL}}` | `https://www.findez.ai/signin`. If the web app has a signed-in home route that already sends signed-out visitors to sign-in, use that instead and tell me. |
| `{{CAD_URL}}` | `https://www.findez.ai/cad-intelligence` if that page is live. If not, `https://www.findez.ai/docs/cad`. Tell me which. |
| `{{UNSUBSCRIBE_URL}}` | The provider's own unsubscribe or preferences merge tag. If the provider has none, use the app's email or account settings page. If neither exists, tell me and leave the "Email preferences" link out. |
| `{{POSTAL_ADDRESS}}` | The address above. |

All other links are already in the template (App Store, Discord, Instagram, Privacy). Keep them.

## Steps

1. **Find the email setup.** Look for the provider the project already uses: Resend, Postmark, SendGrid, Supabase or SMTP.
   - Tell me the provider and the sender address.
   - If there is none, stop and tell me what's needed. Don't sign up for anything.
2. **Find where sign-up completes.** It could be the FastAPI sign-up route, a Supabase Auth hook or webhook, or a Next.js route.
   - Pick the one place every new account passes through, web and iPhone alike.
   - If the app requires email confirmation, send after the email is confirmed. Otherwise send right after the account is created.
   - Tell me which place you picked and why.
3. **Host the images.** Put the seven images in the web app at `public/email/welcome/`.
   - Deploy them to the live self-hosted site the way the repo already deploys it. **Never use Vercel**, and never make a copy of the site.
   - Confirm each image URL loads publicly.
4. **Build the email.** Fill in the placeholders and save the results as:
   - `emails/welcome.html`;
   - `emails/welcome.txt`.

   **Settings:**
   - **Subject:** "Welcome to FindEZ"
   - **Preheader:** already in the HTML.
   - **From:** the existing sender address.
   - **Reply-to:** `info@findez.ai`.
5. **Wire up the send.**
   - Send once per user, never twice. Use what already exists to remember that the email went out: a provider idempotency key on the user id, or an existing user field.
   - If you need to store it, you may add one nullable `welcome_email_sent_at` column, or one small table, in a new additive migration. Keep RLS enabled on anything you add. Don't change or delete existing data, columns or policies.
   - A failed send must never block or fail the sign-up. Log the error, without the user's email address, and move on.
   - Each email goes to one person. Never put other users in To, CC or BCC.
6. **Send one test to TEST_EMAIL only**, using the real template and settings.
7. **Stop.** Tell me the test was sent and what you changed. **Then wait for me to reply "turn it on".**
8. **After I reply "turn it on":** deploy.
   - The website goes to the live self-hosted server, as in step 3. Never Vercel.
   - The backend, if you changed it, deploys through the pipeline it already uses. Don't set up new hosting.
   - Then confirm with one real sign-up using a test account you create for this, and report the result.

## Rules

- **New sign-ups only.** Never send this email to existing users, and don't backfill.
- **Founders Access:** the email says new users are on Founders Access and that every feature is free. If the app gives new sign-ups a different plan, or calls it "Founding Access", stop and tell me before sending the test. Don't change the copy yourself.
- **Don't change:**
  - the app's screens, the website pages, the sign-in and sign-up UI, or the mobile app;
  - auth settings, env and config files.
  - **Allowed changes:**
    - the `emails/` files;
    - the images in `public/email/welcome/`;
    - the one send hook in the sign-up path, and a small helper for it;
    - the one optional additive migration described above.
- **No new packages** unless the existing provider's SDK is already a dependency.
- **No em or en dashes** in anything you write, including commit messages.
- **Credentials:** never create, print, log, commit or ask for API keys, tokens or passwords. Use the ones already configured. If something is missing, stop and tell me exactly what.

## Report

- the provider and sender address;
- where the send happens (file and function) and when it fires;
- how a double send is prevented, and any migration you added;
- the public image URLs, and the `OPEN_URL`, `CAD_URL` and unsubscribe link you used;
- the test send result;
- after "turn it on": how each part was deployed, confirmation that nothing went to Vercel, and the result of the test sign-up;
- the output of `git diff --name-only`.

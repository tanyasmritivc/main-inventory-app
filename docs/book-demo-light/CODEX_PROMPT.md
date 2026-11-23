# Codex prompt: switch the live Book a Demo page to light mode and deploy it directly (web only)

Unzip this folder into the repo at `docs/book-demo-light/`. Then paste everything below the line into Codex from the repo root.

---

**SWITCH THE LIVE BOOK A DEMO PAGE TO LIGHT MODE, INCLUDING ITS HEADER AND FOOTER, AND DEPLOY IT. DO NOT MAKE A VERCEL COPY.**

- No Vercel deployment, no Vercel preview, no Render, no local copy, no staging copy.
- The only deploy target is the self-hosted production server for findez.ai.
- If the repo's deploy scripts or config point at Vercel, don't use them: find the self-hosted deploy path. If you can't find it, stop and tell me, and don't deploy anywhere else.

WEB (NEXT.JS) ONLY. The Book a Demo page you just built from `docs/book-demo-v3/` is live and dark. **The whole page must be light: the header, the content and the footer.** Every other page on findez.ai stays exactly as it is.

## WHAT CHANGES

**Colours only.** Layout, spacing, fonts, copy, the form, the submission, the cards, the 4-second rotation and all behaviour stay exactly as they are now.

- **Don't change any copy.** The live page's wording stays as it is, even where it differs from the prototype.
- `docs/book-demo-light/prototype/findez-book-demo-light.html` and `screens/` show the target. Match the colours, not the prototype's wording.

## HEADER AND FOOTER: A LIGHT VARIANT, ONLY ON THIS PAGE

- **Keep using the site's real shared header and footer components.** Don't copy or rebuild them, and don't port the ones in the prototype.
- **Add a light variant to them,** for example a `theme="light"` prop. The default stays dark, so every other page looks exactly the same as today.
- **Use the light variant only on the Book a Demo page.**
- Same links, same order, same sizes, same Community dropdown. Only the colours change.
- **Check after the change** that the home page, Solutions, CAD Intelligence, Founders Access, Pricing and Research still show the dark header and footer.

| Part | Light value |
|---|---|
| Header background | `#FFFFFF`, 1px bottom line `#E6E6EA` |
| Logo and "FindEZ AI" | ink `#0A0A0B` |
| Nav links | `#5E5F66`, `#0A0A0B` on hover |
| Sign in | `#5E5F66` |
| Download pill | `#F2F3F5` background, `#0A0A0B` text |
| Book a Demo pill | `#0A0A0B` background, `#FFFFFF` text |
| Community dropdown panel | white, 1px `#E6E6EA` line, `#0A0A0B` text |
| Footer background | `#FFFFFF`, 1px top line `#E6E6EA` |
| Footer column headings and © line | `#9A9AA2` |
| Footer links and tagline | `#5E5F66`, `#0A0A0B` on hover |
| Footer divider | `#E6E6EA` |

## PAGE CONTENT COLOURS

| Part | Light value |
|---|---|
| Page background (around the frame) | `#F7F7F8` |
| Frame | `#FFFFFF`, 1px `#E6E6EA` line |
| Divider under the headline | `#E6E6EA` |
| Headline and labels | `#0A0A0B` |
| Paragraph and thank-you text | `#5E5F66` |
| "(optional)" | `#9A9AA2` |
| Required asterisk | `#B45309` |
| Fields | `#F2F3F5` background, 1px `#E6E6EA` line, `#0A0A0B` text, `#9A9AA2` placeholder |
| Field on hover | line `#D4D4DA` |
| Field on focus | white background, `#0A0A0B` line |
| Choice chip, off | white, 1px `#E6E6EA` line, `#0A0A0B` text |
| Choice chip, on | `#0A0A0B` with white text |
| "Request a demo →" | `#0A0A0B` with white text |
| Error line | `#B42318` |
| Thank-you check tile | `#0A0A0B` with white tick |
| "Back to findez.ai" | `#F2F3F5` with `#0A0A0B` text |
| Right panel | `#F2F3F5`, 1px `#E6E6EA` line between the columns (top line when stacked) |
| Card | `#FFFFFF`, 1px `#E6E6EA` line; inner divider `#ECECEF` |
| Card mono label | `#5E5F66` |
| "… ASKS" label | `#9A9AA2` |
| Card answer | `#5E5F66` |
| Tab, off | white, 1px `#E6E6EA` line, `#5E5F66` text |
| Tab, on | `#0A0A0B` with white text |
| Focus rings | `#0A0A0B` |

Drawing panels:

- **Robotics (blush), Hardware (maroon) and Workshops (Glow on ink):** stay as they are.
- **Labs:** changes to `#E4E6EA` with ink `#0A0A0B` lines.

## RULES

- **Don't touch:** the backend (FastAPI or any Python), Supabase, auth, env and config files, the mobile app, or any other page's look.
- **No new packages.** No em or en dashes. No CSS `filter: blur` or `backdrop-filter`. No numbered labels.
- **Edit in place.** Don't make a copy, a duplicate route, a preview page or a feature flag, and don't set up a local preview.
- Only run what the deploy needs (install, lint, build). If the build fails, fix it and continue. Never deploy a broken build.
- **Credentials:** never create, print, log, commit or ask for passwords, keys or tokens. If deploy access or any secret is missing, stop and tell me exactly what is missing.

## After deploying

1. Open the live Book a Demo page at 1440×900 and at 390 wide, and compare it with `screens/`. Everything, header and footer included, should be light.
2. Check that:
   - the cards still change every 4 seconds and the tabs work;
   - the form and the thank-you state look like `screens/desktop/06` to `08`;
   - the phone menu and the Community dropdown are readable in light.
3. Open the home page and one other page and confirm their header and footer are still dark.
4. Don't submit the form with fake details if that sends an email or saves a lead.

## Report back

- How you added the light variant (the prop name) and that only the Book a Demo page uses it.
- The files you changed.
- How you deployed, and confirmation that nothing went to Vercel or Render.
- One desktop and one phone screenshot of the live page, plus a screenshot of the home page header showing it is still dark.

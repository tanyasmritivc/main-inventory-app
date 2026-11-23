# Codex prompt: Book a Demo page in light mode with the new form questions, deployed directly (web only)

Unzip this folder into the repo at `docs/book-demo-light/`. Then paste everything below the line into Codex from the repo root.

This replaces the earlier light-mode-only prompt. Run this one instead.

---

**SWITCH THE LIVE BOOK A DEMO PAGE TO LIGHT MODE (HEADER AND FOOTER INCLUDED), ADD THE NEW FORM QUESTIONS, AND DEPLOY IT. DO NOT MAKE A VERCEL COPY.**

- No Vercel deployment, no Vercel preview, no Render, no local copy, no staging copy.
- The only deploy target is the self-hosted production server for findez.ai.
- If the repo's deploy scripts or config point at Vercel, don't use them: find the self-hosted deploy path. If you can't find it, stop and tell me, and don't deploy anywhere else.

WEB (NEXT.JS) ONLY. The Book a Demo page you just built from `docs/book-demo-v3/` is live and dark. Two changes:

1. **The whole page must be light:** the header, the content and the footer. Every other page on findez.ai stays exactly as it is.
2. **The form gets more questions** (listed below).

## WHAT CHANGES

**Colours and the form fields.** Layout, spacing, fonts, the cards, the 4-second rotation and all other behaviour stay exactly as they are now.

- **Don't change any other copy.** The live page's existing wording stays as it is, even where it differs from the prototype (for example "we will be in touch").
- `docs/book-demo-light/prototype/findez-book-demo-light.html` and `screens/` show the target. Match the colours and the new fields, not the prototype's other wording.

## THE FORM QUESTIONS

Use this order, labels and options exactly.

**Rows:** pairs share a row on desktop and stack under 560px.

| Row | Field | Required | Type and options |
|---|---|---|---|
| Row 1 | Full name | Yes | Text, placeholder "Alex Chen" |
| Row 1 | Work email | Yes | Email, placeholder "alex@yourteam.org" |
| Row 2 | Company or organization | Yes | Text, placeholder "Your team, lab or company" |
| Row 2 | Job title or role | Yes | Text, placeholder "e.g. Build lead" |
| Row 3 | What best describes your organization? | Yes | Dropdown: Robotics team, Robotics company, Hardware startup, Engineering or manufacturing company, University or research lab, Makerspace or workshop, School, Other |
| Row 3 | Team size (optional) | No | Dropdown: 1 to 10, 11 to 50, 51 to 200, 201 to 1,000, 1,000+ |
| Full width | How did you hear about FindEZ? | Yes | Open text box, placeholder "e.g. Instagram, a friend, a competition" |
| Full width | What would you like to explore? (optional) | No | The existing multi-select chips plus a new **Other** chip. When Other is on, show a text box under the chips: "Tell us what else you'd like to see". |
| Full width | Which CAD software does your team use? (optional) | No | Dropdown: Autodesk Fusion, Onshape, SolidWorks, Other, We don't use CAD |
| Full width | What are you trying to solve? (optional) | No | Multi-line text box, about 4 rows, resizable, placeholder "For example: we keep rebuying parts we already have, or we want to check a Fusion assembly before ordering." |

**Field rules:**

- **Required marker:** required fields show the amber asterisk. Optional fields show "(optional)" in grey after the label.
- **Dropdowns:**
  - Same field style as the inputs: `#F2F3F5` fill, 1px `#E6E6EA` line, 54px tall, a small grey chevron on the right.
  - No native browser styling (`appearance: none`).
  - First option "Select".
- **Validation:** if any required field is empty, show one line above the button: "Please complete the required fields." Keep the existing work email check.
- **Submission:** send every new answer through the **same submission the form uses today**, alongside the existing fields.
  - If the answers end up in an email or a web-side handler, include all of them there.
  - **If saving the new fields would need a backend (FastAPI) or Supabase change, don't make that change.** Send what the current handler accepts, then stop and tell me exactly which fields aren't stored and what change would be needed.

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
| Fields, dropdowns and the text box | `#F2F3F5` background, 1px `#E6E6EA` line, `#0A0A0B` text, `#9A9AA2` placeholder |
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
   - all the new fields show in the right order, the required ones block submit, and the Other chip shows its text box;
   - the cards still change every 4 seconds and the tabs work;
   - the form and the thank-you state look like `screens/desktop/06` to `08`;
   - the phone menu and the Community dropdown are readable in light.
3. Open the home page and one other page and confirm their header and footer are still dark.
4. Don't submit the form with fake details if that sends an email or saves a lead.

## Report back

- How the form submits now, which new answers are included, and anything that couldn't be stored without a backend change.
- How you added the light variant (the prop name) and that only the Book a Demo page uses it.
- The files you changed.
- How you deployed, and confirmation that nothing went to Vercel or Render.
- One desktop and one phone screenshot of the live page, plus a screenshot of the home page header showing it is still dark.

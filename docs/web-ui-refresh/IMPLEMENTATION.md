# Web UI refresh delivery

Branch: `feat/web-ui-refresh`. Baseline: `a2309b3`. Implementation: `2e16bd0`. Deployed on explicit user request on November 4, 2026 (November 5 UTC); branch is not merged. See [deployment receipt](deployment-receipt.json). The production overlay preserves the current release rather than replacing it with the branch checkout.

The external `CODEX_PROMPT_WEB-4.md` is preserved here as [CODEX_PROMPT_WEB.md](CODEX_PROMPT_WEB.md). The supplied HTML and eleven reference screens are included unchanged as visual references. Runtime changes are limited to the Next.js visual layer and the four approved additions. No backend, mobile, database, API implementation, dependency, auth or permission changes were made.

## Presentation

The authenticated app uses the supplied light tokens, a 266px sidebar, a 66px top bar, Inter body type, and the existing Inter Tight face for headings. Home uses the 52px headline and 710px composer, subtle shine and edge motion, and staggered entrances. Dark mode retains the same structure; Light is the default and explicit System and Dark choices survive reloads. Reduced motion disables the added animation.

Spaces and Workspaces use the four exact smooth gradients with stable existing palette assignments. Grain was removed from product artwork and Founding Access. Existing inventory actions remain individually available; the optional combined Add items menu was not introduced. Category filters use segmented styling. Tables preserve their columns and rows, and existing item details render in a right-side panel. Existing contextual chat, tool cards, settings, plan surfaces and authentication receive matching styling. The public marketing site was left unchanged.

## Four approved additions

| Addition | Existing action or data used | Deliberate omissions |
|---|---|---|
| Founding Access banner | Existing `FoundingContext` account eligibility and `openPlan`; localStorage remembers dismissal with a storage-error session fallback | No billing, entitlement or account requests added. The existing provider treats signed-in accounts as Founding Access. |
| Quick start | Photo calls `chooseSource("auto_extract")`; sheet calls `chooseSource("spreadsheet")`; Find drafts `Where are the ` and focuses the existing textarea; Running low drafts and submits `What is running low?` through the existing form | No new scan, import, AI or navigation implementation. Existing unavailable/account guards retained. |
| Typing placeholder | Decorative hint in the empty organization home composer; focus stops it, text suppresses it, reduced motion leaves the static hint | No contextual-chat or saved-conversation placeholder animation. |
| Space info line | Already-loaded item quantities and `created_at`, existing `needsBuying` restock logic, and the loaded Space creation date for empty Spaces | Organization-level Space cards load counts but not item quantities, dates or restock entries. Those extra values are omitted there instead of fetching them. |

Prototype-only sample inventories, answer content, hard-coded counts, sample item fields and demonstration interactions were not copied into the application. Existing subtitles, copy, actions and navigation were preserved except for the expressly listed filler removals. There are no new routes in the implementation.

## Controls and data preservation

- [Before controls](controls-before.json): 1,056 JSX control declarations captured before editing.
- [After controls](controls-after.json): 1,059 declarations. [Comparison](controls-comparison.json) finds **zero existing declarations removed or changed**. The three added declarations are two banner buttons and one mapped Quick start button rendering four cards. Placeholder and metadata additions contain no controls.
- This AST inventory compares control kinds, destinations, event handlers, disabled conditions and input attributes. Mapped declarations represent multiple runtime controls; this is not a count of rendered buttons. The snapshots cover non-test frontend TSX sources.
- [Source data contract audit](data-contract-audit.json) confirms unchanged visible-item filtering/sorting, table column construction/order, grid definitions and inventory request expressions. `item-details.tsx`, `api.ts` and `ask-stream.ts` are byte-for-byte unchanged.
- [Browser data comparison](browser-data-comparison.json) confirms exact matching table columns, row values and action labels between the baseline inventory component and the refreshed component, using the same local spreadsheet and photo fixtures. The baseline component was loaded only in an external QA copy, never added to the product branch.
- Spreadsheet fixture: `PART # / ITEM`, `DESCRIPTION`, `CATEGORY`, `QTY`, `ACTIONS`; PN-F245/8 and PN-F45/43. Original imported field order and vendor part values remain visible in the item panel. The vendor part number is not moved to Where to buy.
- Photo fixture: `PART # / ITEM`, `CATEGORY`, `QTY`, `ACTIONS`; Cordless drill/Tools/1. The existing image branch and source URL are unchanged.

## Validation

| Check | Result |
|---|---|
| `npm run lint` | Pass, zero errors and 52 existing warnings |
| `npm run build -- --webpack` | Pass, including TypeScript and static generation |
| Full Jest before | 449 passed, 70 failed, 519 total |
| Full Jest after | 454 passed, 70 failed, 524 total |
| Failure comparison | Exactly the same 70 pre-existing failing test names; zero new failures |
| Focused refresh, theme and Founding Access tests | 33 passed |
| `git diff --check` | Pass |
| Control and source data audits | Pass |
| Browser table comparison | Both fixtures match exactly |

[Test comparison](test-comparison.json) records the baseline and final failures. The full suite is **not green**; unrelated baseline failures were not changed as part of this visual task. Webpack was used because this workstation's installed `node_modules` is a symlink outside the checkout, which Turbopack does not support here. No dependency files were changed.

Local Chrome checks used synthetic account, organization, inventory and chat responses in a separate, uncommitted QA copy. Product auth and API code were not bypassed or changed in the submitted branch. No production data was written. These checks verify UI wiring and presentation, not live AI quality, OAuth, email delivery or production backend writes.

| Area | Browser checks |
|---|---|
| Shell | All sidebar targets, pin/unpin, organization menu, command menu, notifications, avatar/theme menu and Upgrade popup |
| Home | Send/answer with local SSE response; plus menu; saved history; new conversation; all four Quick start actions; banner popup and persistent dismissal after reload |
| Spaces | Search, refresh, New Space form, opening both Spaces, Browse inventories |
| Space detail | Upload chooser, spreadsheet dialog, barcode dialog, manual-add dialog, actual CSV download, search, category filter, row menu, item panel and contextual Ask |
| Tools | Inventory selector, Earlier chats and all ten card destinations in light and dark mode |
| Workspaces | Refresh, Manage workspaces and opening a workspace |
| Account | People, Organization settings, Profile, plans, Upgrade, explicit Light/Dark/System persistence, sign out to the public landing page and sign-in styling |
| Responsive | 390px and 820px web viewports; two-column Quick start; compact top-bar ordering corrected |

Upload pickers were opened and canceled; camera hardware and real file extraction were not exercised. Creation, deletion, invitation and access-change forms were inspected without committing mutations. The unchanged underlying operations remain covered by their existing source/tests, subject to the baseline failures above. Sign-in retains its existing light-only behavior.

## Changed files

Runtime files:

- `frontend/src/app/interior-tokens.css`, `web-ui-refresh.css`, `layout.tsx`
- `frontend/src/components/founding-access/founding-access.tsx`, `founding-access.module.css`
- `frontend/src/components/site/app-shell.tsx`, `desktop-shell.module.css`, `use-app-theme.tsx`
- `frontend/src/components/site/assist-client.tsx`, `web-refresh-ui.tsx`, `context-chat.module.css`
- `frontend/src/components/site/home-inventory-client.tsx`
- `frontend/src/components/site/world-workspace.tsx`, `world-workspace.module.css`, `world-tools.module.css`
- `frontend/src/lib/riso-palettes.ts` (presentation gradients only)

Validation/documentation: `app-theme.test.tsx`, `founding-access.test.tsx`, new `web-refresh-ui.test.tsx`, `.agents/ACTIVE_WORK.md`, and this reference/evidence directory. No files under backend, mobile or database changed.

## Screenshots

All captures use local synthetic data. The [verification directory](verification/) includes light and dark page captures, menus, panels, every Tools destination, baseline table captures and responsive views.

| Page | Light | Dark |
|---|---|---|
| Home | [Home](verification/01-home-light.png) | [Home](verification/21-home-dark.png) |
| Answer / plus | [Answer](verification/02-answer-light.png), [Plus](verification/03-plus-light.png) | Same existing controls and theme tokens |
| Organization menu | [Menu](verification/05-organization-menu-light.png) | Theme menu checked |
| Spaces | [Spaces](verification/06-spaces-light.png) | [Spaces](verification/22-spaces-dark.png) |
| Spreadsheet Space | [Space](verification/07-space-sheet-light.png) | [Space](verification/23-space-dark.png) |
| Item panel | [Panel](verification/08-item-panel-light.png) | [Panel](verification/24-item-panel-dark.png) |
| Contextual chat | [Chat](verification/09-context-chat-light.png) | Shared dark tokens |
| Photo Space | [Space](verification/10-space-photo-light.png) | Shared dark table tokens |
| Tools | [Tools](verification/11-tools-light.png) | [Tools](verification/25-tools-dark.png) |
| Workspaces | [Workspaces](verification/12-workspaces-light.png) | [Workspaces](verification/36-workspaces-dark.png) |
| Workspace | [Workspace](verification/13-workspace-light.png) | Shared dark tokens |
| People | [People](verification/14-people-light.png) | [People](verification/37-people-dark.png) |
| Organization settings | [Settings](verification/15-organization-settings-light.png) | [Settings](verification/38-organization-settings-dark.png) |
| Profile | [Profile](verification/16-profile-light.png) | [Profile](verification/19-profile-dark.png) |
| Plans | [Plans](verification/17-plans-light.png) | [Plans](verification/20-plans-dark.png) |
| Founding Access / Upgrade | [Founding popup](verification/04-founding-plan-light.png) | [Upgrade](verification/39-upgrade-dark.png) |
| Sign-in | [Sign-in](verification/44-signin-light.png) | Existing light-only route |
| Responsive | [390px and 820px](verification/43-responsive-light.png) | Shared responsive rules |

Additional tool screenshots are named `tool-*-light.png` and `26-capture-dark.png` through `35-inventory-settings-dark.png`.

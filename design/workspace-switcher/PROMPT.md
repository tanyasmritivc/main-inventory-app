# Codex prompt: mobile workspace home and place switcher

Setup: put the `workspace-switcher` folder (this file plus `reference/`) in the repo at `design/workspace-switcher/`. Then paste everything inside the block into Codex.

```
Task: Redesign the mobile "Your world" navigation into a workspace home with a place switcher, and reopen the app in the last place the user was in. Mobile (Flutter) only.

Reference images (the source of truth for the look, iPhone 16e size, 390x844 points at 3x):
- design/workspace-switcher/reference/home-ftc-robots.png   the workspace home on FTC ROBOTS
- design/workspace-switcher/reference/switcher-open.png     the place switcher open, FTC ROBOTS selected
Open both images before writing any UI. Where the text spec and the images disagree, the images win; tell me about the difference in your final message.

Read the current code first: find the "Your world" screen, the organization screen, the workspace screen, the inventory screen, and the providers/services that load organizations, workspaces, inventories, people and roles. Reuse them. Write the UI yourself to match the spec below exactly. Do not copy any code from elsewhere.

DO NOT
- Do not touch backend/, frontend/ (web), Supabase schema or any API. If a count or field below is not already returned by existing calls, hide that piece of text instead of adding an endpoint.
- Do not add icons, illustrations, emoji, gradients or shadows beyond what is specified.
- Do not change the inventory screen, Tasks, Files or Activity screens themselves. Only how you get to them.
- No em dashes or en dashes in copy, code comments or commit messages.

1. FONTS
- Bundle Geist (400, 500, 600) and Geist Mono (500) as assets in pubspec (OFL licensed, from the official Geist release). Do not fetch fonts at runtime.
- Geist is the app font for these screens. Geist Mono is used only for section labels.

2. TOKENS (use these exact values; put them in one theme/tokens file)
- Background #F6F5F3. Card #FFFFFF, radius 14, 1px border #ECEAE6, no shadow. Row separator 1px #F1EFEB.
- Text: primary #111112, secondary #8A8782, dim #6B6965, section label #9A978F.
- Brand orange #E8590C. Dark orange #C2410C. Destructive #B42318.
- Chevron right: 8x14, stroke #C4C1BA, width 1.8, rounded.
- Type:
  - Place title 24 / w600 / letter spacing -0.025em.
  - Row title 16 / w500 / -0.015em.
  - Row subtitle 13 / w400 / #8A8782.
  - Section label: Geist Mono 11 / w500 / uppercase / letter spacing 0.06em / #9A978F.
  - Sheet title 18 / w600.
- Spacing: screen side padding 16, gap between blocks 20, row padding 14 vertical 16 horizontal, row min height 52, every tap target at least 44.

3. SHARED COMPONENTS
- PlaceBadge 34x34, radius 10, first letter of the name, 14 / w600:
  - Organization: fill #E8590C, letter #FFFFFF.
  - Workspace: fill #E3ECFB, letter #2453A8.
  - Personal: fill #DFF1E6, letter #1D6B43.
- RoleTag pill, padding 4x10, 12 / w600, capitalized:
  - Owner: bg #FDE6D8, text #A8380A.
  - Editor: bg #E3ECFB, text #2453A8.
  - Member: bg #ECE8F6, text #4F3F8C.
  - Map any other role to Member styling with its own capitalized name.
- Avatar 30 circle with initial, 13 / w600. Current user: bg #FBE1D2, text #B33F08. Others cycle: blue (#E3ECFB / #2453A8), purple (#ECE8F6 / #4F3F8C), green (#DFF1E6 / #1D6B43).
- CardList: a Card containing rows split by separators.

4. WORKSPACE HOME (replaces "Your world" as the root screen after sign in)
Top bar, left: a tappable place title that opens the switcher.
- Line 1: the organization name, 13 / #6B6965. Hidden for Personal and for workspaces with no organization.
- Line 2: the place name (24 / w600) followed by a chevron down (14x9, stroke #3F3D39, width 2).
- Semantics label: "Switch place. Current: <place> in <organization>".
Top bar, right: a 44px circular search button, white with 1px #E3E0DA border, magnifier stroke #3F3D39. It opens the existing search.
Remove the refresh button. Use pull to refresh instead.

Inventory block:
- If the place has exactly one inventory, show the hero card:
  - Card fill #C2410C, radius 18, padding 20, 14 gap.
  - Row 1: "Inventory" (13 / w600 / #FCD9C4) on the left, "You can edit" or "View only" (13 / #FCD9C4) on the right, from the user's role.
  - Row 2: inventory name, 22 / w600 / white.
  - Row 3: "<n> items" (15 / #FFF1E8) on the left, "Open" pill on the right (white fill, text #A8380A, 15 / w600, padding 8x16).
  - Tapping anywhere on the card opens the inventory.
- If the place has several inventories: a section label "INVENTORIES", then a CardList. Each row shows the name on the left, the item count (16 / w600 / #C2410C) with "items" below it (12 / #6B6965) on the right.
- If there are none: one card with "No inventory yet" and a "Create inventory" button using the existing create flow.

Below it, a CardList with rows: Tasks, Files, People (count on the right, 15 / #6B6965), Activity. Each row has a chevron and opens the existing screen. For Personal, show only the inventory block.
Move "Leave workspace" to the bottom of the People screen: centered destructive text button, 16 / w500 / #B42318, behind the existing confirmation.

5. PLACE SWITCHER (bottom sheet)
- Scrim rgba(17,17,18,0.42). Sheet background #F6F5F3, top radius 22, top edge 150 from the top of the screen, scrollable when the list is long.
- Grab handle 38x5, radius 3, #D4D1CB, centered, 10 from the top.
- Header row: "Switch place" (sheet title style) on the left, a close button on the right (36 circle, fill #ECEAE6, X stroke #3F3D39).
- Personal card: PlaceBadge(Personal) + "Personal" + subtitle "Only you".
- For each organization the user belongs to:
  - Section label row: the organization name (section label style) on the left, "Organization · <Role>" (13 / #8A8782) on the right.
  - Its workspaces in a CardList, each row: PlaceBadge(Workspace) + name + subtitle "<Role> · <n> inventories" + chevron.
- Section label "WORKSPACES" for workspaces that are not in any organization, in a CardList: PlaceBadge(Workspace) + name + RoleTag.
- The current place is shown as its own white card with a 1.5px #E8590C border and an orange check (18x14, stroke #E8590C, width 2.4) instead of the chevron.
- Footer pinned to the bottom of the sheet: two equal outline buttons side by side, "New workspace" and "New organization" (white fill, 1px #E3E0DA border, radius 12, height 46, 14 / w500), using the existing create flows.
- Tapping a place: close the sheet, switch the home to that place, save it (section 6).
- A workspace must appear only once: inside its organization, never also in the standalone list.

6. REOPEN IN THE LAST PLACE
- Save the current place locally every time it changes: { userId, type: "personal" | "workspace", id }. Use shared_preferences (or the storage the app already uses) with the key last_place_<userId>, so two accounts on one phone don't mix.
- On cold start, after auth resolves, open the home on the saved place before the first frame of the home is shown. No flash of another place.
- If the saved workspace no longer exists or the user lost access, fall back to Personal, show a one-line snackbar "That workspace is no longer available", and overwrite the saved value.
- First launch or no saved value: Personal.
- Deep links and notification taps that target a specific workspace win over the saved value, and become the new saved value.
- Sign out clears last_place_<userId>.

7. ACCESSIBILITY
- Every row and button is a real button with a semantics label. Icon-only buttons get labels ("Search", "Close").
- Text contrast at least 4.5:1, except the 24 / w600 title.
- Supports Dynamic Type up to the largest accessibility size without clipping. Rows grow in height.

ACCEPTANCE CRITERIA
1. flutter analyze is clean and existing tests pass.
2. New unit tests for the last-place logic: save on switch; restore on start; fallback when access is lost; deep link override; cleared on sign out; separate per user.
3. On an iPhone 16e simulator, take screenshots of: the home on FTC ROBOTS, the home on Personal, the switcher open with FTC ROBOTS selected, and the People screen with Leave workspace. Save them in design/workspace-switcher/out/.
4. Compare out/ against reference/ side by side for the two matching screens. Positions, sizes, colors, fonts, spacing and copy must match. Only the iOS status bar and real data values may differ. Fix and re-shoot until they match, then paste the pairs in your final message.
5. Manual check: switch to FTC ROBOTS, force quit, reopen. The app opens on FTC ROBOTS. Then remove yourself from it on another device, reopen. The app opens on Personal with the snackbar.
6. List every file you created or changed.
```

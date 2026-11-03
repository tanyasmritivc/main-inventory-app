# Collapsed sidebar — November 2, 2026

The compact desktop sidebar previously clipped the full wordmark and expanded-width navigation and footer controls. The collapsed state now uses the supplied standalone FindEZ mark, centered 44px controls, and rail-sized padding. Expanded, pinned, keyboard-focused and open-menu states retain the full navigation layout.

Validation: all 26 sidebar tests pass; changed-file ESLint and `git diff --check` pass. The production build completed successfully. Native Safari verification of the exact staged build confirmed the collapsed rail, hover expansion and pinned expanded sidebar. The original pinned preference was restored. Mobile and light-mode visual checks were not repeated for this desktop-only geometry change.

Build `j7LgB7v3YFurmBlDuc3Wu` was deployed to the self-hosted frontend and verified externally at findez.ai. All 12 public routes and seven authentication guards passed; public-page content, configuration and backend process were preserved. The previous compiled release remains available for rollback. See `sidebar-rail-deployment.json` for the receipt.

# Memory, Upgrade dialog and concise activity

The Memory page now groups personalization, response style, optional aliases and
export/forget controls in a padded theme-aware card. The switch remains a native
accessible checkbox. Existing revision, idempotency, confirmation, export and
account-isolation code is unchanged. Raw source metadata and duplicate style
summaries are removed from the visual layout; values remain in selectors/export.

Sidebar Upgrade is slightly taller (48px), retaining its baby-blue sheen. It opens
a modal using the shared Free/Plus/Team comparison and the same monthly/yearly
prices, including ten Team members. View plans and usage links to the existing
/settings/plans page. Continue with Free and Not now close the modal; paid
subscriptions remain Coming soon during early access. No billing/memory API or
entitlement changed. The drawer closes before the modal takes keyboard focus;
closing returns focus to Upgrade or the mobile navigation trigger.

Chat progress previously appended every server phase transition. Backend code
confirms the repeated lookup/result stages are real tool/model phases, not timed
milestones. The UI now groups repeated labels, counts received phase updates and
keeps at most six distinct recent stages. Current stage, elapsed time, real
liveness/staleness and retry evidence remain visible. Counts are status updates,
not successful operations. No model reasoning, tool arguments or fake percentages
are displayed; no backend or mobile behavior changed.

Focused validation: 27 tests in four suites. TypeScript passes; ESLint has no
errors and 52 pre-existing warnings. Full suite, exact-source CI, production build
and Safari verification are recorded in the delivery receipt.

# Purchase library and before-buying checks

Deployed November 11, 2026 to the existing self-hosted FindEZ application.
Open https://findez.ai/settings/connections and choose the intended owner.

* Check before buying accepts a product name, ASIN or full Amazon product link.
  It reads authorized inventory and saved purchase imports. It never fetches the
  supplied link, connects to a live cart, purchases an item or changes stock.
* The library groups products by ASIN, falling back to normalized title. It lists
  ordered units, distinct orders, latest order date and expandable order lines.
  Search accepts product names, ASINs and order IDs. Status filters and pages of
  30 products keep the history manageable. Each product shows its latest 20 lines.
* Ordered units exclude cancelled/returned orders and zero quantities. They are
  not owned or available stock. Recorded inventory can still be allocated or stale.
* FIND's read tools use the current authenticated Personal or organization scope.
  They can ground purchase and reuse advice in saved evidence. Compatibility is
  not inferred from a name match; the user should verify the exact part and fit.
* To populate the library, preview the export and explicitly Save purchase
  history. Previewing alone does not save. Upload a newer export to update history.

## Boundaries and validation

Existing owner/admin organization authorization is reused, with connection
access checked again after the read. Legacy inventory-bound connections remain
in their original View records flow, not silently transferred into owner scope.
The reader caps at 10,000 source lines and 100 connections; limited results are
marked incomplete. Inventory matching uses the existing bounded search. A
negative search never establishes physical absence. Before-buy results show up
to 10 products and 20 inventory candidates. Source addresses, payment information,
credentials and arbitrary source fields are excluded.

The two new tool registrations are additive. Existing vision, attachment,
Auto Extract, capture drafts, review cards and inventory mutations are unchanged.
Recommendations use FIND's existing inventory/project tools and current goal;
there is no autonomous shopping or browser-extension monitoring.

Tests: 9 purchase service tests, 3 full-backend API/chat integration tests with
mocked external I/O, 3 web interaction tests, component lint, production build
and TypeScript. Backend/database health returned 200; anonymous reads/checks
returned 401. Safari live owner-scoped check and actual FIND response verified.
The live account's Personal purchase library was empty; populated results and
permission boundaries were verified with synthetic data rather than importing
or mutating customer records. Mobile-width and light-mode UI were not manually
verified during this delivery; components inherit existing theme variables.

Frontend deployment copied the latest active source and overlaid only the three
purchase UI files, with source-hash and active-directory guards. Backend deployed
four files with baseline-hash guards, backups, health checks and rollback.
No Vercel or Render deployment. No schema or dependency changes.

# Amazon order-history import

User-requested replacement for the primary Gmail setup in Connections. One-time
manual import, with optional later exports, uses existing private commerce records.
No Amazon seller grant or Gmail permission is required. Gmail is shown only as an
optional expansion when configured; this release does not activate it.

## User flow

Settings > Connections > select workspace and inventory > Your Amazon order history.
Follow Amazon's Request Your Data link, obtain an order-data export, upload its
order-history CSV or ZIP, preview the records, then Save purchase history.
The file is not retained. Only allowlisted purchase fields are saved. Addresses,
payment details and unrelated archive members are discarded. Preview makes no
connection or purchase writes. Save creates/reuses the actor's inventory-bound
consumer destination and confirms the exact reviewed bytes by SHA-256.

History shows names, order IDs, quantities, dates and statuses. It is not owned
stock. Users must review what they still own and its location through the existing
inventory workflow. No inventory reconciliation, automated stock additions,
purchasing, seller sync or mailbox sync is introduced here.

## Accepted formats and limits

- UTF-8 Amazon CSV: Order ID, Product Name/Title/Item Name, Quantity/Quantity
  Ordered, Order Date. Optional ASIN or ASIN/ISBN, Order Status, Order Item ID.
- ZIP with Retail.OrderHistory CSV members (or orders.csv); unrelated files ignored.
- Existing strict FindEZ CSV template remains supported.
- At most 10 MB uploaded, 32 MB expanded order files, 100 selected CSVs, 1,000 ZIP
  entries and 10,000 rows. Unsupported/invalid files fail before saving anything.
- ISO dates and US MM/DD/YYYY supported. Date-only/missing-zone native values use
  UTC; UI displays the source calendar date. Unknown statuses remain unknown.
- Native rows with line IDs preserve them. Otherwise order + ASIN (or normalized
  title hash) identifies each product; split rows aggregate quantities. Identical
  rows are skipped with a visible count. Conflicting repeated line IDs fail.
- Repeat imports upsert the same purchase identities through the existing locked
  transaction, never increment inventory. Later exports should include the full
  order/product data; they replace that product's historical quantity rather than
  add it. Cross-format identifier changes are not guaranteed to deduplicate.
- Export schemas vary by Amazon region/account. JSON-only exports and XLSX are not
  supported by this importer. Nothing scrapes Amazon or downloads on the user's behalf.

## Configuration and boundaries

`FINDEZ_COMMERCE_PURCHASE_IMPORT_ENABLED=true` enables file import independently of
merchant integrations and Gmail. Existing feature switches remain unchanged.
New authorized POST /commerce/purchase-file/preview accepts inventory_id and file.
Existing connection creation, SHA-256 confirmation, actor filtering, edit-access
checks, transactional upserts and deletion are reused. No migration is needed.

## Validation

1,675 backend tests and 10 subtests passed; 82 focused commerce/history/email checks
passed. Four frontend suites (38 tests), TypeScript and changed-file ESLint passed.
Real production webpack build passed on a copy of the latest CAD landing release.
Disposable real-account API acceptance verified preview without writes, two saves
producing exactly two records, SHA mismatch rejection, cross-account denial, PII
exclusion and zero inventory items. Browser acceptance and deployment receipt follow.

Amazon download instructions are based on Amazon's Request Your Data entry point
https://www.amazon.com/hz/privacy-central/data-requests/preview.html and official
Amazon privacy/data portability documentation. The page does not promise a fixed
export delivery time or universal account/region format.

## Deployment and acceptance

Published November 11, 2026. Web directory:
`/home/ubuntu/findez-amazon-history-20261111/frontend`, over the current CAD landing
release. Only four web runtime files differ. Backend changes are limited to three
commerce files; original files are backed up under this release's `backup/`.
The independent purchase-import switch is enabled by
`/etc/systemd/system/findez.service.d/zz-amazon-history.conf`. No database migration
or merchant/Gmail activation was performed.

Signed-in browser acceptance passed on the public website without API mocks:
Settings > workspace > inventory > upload CSV > preview > save > view history.
Repeated saves still show exactly two synthetic order lines. Both 1440px and 390px
layouts have no page overflow; primary-button text exceeds 4.5:1 contrast in light
and dark themes. A preexisting commerce button text-token mismatch was corrected.
Temporary test accounts, inventories and purchase records were removed afterward.
The real-account API checks also prove other-account denial and no stock writes.
No real Amazon customer export was supplied; supported synthetic export layouts
and malformed/oversized archives were tested. Region-specific formats may vary.

Rollback: restore the three backend files from `backup/`, remove only
`zz-amazon-history.conf`, reload systemd and restart findez. Remove only the web
`zzzzzzzzzzzzzzzz-amazon-history.conf` drop-in, reload and restart findez-web to
restore the previous website. Saved commerce records remain compatible. One
regenerable webpack cache was moved from the inactive desktop-auth-nav release
to this candidate to fit the server's disk budget; old runtime builds are retained.

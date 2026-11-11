# Using Connections

Release status: live on November 11, 2026. Open https://www.findez.ai/settings/connections. The ownership migration, matching backend and website are deployed and verified.

Connections belong to **Personal** or an **Organization**. An inventory is only selected when you add or update physical items, not when importing purchase history.

## Open the right owner

- Profile and settings → Connections opens Personal by default.
- Connections in an organization's navigation opens that organization's records.
- The Tools card opens Connections even if no inventory exists yet.
- Use **Connection owner** to switch between Personal and organizations where you are an owner or administrator.
- Personal records are private to your account. Organization records are visible to that organization's owners and administrators. Membership does not reveal another user's personal purchases. Switching the owner does not move existing records.

## Import Amazon order history

1. Open **Your Amazon order history** and follow the link to [Amazon's data-request page](https://www.amazon.com/hz/privacy-central/data-requests/preview.html).
2. Sign in on Amazon, request order data, and follow Amazon's confirmation instructions. Labels and availability depend on your Amazon region. FindEZ never needs your Amazon password.
3. When Amazon makes the export available, download it. Choose its order-history **CSV or ZIP** in FindEZ. A ZIP must contain supported CSV order data; JSON-only exports are not supported by this importer. Limits: 10 MB uploaded, 10,000 order rows; ZIP expansion is bounded.
4. Click **Preview order history**. Verify the selected owner, products, order dates, quantities and statuses. Preview saves no records. For Organization, confirm that all records in this file should be shared with its administrators; this is a whole-file import, not a per-order sharing picker.
5. Click **Save purchase history**. Use **Your connections → View records** to reopen the history later.
6. To update your history, upload a newer export under the same owner. Matching order items in that import destination update instead of being added twice. This is a manual import, not ongoing synchronization with Amazon.

Only supported purchase fields are saved. Addresses, payment details and the uploaded file are not retained. Only orders present in your export are included. Returns, cancellations and unknown statuses remain historical evidence, not confirmed stock.

## Add what you still own

Imports never automatically change physical inventory. Verify the item and count it first.

1. Open **Inventory** and select the intended inventory. Search for the item first.
2. If the item already exists, edit its current quantity instead of creating a duplicate.
3. For a new item, choose **Add items → Manual**.
4. Select its Space in **Save to**. Enter **Name**, **Category** and the **Quantity** you physically have now. Add identifiers such as barcode or part number when available.
5. Click **Save item**. Existing inventory editing permissions still apply.

Ordered quantities can represent packs, gifts, returned items or items already consumed. They should not be copied into stock without checking.

## Manage or remove a connection

**Delete imported records** removes that connection and its imported records from FindEZ, after confirmation. It does not remove inventory items or delete orders at Amazon. Organization owners/admins can manage the organization's connection even if another administrator created it.

Shopify and Amazon seller are separate merchant integrations. Their controls remain disabled until configured; they are not required for Amazon shopping-history imports. Existing Gmail integrations retain their previous inventory access rules and appear as previous inventory connections; no new Gmail capability is enabled by this release.

Old non-Gmail connections are moved into their original user's Personal scope only if that user still has inventory editing access. Their IDs, tokens and records are retained. Previously revoked access is not restored. Separate old import sources remain separate rather than being silently merged or shared with an organization.

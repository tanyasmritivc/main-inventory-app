# Large-inventory checkout summary repair

Status: explicitly approved by the user, deployed and verified healthy. The same 670-item website dashboard now loads without the checkout failure.

The website dashboard for a 670-item inventory displays “Could not load lent items.” Production logs identify a PostgREST HTTP 414 URI-too-long failure. The existing exact-item authorization filter sends 200 UUIDs in one database URL; encoding pushes it over the proxy limit.

The only runtime change is in `backend/app/api/routes/checkouts.py`: reduce each exact-item filter batch from 200 to 50 IDs. The same authorized IDs, pagination, active/returned filters, deduplication and final order remain. No database, mobile source, GPU configuration or customer data changes. More small database reads are made for large inventories.

Validation: 1,103 tests and 10 subtests passed in the root suite, including 43 focused checkout/scope/security cases. New tests cover a 670-item HTTP summary, encoded query size under 4KB, exact IDs, per-batch pagination, returned filters, global ordering and no queries for empty visibility.

Proposed deployment: compare the current production file hash with the tested base; back up just that file, publish its tested replacement, compile it, restart the API and check health. Restore on failure. Verify the same website dashboard against the existing inventory without writing customer records.

This is outside the previously approved item-metadata-only server exception. AGENTS.md says: “Keep each change scoped to the requested system. Do not change backend behavior to solve a frontend-only task.” Approval expands scope for this specific repair only.

Deployment receipt: `/home/ubuntu/findez-web-checkout-20261019/activation.json`. Only `backend/app/api/routes/checkouts.py` changed. Before SHA256 `db532d2b482a1b984e912017cad41519186fab1a5f8ab8cadae2abfd67813a97`; after `4390228f43871a8aa29a7fb21d40019d357c9424efc3c3df59cf0760b656fe92`. Backup retained; API health passed. Safari verified the Home overview at 390px with 670 items, seven Spaces, recent items and Review attention, without the earlier lent-items error.

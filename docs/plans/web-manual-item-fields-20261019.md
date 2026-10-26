# Manual web item metadata persistence

The website exposes Brand, Part number, Subcategory and Tags, but the shared
add/update request schemas omitted them. FastAPI silently discarded these values
before storage, so an HTTP 200 could leave the user's metadata unchanged.

User explicitly approved this narrow shared-server correction on October 19.
No mobile source/binary changes and no database migration.

Add bounded optional fields matching existing bulk metadata constraints: 100
characters per scalar, up to 20 tags of up to 50 characters each. Existing omitted
and null update behavior is preserved; blank strings/empty tags explicitly clear
metadata. Ownership and catalog IDs remain outside the client request schema.

Validation: 1,100 tests plus 10 subtests passed, including HTTP create/edit, legacy
quantity-only writes, empty-field clearing and oversized metadata rejection.
Runtime schema/routes/repository hashes match the source baseline.
Deployed the schema only to the existing API service on October 19, with a byte-for-byte backup and health-checked rollback. Live Safari edit/reopen verified Brand and Part number persistence on the isolated QA item. Deployment receipt: /home/ubuntu/findez-web-item-fields-20261019/receipt.json. No other backend files, database state or mobile artifacts were deployed.

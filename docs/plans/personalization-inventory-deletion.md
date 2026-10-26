# Inventory deletion after personalization

The App Store audit confirmed that the fail-closed inventory deletion function did not recognize three inventory-owned tables added by migration081. Consequently even an otherwise valid owner-confirmed inventory deletion failed before mutation.

Migration085 adds only personalization_events, personalization_aliases and personalization_notifications to the reviewed dependency list, after verifying their inventory foreign keys cascade. It does not modify data, table policies, actor/name checks, file cleanup, cross-inventory linkage protection or client RPC privileges. Future unknown dependencies continue to block deletion.

A current production schema with original grants and no customer rows was restored to a network-isolated PostgreSQL container. The migration was applied twice. `backend/tests/sql/personalization_inventory_deletion.sql` passed owned-metadata cleanup, neighbor preservation, outsider/wrong-name denial, unknown dependency denial, cross-inventory alias denial and private RPC checks. The fixture rolls back all synthetic rows and DDL. Run it only on a disposable current-schema clone after085.

Production deployment and live disposable-account verification pending. Rollback must restore the exact prior function definition and retain its existing grants; it must not restore customer rows or reset the database.

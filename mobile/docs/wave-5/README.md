# Wave 5 manual add review

The light and dark simulator screenshots show the grouped manual add form with
an API match selected. The object and place in the screenshots come from a
temporary test API outside the app. No fixture name or count is in the product.

The form checks existing objects before enabling a new save. Selecting a match
fetches its current count and updates that record. A separate new object must
be chosen explicitly when matches exist. Unit tests cover both save paths.

A live save still needs acceptance after the workspace backend and migrations
are available. Shared legacy spaces retain their existing add flow because
their co-member update route does not yet support this record-matching path.

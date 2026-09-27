# Wave 3 visual review

`object-light.png` and `object-dark.png` are iPhone 17 Pro simulator screenshots
of the rebuilt object sheet. They use a temporary test fixture outside the app
source tree. The fixture is not shipped in the app and contains no prototype
demo data.

The real workspace API was not available for this review because migrations 036,
037 and 038 have never been executed against a database. Live object and photo
acceptance remains open. The production app launched with its local configuration
but the workspace request returned Not Found against the undeployed backend.

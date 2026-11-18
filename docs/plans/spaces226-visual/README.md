# Spaces counts and outlines — build 226

The shared Space directory card displays the server-provided item count in both
organization and inventory directories and restores a rounded theme-aware border.
The count describes saved item records, not summed physical units. Zero and missing
counts are distinguished. View-only labels and existing permissions/actions remain.

## Validation

- Flutter analysis: no issues.
- Full Flutter suite: 1,404 passed, one existing skip.
- Focused Spaces suite: 28 passed, including zero/missing counts and 2x text.
- Native iOS simulator: four checks passed, organization/inventory in light/dark.
- The four PNGs here use synthetic data at a 390x844 logical viewport; inspected
  for readable counts, visible borders and layout. They are not customer data.
- Physical iPhone/TestFlight acceptance remains unverified.

## Packaging

The first export was rejected locally because objective_c was a stale simulator
framework. Generated native assets, hook caches and Flutter build intermediates
were cleared and the release was rebuilt. The replacement archive and IPA passed
all 33 device executable checks, strict signatures, 27 privacy manifest checks,
app/extension versions and production configuration verification. No failing
package was uploaded. Application source did not change during the rebuild.

See ../findez-spaces-mobile226-release.json for the delivery receipt.

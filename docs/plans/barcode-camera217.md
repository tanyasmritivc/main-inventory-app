# Camera barcode support

FindEZ UUID labels and recognized FindEZ item URLs are resolved against the
current World using the existing fresh inventory/resource authorization. Private
labels never go to a public provider, and a found item returns details instead of
creating a duplicate draft. Unavailable or cross-organization items return the
same not-found response. Inventory-scoped lookup also normalizes FindEZ URLs.

Public product identity retains the parts catalog and three external providers.
When no source matches, return Unknown item. A bare code no longer triggers an AI
guess that could be mistaken for verified product identity. Catalog coverage is
not universal.

Validation: 1,583 backend tests passed, then two added provider fallback tests
passed in the 11-case camera barcode suite. Live deployment used exact source
hashes, backups and health verification. All 150 unrelated Python files remained
unchanged. No schema migration or customer inventory mutation. The live baseline
contains unrelated work, so only the two narrow route edits and new helper were
applied. Receipt is barcode-camera217-release.json.

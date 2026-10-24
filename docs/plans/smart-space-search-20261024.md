# Smart Space search — October24

The displayed heading prefers partNumber, but the Space filter checked only
name, brand and category. PN-F therefore missed visible PN-F156 records.

`core/item_search.dart` provides pure deterministic keyword matching, identifier
format/prefix matching and one-character word typos/transpositions. All query
words must be present across the saved fields. Numeric identifiers are never
fuzzy. `InventoryItem.searchScore` includes name, partNumber, barcode, brand,
category, subcategory, notes, location, purchase source, tags and imported field
values. `api_client.dart` Team-space lookup and inventory_page Space/global
lookup reuse it. Global exact matches rank before expanded alternatives; the
existing global expansion behavior is retained. Space/category/low-stock filters
and user-selected sorting remain intact. No extra model calls for Space search.

Version becomes1.1.1(121). Tests:21 focused checks, including a real390x844 Space
widget typing PN-F/PNF156 and imported descriptive keywords with a category
filter. Full suite:847 passed,1 optional visual skip. Search regression tests use
synthetic records, not customer data. No native behavior/layout changed.

Manual acceptance on build121:
1. Open Fastener DB; type Pn-F. Existing PN-F rows should remain visible.
2. Type an existing part number with spaces, then without punctuation.
3. Search a description keyword, two words in reverse order, a brand/tag/notes
   keyword, and an imported-column value. A small spelling mistake should work.
4. Try a nonexistent neighboring full part number; it must not substitute another.
5. Repeat with a category and low-quantity filter selected; both still apply.
6. Chat improvements are deployed separately in API PR186; ask for an item using
   descriptive words and check saved candidates/locations instead of exact names.

TestFlight/CI/signature receipts will follow delivery. Physical-device acceptance
remains unverified until the customer checks their own inventory.

## Delivery receipt

Apple acknowledged1.1.1(121):8604efa5-2f43-40ff-96e8-e051dc2a5a11.
Sourcec4fe0b8 / PR187. All five CI jobs passed (run40071676839), clean Flutter
analysis,32 device executables in archive/export,24 privacy manifests, strict
signature/production config and Apple validation passed. Build retains the
pre-existing default launch-image warning; launch/icon assets were not changed.
Processing/tester availability were not polled, physical-device acceptance
unverified, no public App Store submission. IPA/archives and receipts are preserved
under Documents/FindEZ/AppStore/1.1.1-build121.

Backend39ed171 / PR186 is live and passed real HTTPS/real-model tests with synthetic
accounts: formatting, descriptors, notes/tags, typo tolerance and scope isolation.
Stock unchanged; both accounts removed. No customer records used or modified.

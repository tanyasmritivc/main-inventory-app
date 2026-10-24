# Smart inventory search — October 24

The Space list displayed part_number but searched only name, brand and category.
Chat had whole-phrase substring lookup and a SQL prefilter that excluded typo and
formatted-identifier candidates before its word matcher ran.

## Backend changes

- `item_search.py`: pure read-only scoring across name, part number, barcode,
  brand, category, subcategory, notes, location, purchase source, tags and scalar
  imported-column values. All requested words must match across saved fields.
  Exact identifiers/names rank first. Case, separators, common plurals/adaptor,
  prefixes and one-character spelling/transposition are tolerated. No numeric
  fuzzy matching or compatibility inference.
- `items_repo.py`: scoped basic search uses that matcher, preserving fresh-read
  invalidation, repository authorization and pagination. The legacy unscoped
  API keeps its existing behavior. Query candidates walk scoped pages of500,
  retain up to500 matches plus a completeness sentinel, and stop after10,000
  scanned records. Reaching either limit explicitly returns incomplete results.
- `inventory_query.py`: same matching for structured chat queries; filters,
  unknown quantity accounting and bounded totals remain intact.
- `world_chat.py`: instructs the model to extract descriptive keywords, try a
  shorter keyword/synonym when appropriate and clarify ambiguous identities.
- Regression tests cover screenshots' PN-F/PNF156 patterns, description words,
  imported fields, typos, nearby-number rejection, foreign inventory exclusion,
  rare matches beyond the first page and bounded scanning. Full Python suite:
  1,433 passed plus10 subtests;451 existing deprecation warnings.

No schema, dependencies, credentials or new model calls were added. Broad query
scanning can require up to20 database page reads; this is bounded and disclosed.
Semantic embeddings and arbitrary visual similarity are not introduced. The
model can propose semantic synonyms; deterministic search does not invent facts.

## Manual verification

1. In Fastener DB, type `Pn-F`, then an existing full part number with spaces
   instead of hyphens, then the same number without separators.
2. Search a description keyword, then two words in reverse order. Try one word
   from a description and one from notes, brand or an imported column.
3. Keep a category/low-quantity filter selected; search must respect it.
4. Ask chat to find an item by a description or minor spelling mistake. It should
   show saved candidates/locations rather than demand an exact heading.
5. Search a neighboring part number that does not exist; it must not silently
   select the closest numbered part. Ask about an ambiguous item and confirm
   that chat distinguishes candidates before a change.

Deployment and TestFlight receipts will be added after activation. Physical
customer-device acceptance remains separate from synthetic automated checks.

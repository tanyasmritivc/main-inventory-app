# Import test fixtures

Eight files, each built to break the importer in a different way.
If the parser handles all eight, it will handle almost anything a
team uploads.

Every "expected" value below was measured from the generated file,
not estimated.

---

## 01-clean-baseline.xlsx

The happy path. Header in row 0, one clean column per field.

| | |
|---|---|
| Sheets | 1 (`Inventory`) |
| Header row | 0 |
| Data rows | 20 |
| Columns | Name, Category, Quantity, Location, Notes |

**Expected:** every field maps automatically, confidence `high`,
zero issues reported. If this one needs any user correction, the
mapping step is broken.

---

## 02-ftc-parts-gobilda.xlsx

Modeled directly on the real team file. This is the realistic case.

| | |
|---|---|
| `max_row` reports | 1000 |
| Rows with real data | 26 |
| `max_column` reports | 28 |
| Real columns | 9 |
| Header row | 0 — but cell A1 is the number `8` and C1 is 28 spaces |

**Traps:**

- Trusting `max_row` / `max_column` gives 1000×28 instead of 26×9.
  Two whitespace-only cells (A1000, AB640) cause this, exactly as
  in the real file.
- The header row scores *lower* on a "mostly text" heuristic than
  the data rows do. Header detection must use the model.
- Vendor column has five spellings of one company: `Gobilda`,
  `GoBuilda`, `GoBilda`, `gobilda`, `Gobuilda`.
- One vendor cell contains a part number: `3405-0005-0653`.
- `PN-F202` and `PN-F203` have no description at all.
- `PN-F203` has no quantity either.
- `Pn-F7` is size M3 but its description reads `M2x0.4x14mm` —
  a genuine data conflict. Flag it; do not "correct" it.
- Case-inconsistent part numbers: `PN-F7` vs `Pn-F10`.
- Row `PN-F199` has a long note in column 9 that must survive.

**Expected:** name ← Description, category ← Type, quantity ←
Quantity, part_number ← col 0, vendor ← Vendor Name,
purchase_source ← Vendor Part #. Vendor variants grouped with
`Gobilda` proposed as canonical.

---

## 03-section-dividers.xlsx

Category lives in divider rows, not a column.

| | |
|---|---|
| Header row | 2 (rows 0–1 are a merged title and a blank) |
| Rows with data | 14, of which **4 are dividers** |
| Real item rows | 10 |
| Merged ranges | 1 |

Dividers look like `=== FASTENERS ===` with all other cells empty.

**Expected:** the importer recognizes these as section headers and
offers to use them as the category for the rows beneath. Worst
acceptable outcome: they are skipped. Unacceptable: they get
imported as items named `=== FASTENERS ===`.

---

## 04-multi-quantity.csv

Export from a real inventory system. Four numeric columns that
could each plausibly be "quantity".

| | |
|---|---|
| Data rows | 20 |
| Quantity candidates | On Hand, On Order, Min Qty, Reorder Point |

**Expected:** `On Hand` chosen for quantity — and the user is
shown *why*, with the other three offered in the dropdown. Also
SKU → part_number, Supplier → vendor, Bin → notes or location.

This is the file that proves the mapping UI is genuinely editable
rather than decorative.

---

## 05-title-double-header.xlsx

Header is not in row 0, and there are two header rows.

| | |
|---|---|
| Row 0 | merged title, "Robotics Club Inventory — Updated 2026-01-14" |
| Row 1 | blank |
| Row 2 | group header: Item / Stock / Purchase, with gaps |
| Row 3 | **the real header** |
| Data rows | 10 |

**Expected:** `header_row_index = 3`. Picking row 2 yields columns
named `Item`, `None`, `Stock`, `None` — visibly wrong, so this is
easy to eyeball in the preview.

---

## 06-multi-sheet-mixed.xlsx

Three sheets, three different situations.

| Sheet | Rows | Situation |
|---|---|---|
| `Motors` | 5 | clean, maps normally |
| `5mm Timing Belts` | 14 | **no name column** — only Tooth Count, Length, Quantity |
| `Team Notes` | 4 | free-text reminders, not inventory at all |

**Expected:** sheet picker defaults to `Motors`. For the belts
sheet, names are synthesized — `5mm Timing Belt 43T` — from the
sheet title plus tooth count. `Team Notes` is detected as
non-tabular and either hidden or clearly marked unimportable.

Importing `Team Notes` as four unnamed items is the failure to
watch for.

---

## 07-messy-household.xlsx

Non-robotics inventory with human-entered data.

| | |
|---|---|
| Data rows | 17 (one fully blank row inside the data) |
| Header | lowercase with trailing spaces: `item name `, `qty`, `where` |

**Traps:**

- Quantity is prose: `3 boxes`, `~24`, `1 case (12)`, `half box`,
  `12 ea`, and one empty string
- `AA Batteries` appears twice — same item, different casing in
  location (`Junk Drawer` vs `junk drawer`) and category
- Emoji in a name: `Duct Tape 🦆`
- Leading/trailing whitespace on names
- Prices as `$12.99` strings, one bare `18.50`
- Dates as text

**Expected:** numeric quantities extracted where possible
(`3 boxes` → 3, unit `boxes` into notes), `half box` flagged for
review rather than silently becoming 0, and the duplicate pair
surfaced as a merge suggestion.

---

## 08-google-sheets-export.csv

What actually comes out of Google Sheets.

| | |
|---|---|
| Encoding | UTF-8 **with BOM** |
| Data rows | 15 |
| Rows with embedded newlines in a quoted field | 2 |

**Traps:**

- The BOM makes a naive reader see the first column as `﻿Name`
  and fail to match it
- Two Notes cells contain real line breaks inside quotes —
  a line-splitting parser sees 17 rows instead of 15
- Several names contain commas inside quotes:
  `Resistor Kit, 1/4W, 600pc`, `Raspberry Pi 4, 4GB`

**Expected:** 15 rows, multi-line notes preserved intact, first
column recognized as `Name`.

---

## Suggested order

Build against 01 first. Then 02 — it is the realistic target and
the one your users' files will resemble. 04 and 08 are quick wins.
03, 05, 06, 07 are the ones worth deciding *deliberately* about,
because each has a legitimate "we don't support that yet" answer
as long as it fails loudly instead of importing garbage.

The rule for all eight: **never silently import something wrong.**
Skipping with a clear message always beats a clean-looking import
of nonsense rows.

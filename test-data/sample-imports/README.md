# Sample import spreadsheets

Clean, realistic files for uploading through the web app's spreadsheet import.
Unlike `../import-samples/`, these are **not** designed to break the parser —
they are the happy path, meant to populate an account with believable robotics
data for demos, import testing and AI evaluation.

| File | Rows | Contents | Part numbers |
|---|---|---|---|
| `ftc-real-parts-gobilda-rev.xlsx` | 30 | FTC: goBILDA motion + structure, REV control system | **Verified where present** |
| `frc-real-parts-inventory.xlsx` | 40 | FRC: swerve, Kraken/NEO motors, control system, pneumatics | **Verified where present** |
| `ftc-pit-kit-consumables.xlsx` | 30 | Tools, safety, consumables, pit setup | None claimed |
| `ftc-team-parts-inventory.xlsx` | 28 | Earlier draft — FTC parts | ⚠️ **Unverified** |
| `ftc-electronics-control.xlsx` | 25 | Earlier draft — FTC electronics | ⚠️ **Unverified** |

> The last two were written before part numbers were checked against vendor
> catalogues. Their SKUs follow the right *format* but most were never
> confirmed and some are wrong. Fine as import-parser test data; **do not treat
> their Part Number column as real.** Prefer the two `*-real-*` files for
> anything involving catalogue matching.

Shared format, header in row 1:

`Name | Category | Quantity | Location | Part Number | Vendor | Notes`

## About the part numbers

**Only part numbers marked `VERIFIED SKU` in the Notes column were checked
against vendor sources.** In the two `*-real-*` files every other Part Number
cell is deliberately left **blank** rather than filled with a plausible guess —
which is also what a real team's spreadsheet looks like, since teams rarely
record SKUs for everything.

Verified, with sources:

| Part number | Item | Source |
|---|---|---|
| 5203-2402-0005 / -0014 / -0019 / -0027 / -0051 / -0100 | goBILDA Yellow Jacket motors, by ratio | [gobilda.com](https://www.gobilda.com/yellow-jacket-planetary-gear-motors) |
| 1201-0043-0002 | Quad Block Pattern Mount | [gobilda.com](https://www.gobilda.com/1120-series-u-channel) |
| REV-31-1595 | Control Hub | [revrobotics.com](https://www.revrobotics.com/rev-31-1595/) |
| REV-31-1153 | Expansion Hub | [revrobotics.com](https://www.revrobotics.com/rev-31-1153/) |
| REV-31-1389 / -1384 / -1407 / -1382 | Level shifter, sensor adapter, JST cables | [REV docs](https://docs.revrobotics.com/duo-control/control-system-overview/expansion-hub-basics) |
| WCP-0940 / WCP-0941 | Kraken X60 / X44 with TalonFX | [wcproducts.com](https://wcproducts.com/products/kraken) |
| 217-6515 / am-6515 | Talon FX (VEXpro / AndyMark) | [YAGSL docs](https://docs.yagsl.com/devices/motor-controllers/talonfx) |
| am-3583 | Robot Signal Light | [FRC Game Manual §8](https://www.frcmanual.com/2026/robot-construction-rules-(r)) |
| 855PB-B12ME522 | Robot Signal Light (Allen-Bradley) | FRC Game Manual §8 |

Prices change every season and are not included. None of this is a purchase list.

## Before you upload

`Location` values become spaces. Across these files they are: Drivetrain Bin,
Structure Rack, Hardware Drawer, Electronics Bin, Wiring Bin, Pneumatics Bin,
Battery Cart, Pit Cart, Parts Shelf A, Parts Shelf B.

**The free tier allows 3 spaces.** On a free account the import stops with
`FREE_TIER_SPACE_LIMIT`. Upload on Pro, or collapse the Location column to
three values first.

## Why these exist

- A demo account that looks like a real team's inventory
- Happy-path import testing, end to end
- Giving the AI FTC/FRC-shaped data to answer questions about, instead of the
  alcohol cabinets and garden photos currently in test data
- A base for the bin-location work — once `items.bin` exists, these rows are
  ready to be split into bins

For deliberately malformed files that stress the parser — title rows, section
dividers, merged headers, five spellings of "Gobilda" — see
`../import-samples/`, which includes `02-ftc-parts-gobilda.xlsx`, modelled
directly on a real team's file.

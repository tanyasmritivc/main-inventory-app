# FindEZ CAD implementation tracker

The requested product is an inventory-connected CAD workspace, shared parts and
CAD library, BOM reconciliation, pricing and procurement system. The connected
Fusion candidate is the first increment, not completion of this roadmap.

## Candidate 0.4.0: saved BOMs and RexCAD generation (not live)

Implemented locally and staged on the self-hosted server on November 16. A new
migration requires separate production approval before activation. Existing
sessions remain read-only; new CAD writing permission is an explicit editor opt-in.

- Shared immutable BOM versions, inventory-scoped history and saved corrections.
- Actor/inventory-owned generation jobs, durable idempotent retries, clarification,
  cancellation, and temporary STEP download directly into the Fusion placement flow.
- RexCAD server-only adapter using the supplied interface; no provider key in ZIP,
  browser, source or logs. Live synthetic plate submission and download passed.
- Bounded transfers, byte/hash verification, valid solid metadata checks, and
  generated-unverified/fabricate metadata. No manufacturer certification implied.
- Candidate docs and all eight download links consistently target 0.4.0.

The production-copy migration rehearsal preserved 131 original tables, all old
row values, policies and functions. Native Windows insertion is still unverified.
Drawing references, previews, hosted exact-variant assets, nightly generation,
pricing, procurement and advanced engineering checks remain unfinished.
Release evidence: `docs/releases/cad-bom-generation-20261116/README.md`.

## Live increment: connected Fusion candidate 0.3.1

Implemented and published to the self-hosted site on November 15, 2026 after the
user approved the exact additive session migration and candidate release:

- Docked Fusion palette with Inventory, Parts catalog and BOM views.
- Browser sign-in, explicit inventory selection and matching-code confirmation.
- One-inventory, eight-hour, read-only capability. No stock or purchasing writes.
- Inventory search, saved location filtering, pagination and separate on-hand,
  reserved, checked-out and available quantities. Unknown stock remains unknown.
- Browsing existing verified catalog identities and specifications separately
  from team ownership. No invented CAD assets, prices or stock availability.
- AI query interpretation for scoped part searches. Design questions dispatch the
  actual active assembly comparison; vague questions ask for clarification.
- Current-design and saved Fusion project model picker with independent-copy
  insertion, part confirmation, and design/inventory-bound selection.
- Optional local STEP/F3D selection, wrapper identity metadata, SHA-256 asset provenance,
  rigid placement handles, cancel/failed-import cleanup and retained geometry.
  This association and geometry remain unverified.
- Read current assembly metadata, compare through the existing backend engine,
  subtract reservations/checkouts and export shortages from the Fusion panel.
- Existing export-only add-in and browser JSON/CSV/XLSX import preserved.

User photo IMG_3575.DNG confirms Windows installation, sign-in and inventory
browsing; production logs confirm a successful native comparison. New 0.3.1
design-question dispatch and native insertion/placement acceptance remain pending.
Fusion is not installed on the development Mac. Fake-adsk tests are API-contract tests,
not evidence of successful placement in a real design.

## Ordered remaining work and acceptance

| Stage | Existing/reused | Still required | Completion evidence |
| --- | --- | --- | --- |
| Fusion workspace | Candidate connection, personal/team inventory selection, AI parts search, current-design/project model picker, optional local insertion and BOM | Real-host acceptance of native copying/placement; saved/frequent parts; hosted model preview and delivery; richer dimensions/units/orientation verification; reliable placement on supported Fusion versions | Real user signs in, chooses owned part, previews its verified model, inserts and positions it; cancellation leaves design intact; insertion never consumes stock |
| BOM and matching | Existing hierarchy extraction, conservative exact identifiers, name-only review, stock allocation, reservations/checkouts | Carry canonical part/variant identity throughout extraction; activate the tested correction/version candidate; specification conflict checks; design change impact | Duplicate rows cannot reuse stock; corrections survive recheck but invalidate on identity changes; wrong variants need review; unauthorized teams cannot read snapshots |
| Parts and CAD library | Existing verified parts_catalog identity and specifications | Exact variants and identifiers; licensed source records; CAD assets with units, version, digest, provenance and quality; user submissions; official-model resolution; validated previews; incremental durable generation jobs | Initial curated robotics catalog has authoritative exact variants and permitted assets; unknown/approximate models never masquerade as manufacturer verified |
| Pricing | No new live pricing integration | Approved source adapters; timestamped vendor offers and history; currency, pack/unit, MOQ and quantity breaks; exact match vs reviewed alternative vs similar part; partial BOM estimates; independent refresh/retry queue | Correct integer pack purchasing and decimal money; no mixed-currency total; stale/missing quotes visible; substitutes require engineering review; shipping/tax not fabricated |
| Procurement | Existing inventory and project reservations | Inventory-scoped purchase lists, vendor grouping, export/share, team approval, ordered quantities, order references, partial receiving, transactional idempotent stock updates and BOM version association | Two receives/retries cannot double stock; viewers cannot approve/receive; ordered is distinct from physically available; cross-project reservations and received stock reconcile |
| Advanced intelligence | Conservative deterministic matching plus AI query interpretation with scoped retrieval | structured specification extraction; reviewed alternatives; budget recommendations; design-change impact; multi-project planning | Evidence and uncertainty visible; constraints preserved; user approves substitutions; no automatic design changes or checkout |

## Dependencies and boundaries

The user supplied RexCAD generation documentation and server access on November 16.
The 0.4.0 adapter passed a live synthetic generation/download check. Activation is
pending the new migration approval; nightly catalog publication remains separate.

Approved vendor feeds, CAD redistribution rights and pricing access have not been
established for this expansion. Existing catalog records are not evidence of a
license to redistribute the corresponding geometry or imagery. Prefer official
CAD, then verified permitted third-party CAD, then clearly labeled generated
approximate models. Low-confidence generation stays pending validation.

Start the curated catalog with FTC/FRC components; retain a general exact-variant
schema for future engineering hardware. Keep the existing FastAPI backend and
Postgres rather than independent microservices. Reuse existing inventory scope,
reservations and verified catalog identities. Do not add competing stock ledgers.

The Onshape candidate and saved corrections inherited by this branch are not
activated by this Fusion increment. Onshape registration and its migration are
separate. The active production API origin is
https://findez.openstack.ftctools.com, not https://api.findez.ai.

## Data invariants

Catalog existence, CAD representation, team ownership, design requirement,
reservation and purchase are different records. A canonical variant must retain
manufacturer, exact part number, dimensions, thread, material and finish. Similar
names alone cannot establish dimensional or engineering equivalence.

Available stock subtracts other commitments and active checkouts. Required,
on-hand, reserved and on-order quantities must remain distinct. On-order stock
cannot satisfy physical availability. Missing quantities are never negative and
one physical unit cannot satisfy two BOM requirements.

Prices require vendor, source, currency, timestamp and selling unit. A partial
estimate must say which lines lack prices. Alternative recommendations never
modify the design automatically. Model quality must be visible at insertion.

Projects, corrections, purchases and receiving are inventory scoped, permission
checked on every operation, and transactional where stock changes. Public catalog
records must never contain private team inventory or projects.

## Delivery order

Finish native acceptance and connected model selection first, then persist exact
identity and reviewed BOM corrections. Add licensed CAD asset/catalog ingestion,
then pricing, then procurement/receiving. On-demand generation is staged; nightly catalog generation and publication remain
unimplemented. Implement each complete user workflow
with its permission, retry, ambiguity and failure tests before activating it.

Track successful insertions, manual identity corrections, BOM match accuracy,
validated model coverage, current-price coverage, comparison latency, purchase
list usage and repeat use. Do not claim these metrics are instrumented yet.

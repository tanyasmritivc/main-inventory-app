# FindEZ CAD implementation tracker

The requested product is an inventory-connected CAD workspace, shared parts and
CAD library, BOM reconciliation, pricing and procurement system. The connected
Fusion candidate is the first increment, not completion of this roadmap.

## Live release: Fusion 0.5.0 purchasing and shared-stock planning

Published on November 16 after explicit approval of the native purchasing migration.
The full requested roadmap is not complete.

- Fusion panel, scoped sign-in, personal/team inventory selection, AI search,
  location browsing and separate global catalog identities.
- Current-design/project model picker, optional local STEP/F3D import, native
  placement handles, cancellation cleanup, and generated-model insertion.
- On-demand RexCAD jobs, clarification, cancellation, resumable job receipts,
  automatic STEP download with checksum/size checks, and unverified/fabricate labels.
  Provider credentials remain backend-only. No manufacturer certification implied.
- Assembly extraction, exact-identifier matching, reviewable ambiguous matches,
  shared remembered corrections, stock allocation after reservations/checkouts,
  shortages CSV, and immutable inventory-scoped BOM versions.
- Saved requirement quantity/specification differences in Fusion and on the web for two versions of a project.
  This does not compare geometry or refresh historical stock counts.
- Web and separately authorized Fusion purchase plans from a fresh inventory comparison of a saved design; manual
  supplier quotes with sources and expiry; decimal pack/MOQ/bulk pricing; currency-
  separated totals; quote selection and owner/admin approval; vendor-grouped export;
  manual order references; explicit partial receipts into existing stock records.
  Receiving is transactional, retry-safe, permission-checked and audited.
- Slate Fusion panel, centralized CAD docs and consistent 0.5.0 download links.
  Local occurrences no longer require external documentReference access; unresolved
  external references remain incomplete. Public marketing layout unchanged.

Existing Fusion grants remain read-only by default, with a separate editor opt-in
for BOM/correction saves and generation. Purchasing requires its own explicit grant;
CAD writing alone does not authorize procurement or stock changes.

Multi-project planning compares up to twenty saved projects against one free-stock
pool, in selected priority order. All reservations/checkouts are excluded; on-order
quantities remain separate. No reservations or purchases are made by the preview.
Nominal specification conflicts block matching; saved requirements are shown in plans.

Validation: 1398 backend and 726 web full tests; subsequent affected suites 71/29;
local PostgreSQL state/permission/concurrency tests; restored-production rehearsal
preserving 137 tables and existing policies/functions; real production build;
public ZIP/source equality, native grant-revocation concurrency, and narrow browser panel checks. Native Windows
placement/geometry acceptance cannot be established by protocol fakes.

Receipts: docs/releases/cad-native-planning-20261116/README.md and prior CAD releases.

## Ordered remaining work and acceptance

| Stage | Existing/reused | Still required | Completion evidence |
| --- | --- | --- | --- |
| Fusion workspace | Candidate connection, personal/team inventory selection, AI parts search, current-design/project model picker, optional local insertion and BOM | Real-host acceptance of native copying/placement; saved/frequent parts; hosted model preview and delivery; richer dimensions/units/orientation verification; reliable placement on supported Fusion versions | Real user signs in, chooses owned part, previews its verified model, inserts and positions it; cancellation leaves design intact; insertion never consumes stock |
| BOM and matching | Hierarchy extraction, catalog IDs, conservative nominal specification checks, exact identifiers, reviewed corrections, stock allocation, reservations/checkouts | Exact-variant catalog infrastructure; geometry-aware design change impact; automatic synchronization | Duplicate rows cannot reuse stock; corrections survive recheck but invalidate on identity changes; wrong variants need review; unauthorized teams cannot read snapshots |
| Parts and CAD library | Existing verified parts_catalog identity and specifications | Exact variants and identifiers; licensed source records; CAD assets with units, version, digest, provenance and quality; user submissions; official-model resolution; validated previews; incremental durable generation jobs | Initial curated robotics catalog has authoritative exact variants and permitted assets; unknown/approximate models never masquerade as manufacturer verified |
| Pricing | Manual exact-part quote history, expiry, currency-separated subtotals, pack/MOQ/all-unit breaks in web and Fusion purchase plans | Approved live feeds; engineering-reviewed alternatives; independent refresh/retry queue; richer freight and availability | Correct integer pack purchasing and decimal money; no mixed-currency total; stale/missing quotes visible; substitutes require engineering review; shipping/tax not fabricated |
| Procurement | Web and separately authorized Fusion inventory-scoped plans, shared access, vendor CSV, owner/admin approval, manual order records, partial transactional receiving, replay receipts | Vendor cancellations/returns; new stock-record creation during receiving; automatic replenishment allocation; direct checkout | Two receives/retries cannot double stock; viewers cannot approve/receive; ordered is distinct from physically available; cross-project reservations and received stock reconcile |
| Advanced intelligence | Conservative nominal checks, deterministic matching, AI scoped retrieval and ordered multi-project free-stock previews | Structured specification extraction; reviewed alternatives; budget recommendations; geometry-aware design-change impact; reservation-aware project scheduling | Evidence and uncertainty visible; constraints preserved; user approves substitutions; no automatic design changes or checkout |

## Dependencies and boundaries

The user supplied RexCAD generation documentation and server access on November 16.
The adapter is live and passed a synthetic generation/download check. Nightly
catalog publication remains unimplemented.

The user confirmed there are no approved vendor feeds. CAD redistribution rights
and live pricing access have not been established for this expansion. Existing catalog records are not evidence of a
license to redistribute the corresponding geometry or imagery. Prefer official
CAD, then verified permitted third-party CAD, then clearly labeled generated
approximate models. Low-confidence generation stays pending validation.

Start the curated catalog with FTC/FRC components; retain a general exact-variant
schema for future engineering hardware. Keep the existing FastAPI backend and
Postgres rather than independent microservices. Reuse existing inventory scope,
reservations and verified catalog identities. Do not add competing stock ledgers.

The inherited direct Onshape candidate is not activated. Onshape registration
and its migration remain separate; saved CAD corrections are live. The active production API origin is
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

## Remaining delivery dependencies

The next connected increments are canonical exact variants with licensed model
storage and previews, then incremental official-model resolution and validated
catalog generation. Independent geometry validation must precede verified labels.
Do not populate fake vendor feeds, fabricate usage rights, or present generated
nominal parts as manufacturer CAD. Engineering substitutions depend on that trustworthy identity/specification foundation.
The current multi-project preview only allocates conservatively matched free stock.

Native purchasing now uses explicit additional consent and does not expand the
existing BOM/generation grant. Drawing reference uploads, automatic
project synchronization, and broader operational metrics remain unfinished.
Track successful insertions, manual corrections, match accuracy, validated-model
coverage, quote coverage, latency and repeat usage as instrumented evidence,
not claims inferred from unit tests.

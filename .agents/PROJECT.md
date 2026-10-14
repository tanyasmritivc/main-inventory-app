# FindEZ project context

## What FindEZ is

FindEZ's user-supplied product direction is AI memory for the physical world:
capture, understand, remember, retrieve and act on physical belongings. It serves
personal homes/workplaces as well as teams, not only parts inventory or robotics.
The current inventory/Space foundation lets users capture objects, review uncertain
identifications, save their location/context, ask about saved items and coordinate
access or work with others.

The optional mobile setup asks four questions and the guided tutorial teaches the
implemented foundation. The broader context graph, camera-based spatial navigation, predictive
replenishment and other proposed memory capabilities are not all implemented.
Do not present the vision document or demo graphics as proof of deployed features.

## Product direction

Identity: **THE AI MEMORY FOR THE PHYSICAL WORLD.** Promise: **Know what you have.
Find what you need. Instantly.**

- Make physical inventory easy to capture, understand, retrieve, and act on.
- Preserve trustworthy context about an item, including where it is, what evidence
  identified it, and its history.
- Serve individual workshops and teams without making robotics the only use case.
- Keep the product useful in everyday homes, workplaces, labs, and team operations.

## Planned optional business connectors

The user wants Shopify as an additional FindEZ feature, with reusable onboarding
and import/mapping rules for businesses already using commerce platforms. Bring
their existing catalog into context without repeated entry or replacing their
commerce system. Shopify owns commerce records; FindEZ records physical context.
Keep catalog variants, Shopify quantity snapshots and confirmed physical
observations distinct. Read-only is the default; owners can choose supported
product/stock edits and change that later with actual Shopify grants, role checks
and reviewed actions. Preserve general pricing direction and avoid Shopify-only
product/navigation/business logic.

Discovery is complete in `docs/shopify-discovery.md`. The read-only development
connector (1A) and human-confirmed physical-location memory with Team-authorized
lookup (1B) now exist in separate source lanes, disabled by default and not deployed.
See `docs/shopify-development.md` and `docs/physical-memory.md`. No real Shopify
app/store acceptance is complete. Photos, discrepancies, shipments and external
writes beyond supported product details/stock adjustments remain later increments.
Owner-controlled edit source is described in `docs/shopify-owner-permissions.md`;
live grants and mutations remain unverified. This is not authorization for production
migrations or deployment.

Guided stockroom setup is now a further source slice, with factual sync/mapping
progress, a bounded unconfirmed-variant queue and a reviewed-name shortcut into
existing physical memory. See `docs/merchant-guided-migration.md`. It remains
disabled and needs actual development-store and merchant-pilot acceptance.

Business adoption should feel like a guided migration into FindEZ: reuse the
merchant's catalog, preserve product/variant identity, map actual storage and help
the team understand what it has and what needs attention. Shopify can remain the
commerce system. FindEZ adds persistent physical memory and, in later increments,
planning grounded in that memory. Do not claim an end-to-end business migration wizard,
automatic visual matching or operational planning is implemented by these slices.
The first pilot should demonstrate reliable product finding and measure setup
effort, finding/picking time, repeat employee use and willingness to pay.

The user confirms on October 14 that current Shopify work is intended for launch.
The development organization/app/store now exist to test the same launch feature.
Prepare merchant-ready installation and required public-distribution approval;
the current single-store pilot alone does not support unrelated customer stores.
Photo matching and broader planning remain unbuilt subsequent capabilities.

## Users and markets

FindEZ serves households, small businesses, laboratories, schools, makerspaces,
clubs, nonprofits, robotics teams, retail, warehouses, factories, and other
organizations managing physical belongings, supplies, parts, or equipment. Team
category is descriptive and does not change a plan or access permissions. The
category expansion supports 29 alphabetically displayed choices, including a
bounded saved custom label; deploy migration 040 before its dependent clients.

## Current capabilities

- Personal inventory grouped into persistent Spaces
- Photo, barcode, manual, spreadsheet, and BOM-based capture
- FIND photo segmentation, identification, OCR/barcode evidence, and measurement
- Durable Review for uncertain photo results, with retained source photos and
  model-neutral scan evidence
- Search and Ask FindEZ with authenticated inventory tools
- Space sharing with view or edit permissions
- Teams, Team Spaces, board work, members, documents, and activity
- Check-outs and returns
- Project Kits, readiness analysis, and part reservations
- Documents, labels, smart collections, low-stock behavior, and notifications
- Scoped public integration API, Claude Desktop MCP extension, and ChatGPT Actions
- Account, billing, profile, legal, and onboarding flows

## Platforms

- Flutter iOS app, distributed through TestFlight and the App Store process
- Next.js public site and authenticated web application
- FastAPI backend shared by web and mobile
- Local Claude Desktop MCP connector and public HTTP integration API

## Terms agents must use correctly

- **FIND**: the server-side inventory photo pipeline. It segments a scene, proposes
  objects, reads barcodes and text, identifies parts, and measures them. It is not
  the chat model.
- **Agent gateway**: the private FTCTools OpenAI-compatible language gateway used
  for Ask FindEZ, structured tool selection, summaries, parsing, and mapping. The
  application does not use the OpenAI runtime or SDK.
- **Space**: a persistent inventory location. Items still retain a legacy
  `location` string alongside `space_id`.
- **Shared Space**: the older `team_shares` and `team_members` sharing model.
- **Team**: the newer `teams` and `team_memberships` collaboration and licensing
  model. Both models currently exist.
- **Scan evidence**: the public, model-neutral identity, detection, text/barcode,
  measurement, assumptions, warnings, and review reasons returned by capture.
  It persists with unresolved Review records; raw masks/geometry do not persist.
- **Review queue**: durable unresolved photo results in `capture_reviews`, deployed
  with migration `036`. Confirmation creates one inventory item transactionally;
  dismissal creates none. Mobile and web provide the review flow.

## Product invariants

- Mobile leads item presentation; web follows its field order and meaning.
- AI output must remain reviewable. Unknown or low-confidence results must not be
  presented as equally trustworthy inventory.
- Canonical customer contact is `info@findez.ai`.

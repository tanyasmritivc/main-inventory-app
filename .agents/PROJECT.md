# FindEZ project context

## What FindEZ is

FindEZ turns physical objects into searchable, structured inventory. A user can
capture a bin or workspace, identify parts, organize them by Space, find them with
natural language, and coordinate access and work with a team.

The product is positioned as an inventory understanding system rather than a
chatbot layered over a database. The current public message is: turn photos of
physical objects into searchable inventory, organized by space and ready to answer
questions.

## Product direction

- Make physical inventory easy to capture, understand, retrieve, and act on.
- Preserve trustworthy context about an item, including where it is, what evidence
  identified it, and its history.
- Serve individual workshops and teams without making robotics the only use case.
- Keep the product useful under real workshop and competition conditions.

## Users and markets

Robotics teams are the first and most developed market. The product and data model
also support schools, makerspaces, clubs, businesses, and other teams with physical
parts or equipment. The current team context choices include FTC, FRC, FLL, VEX,
School, Makerspace, Club, Business, and Other.

## Current capabilities

- Personal inventory grouped into persistent Spaces
- Photo, barcode, manual, spreadsheet, and BOM-based capture
- FIND photo segmentation, identification, OCR/barcode evidence, and measurement
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
- **Scan evidence**: transient FIND reasoning, confidence, OCR, barcode, and
  measurement information returned before save. It is not a durable evidence
  record today.
- **Review queue**: a planned durable queue for unresolved captured objects. The
  web route exists with an honest empty state, but persistence is not implemented.

## Product invariants

- Mobile leads item presentation; web follows its field order and meaning.
- AI output must remain reviewable. Unknown or low-confidence results must not be
  presented as equally trustworthy inventory.
- Canonical customer contact is `info@findez.ai`.

# FindEZ: AI Inventory

AI item recognition & search for the things you own and the inventory you manage.
FindEZ helps households, small businesses, labs, schools, robotics teams,
warehouses, factories, and other organizations capture, organize, and find
physical belongings, supplies, parts, tools, and equipment.

## What you can do

- Capture inventory from photos, barcodes, manual entry, and spreadsheets.
- Review uncertain AI identifications before saving them as items.
- Organize items into Spaces and find their saved location and quantity.
- Ask natural-language questions about accessible inventory.
- Share Spaces and collaborate in Teams with members, boards, and documents.
- Track check-outs, project kits, reservations, and low stock.
- Connect authorized external assistants through the scoped integration API.

Team categories describe your group; they do not determine access or a paid plan.
Choose from 29 alphabetized categories, including robotics programs, or save your
own custom category.

## Repository

- `mobile/`: Flutter iOS app.
- `frontend/`: Next.js, React, and TypeScript public site and web app.
- `backend/`: shared FastAPI service and Supabase SQL.
- `integrations/findez-mcp/`: local Claude Desktop connector and assistant assets.

Production is self hosted on an OpenStack VM with systemd services, Caddy/nginx,
and Docker-based Supabase. See [.agents/ARCHITECTURE.md](.agents/ARCHITECTURE.md)
for current boundaries and [AGENTS.md](AGENTS.md) before making changes.

## Local development

Use an isolated development database. Numbered migrations alone do not reconstruct
the whole production schema: start with the committed schema baseline and follow
[the schema baseline](backend/supabase/schema-baseline-2026-08-10.sql) and
[TESTING.md](TESTING.md). Never run test fixtures
against production. Copy the relevant `.env.example` files and fill in your local
values; keep service-role, FIND, and language gateway credentials on the backend.

From the repository root:

```bash
python3 -m venv backend/venv
backend/venv/bin/pip install -r backend/requirements.txt
cp backend/.env.example backend/.env
cd backend
venv/bin/uvicorn app.main:app --reload --port 8000
```

In another terminal:

```bash
cd frontend
npm ci
cp .env.example .env.local
npm run dev
```

Frontend: http://localhost:3000. Backend reference: http://localhost:8000/docs.
Mobile setup and client configuration are documented in
[mobile/README.md](mobile/README.md).

Both clients use Supabase Auth and send the user token to FastAPI. The backend
checks authorization before data access. FIND handles inventory photo analysis;
the private language gateway handles Ask and tool selection. Client bundles must
never contain server credentials.

## Validation

```bash
make test BACKEND_PYTHON=backend/venv/bin/python
```

See [TESTING.md](TESTING.md) for setup, coverage, database checks, and physical-device
release gates. Planned capabilities in project context are not claims of deployed
features.

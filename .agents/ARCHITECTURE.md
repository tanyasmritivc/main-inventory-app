# Current architecture

This describes the 2026-10-01 release candidate. Planned systems are labeled.

## Repository

| Path | Current role |
|---|---|
| `frontend/` | Next.js 16, React 19, TypeScript public site and authenticated web app |
| `backend/` | FastAPI application, integrations, data access, and Supabase SQL |
| `mobile/` | Flutter iOS product client and native iOS integrations |
| `integrations/findez-mcp/` | Local stdio MCP server and generated assistant integration assets |
| `supabase/functions/` and `backend/supabase/functions/` | Supabase Edge Function source, including account deletion |
| `tests/` and surface test folders | API contract, PostgreSQL, web, backend, connector, and mobile coverage |

## Client applications

The Flutter app uses Supabase Auth directly, then sends the Supabase access token to
FastAPI through `mobile/lib/core/api_client.dart`. Its main shell has Home, Capture,
Ask, Find and Profile in the restored rounded icon pill. Home surfaces recent items, places, natural-language recall, and
pending Review items. Profile, team, sharing, project, document, checkout,
notification, and settings flows remain.

The Next.js app serves the animated marketing homepage and authenticated product
routes such as `/home`, `/scan`, `/review`, `/inventory`, `/assist`, `/checkout`,
`/teams`, `/collections`, `/project-kits`, `/documents`, `/labels`, and `/settings`.
Server components protect routes with Supabase Auth. Client components call FastAPI
with the current access token. `/product` and `/robotics` redirect to `/`.

## Backend and APIs

`backend/app/main.py` creates the FastAPI app and central error handling.
`backend/app/api/router.py` mounts route modules. HTTP handlers are generally thin;
repository and service modules own data and integrations, although some older routes
still query Supabase directly.

There are two API contracts:

- Application routes use a Supabase user JWT. The backend verifies the user and
  performs authorization and data access.
- `/api/v1` uses hashed, scoped, expiring API keys. It exposes bounded inventory and
  workspace operations for owned Team workspaces. Data requests use a short-lived
  RLS JWT and anon PostgREST client rather than service-role reads.

## Authentication and authorization

Supabase Auth supports email, Google, and Apple. Web and mobile receive a Supabase
session. FastAPI accepts asymmetric ES256/RS256 tokens through JWKS and self-hosted
HS256 tokens through the server-only JWT secret.

Most application repositories use a server-side Supabase service-role client, so
backend user and membership filters are the primary authorization layer and RLS is
defense in depth. The service-role key must never reach a client.

## Database and storage

Production uses self-hosted Supabase with PostgreSQL, PostgREST, Auth, Storage, and
related services. Numbered migrations exist through `037`, but they do not contain
the complete origin of every live table. The committed
`backend/supabase/schema-baseline-2026-08-10.sql` is required for reconstruction and
live schema verification is still necessary for documented drift.

Items use `item_id`, `user_id`, `space_id`, a legacy `location` string, identity and
catalog fields, quantity, notes, and an optional `image_url`. Storage uses the
`item-images` and `documents` buckets. Public or signed item URLs are configuration
dependent; protected document access is authorized before issuing a signed URL.

`capture_reviews` stores uncertain photo results separately from inventory.
Authenticated clients can read only their own records; the backend creates, edits,
dismisses, and resolves them through service-role operations. The resolver inserts
the item and marks its review resolved in one transaction.

Two collaboration models coexist:

- `team_shares` and `team_members` provide Shared Spaces.
- `teams`, `team_memberships`, Team Spaces, board, activity, documents, licensing,
  and API workspaces provide the newer Team model.

## AI and FIND

There is no OpenAI runtime dependency or fallback.

Photo flow:

1. Web or mobile uploads an authenticated image to FastAPI.
2. `find_pipeline.py` runs detection, identification, OCR/barcode processing,
   and measurement. Model and infrastructure details stay on the server.
3. FastAPI maps identity, detection, text, barcode, measurement, assumptions,
   warnings, and review reasons into public `scan_evidence`.
4. The uploaded source image and available per-item crops are copied to the
   `item-images` bucket before the FIND job is deleted in `finally`. Masks and
   geometry are not stored.
5. Clear results may be added to inventory. Uncertain results are saved in
   `capture_reviews` until the user confirms or dismisses them.
6. Review resolution saves the crop or source image as the item's primary
   `image_url`. Lists render a thumbnail only when the item has an image.

Item photo galleries keep `items.image_url` as the primary thumbnail and store
additional image references as `photo` rows in the existing `item_events` table.
This preserves the established item contract and does not require another database
column or migration.

Language flow:

1. Ask FindEZ sends text and an authenticated user context to FastAPI.
2. The backend calls the FTCTools agent gateway using `FINDEZ_AGENT_KEY` and
   the configured private route.
3. The gateway selects a tool call or response.
4. FastAPI executes inventory tools in-process under the signed-in user's scope and
   streams the result to the client.

The gateway also supports summaries, search parsing, barcode fallback, spreadsheet
mapping, and memory extraction. Image uploads for inventory use FIND, not the
language gateway.

## Integration and MCP

`integrations/findez-mcp` is a local stdio process for Claude Desktop. Its eight
tools wrap the public `/api/v1` integration API and use a user-issued scoped key.
It does not connect directly to PostgreSQL. OpenCode is configured to spawn this
same local process. A hosted remote MCP connector with per-user authentication is
not implemented.

## Infrastructure

Production is self hosted on an Ubuntu 24.04 OpenStack VM:

- Caddy terminates public TLS and forwards to nginx.
- systemd runs FastAPI as `findez` and Next.js as `findez-web`.
- Docker runs the self-hosted Supabase stack behind Kong.
- Nightly PostgreSQL backups are restore-checked locally.

There is no automatic deployment. Database migrations are applied manually before
dependent services restart. The production checkout has carried unrelated local
changes, so deploys must inspect and preserve its state. Render, Vercel, and cloud
Supabase are retired production paths; cloud Supabase remains a read-only migration
source and fallback copy.

## Major dependencies

- Both clients depend on Supabase Auth and FastAPI.
- FastAPI depends on Supabase, FIND for photo analysis, and the agent gateway for
  language tasks.
- FIND and gateway credentials remain backend-only.
- Team API access depends on migration `034` workspace synchronization and RLS.
- Durable Review depends on migration `036` and its transactional resolver.
- Next.js public environment values are fixed at build time.

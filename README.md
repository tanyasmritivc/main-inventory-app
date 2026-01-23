# main-ai-inventory

AI-powered inventory management web app.

## Monorepo Structure

- `frontend/`: Next.js (App Router) + TypeScript + Tailwind + shadcn/ui, deployed to Vercel
- `backend/`: FastAPI (Python), deployed to Render (no Docker)

## Quickstart (Local)

### 1) Create Supabase project

- Create a Supabase project
- Create a Storage bucket named `item-images` (public or private; see notes below)
- Apply the SQL in `backend/supabase/migrations/001_init.sql`

To apply the migration:

- In Supabase Dashboard → **SQL Editor** → paste the contents of `backend/supabase/migrations/001_init.sql` → Run

### 2) Backend

```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r backend\requirements.txt
copy backend\.env.example backend\.env
```

Fill in `backend/.env` then run:

```bash
uvicorn backend.app.main:app --reload --port 8000
```

### 3) Frontend

```bash
cd frontend
npm install
copy .env.example .env.local
npm run dev
```

Open:

- Frontend: http://localhost:3000
- Backend: http://localhost:8000/docs

## How Frontend and Backend Communicate

- The frontend uses Supabase Auth in the browser.
- After login, the frontend obtains the user `access_token` (JWT).
- For any inventory action, the frontend calls the FastAPI backend and includes:
  - `Authorization: Bearer <supabase_access_token>`
- The backend verifies the JWT using your Supabase project JWKS and extracts `sub` (user id).
- The backend uses the **Supabase Service Role key** to:
  - Query Postgres (via Supabase REST)
  - Upload images to Supabase Storage
- Row Level Security is enforced on the `items` table so users can only access their own rows.

## Backend API Overview

All endpoints require:

- `Authorization: Bearer <supabase_access_token>`

Endpoints:

- `POST /add_item`
- `POST /search_items`
- `DELETE /delete_item?item_id=...`
- `POST /extract_from_image` (multipart form with `file`)
- `POST /process_barcode`
- `POST /ai_command`

### AI Tool Calling (`POST /ai_command`)

Send a natural-language instruction and the backend will:

- Ask OpenAI to choose a tool (`add_inventory_item`, `search_inventory`, `delete_inventory_item`)
- Execute the chosen action against the database
- Return both the tool result and a final assistant message

Example request body:

```json
{ "message": "Add 2 cans of chickpeas to pantry" }
```

## Deployment Notes

### Vercel (Frontend)

- Set the environment variables from `frontend/.env.example` in Vercel.
- Ensure `NEXT_PUBLIC_API_BASE_URL` points to your Render backend.

### Render (Backend)

- Create a new **Web Service**.
- Build command:

```bash
pip install -r backend/requirements.txt
```

- Start command:

```bash
uvicorn backend.app.main:app --host 0.0.0.0 --port $PORT
```

- Set environment variables from `backend/.env.example`.

## Security Notes

- Do not expose `SUPABASE_SERVICE_ROLE_KEY` to the frontend.
- If you set the Storage bucket to **private**, you should return **signed URLs** from the backend.
  This project supports both; see `backend/app/services/storage.py`.

## Required Environment Variables

Backend (`backend/.env`):

- `SUPABASE_URL`: your Supabase project URL
- `SUPABASE_ANON_KEY`: public anon key
- `SUPABASE_SERVICE_ROLE_KEY`: server-only key (keep secret)
- `SUPABASE_JWKS_URL`: Supabase JWKS endpoint (used to verify JWTs)
- `OPENAI_API_KEY`: OpenAI key (keep secret)

Frontend (`frontend/.env.local`):

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_API_BASE_URL`

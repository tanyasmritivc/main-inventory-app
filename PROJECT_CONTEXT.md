# FindEZ AI — Project Context

## Stack
- Flutter mobile (iOS, com.findez.app) — main app
- FastAPI backend at https://api.findez.ai (Render, repo: backend/)
- Supabase PostgreSQL + RLS
- Next.js 16 frontend at https://www.findez.ai (Vercel, repo: frontend/)
- OpenAI GPT-5 for chat, GPT-4o for vision
- Stripe for payments
- Repo: github.com/tanyasmritivc/main-inventory-app

## Rules
- Windsurf/VS Code + Claude handles ALL code
- Spaces = unique location values on items (NO separate spaces table)
- Always push to git after every change: git add -A && git commit -m "message" && git push
- Never change backend from frontend prompts
- Never change mobile from web prompts

## Architecture
- Spaces are derived from items.location field — no DB table
- Auth: Supabase auth, JWT tokens passed as Bearer headers
- Storage: Supabase Storage bucket "item-images"
- Free tier: 3 spaces, 30 items, 5 photo scans/month, 10 AI chats/month
- Pro tier: $6.99/month or $59.99/year via Stripe

## Database Tables
- profiles: id, is_pro, stripe_customer_id, stripe_subscription_id, display_name, contact_email, avatar_color, created_at
- items: item_id, user_id, name, category, quantity, location, barcode, brand, part_number, notes, purchase_source, created_at
- documents: document_id, user_id, item_id, filename, display_name, storage_path, mime_type, size_bytes, expires_at, created_at
- activity_log: id, user_id, event_type, summary, created_at
- team_shares: share_id, owner_user_id, share_name, share_code, permission, is_active, created_at
- team_members: member_id, share_id, member_user_id, joined_at
- checkouts: checkout_id, user_id, item_id, checked_out_by, space_name, checked_out_at, due_back_at, returned_at, notes, is_active

## Key Files
- mobile/lib/main.dart — app entry, theme, routing
- mobile/lib/features/inventory/inventory_page.dart — main inventory (4000+ lines)
- mobile/lib/features/scan/scan_page.dart — scan tab (DO NOT TOUCH unless scan feature)
- mobile/lib/features/chat/chat_page.dart — Ask tab AI chat
- mobile/lib/features/profile/profile_page.dart — profile + Pro status
- mobile/lib/features/shopping/shopping_list_page.dart — auto shopping list
- mobile/lib/features/checkout/checkout_page.dart — check-out tracker
- mobile/lib/features/sharing/sharing_page.dart — team sharing
- mobile/lib/features/sharing/shared_inventory_page.dart — shared space view
- mobile/lib/features/sharing/space_members_page.dart — team members
- mobile/lib/features/onboarding/onboarding_page.dart — onboarding flow
- mobile/lib/core/api_client.dart — all API calls
- mobile/lib/core/pro_status.dart — Pro status singleton
- mobile/lib/core/upgrade_sheet.dart — Stripe upgrade bottom sheet
- mobile/lib/features/inventory/bin_label_sheet.dart — QR bin labels
- backend/app/api/routes/inventory.py — all API endpoints
- backend/app/services/sharing_service.py — sharing logic
- backend/app/services/usage_service.py — free tier limits
- backend/app/services/items_repo.py — item CRUD + free tier check
- frontend/src/components/site/dashboard-client.tsx — web dashboard
- frontend/src/components/site/settings-client.tsx — web settings + Stripe
- frontend/src/app/shopping-list/page.tsx — web shopping list
- frontend/src/app/checkout/page.tsx — web checkout tracker
- frontend/src/lib/api.ts — all frontend API functions

## Features Built
- Spaces with colored icons (keyword-matched)
- AI photo extraction → bulk save to space
- Barcode scanning (mobile + scan tab)
- Scan Everything button on scan tab
- Space picker when scanning outside a space
- Share spaces by code (view/edit permissions)
- Joined spaces with amber "Shared" badge
- Space members list with owner badge
- Team sharing page (create/join/leave shares)
- Shopping list (auto from low stock thresholds)
- Check-out system (space-scoped, team visible)
- QR bin labels (printable, deep link)
- Where to buy (store links popup — Amazon, eBay etc)
- Item detail: notes, documents, QR code, checkout status
- Pro upgrade via Stripe ($6.99/mo, $59.99/yr)
- Free tier enforcement (429 → upgrade sheet)
- ProStatus singleton with SharedPreferences cache
- Profile: display name, contact email, avatar color picker
- Onboarding flow (4 slides, shows on first install)
- Web: dashboard, shopping list, checkout tracker, settings with Stripe

## Current Issues / In Progress
- Sign up: email confirmation disabled in Supabase (SMTP not configured)
- Scan photo save to documents (backend endpoint written, mobile pending)
- Web dashboard needs full redesign (dashboard-client.tsx)
- Light mode was attempted and reverted — stay dark mode only

## Stripe
- Sandbox mode (test keys)
- Monthly price ID: price_1TiaqF360henrkCrUYnDNBb4
- Yearly price ID: price_1Tiaqi360henrkCrmnkb5942
- Webhook: https://api.findez.ai/stripe/webhook
- Webhook secret: in Render env vars as STRIPE_WEBHOOK_SECRET

## Environment Variables (Render backend)
- SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
- OPENAI_API_KEY, OPENAI_MODEL (gpt-5.2-2025-12-11), OPENAI_VISION_MODEL (gpt-4o)
- STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PRICE_MONTHLY, STRIPE_PRICE_YEARLY
- SUPABASE_JWKS_URL, SUPABASE_JWT_AUDIENCE

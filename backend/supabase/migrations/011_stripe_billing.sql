-- 011_stripe_billing.sql
--
-- 1. Add Stripe subscription tracking columns to profiles.
-- 2. Add team billing columns to team_shares.
--
-- stripe_customer_id and stripe_subscription_id may already exist in the live DB
-- (written by the /stripe/* webhook handler). add column if not exists is idempotent.

-- ── profiles: Stripe + subscription info ──────────────────────────────────────

alter table public.profiles
    add column if not exists stripe_customer_id      text,
    add column if not exists stripe_subscription_id  text,
    add column if not exists subscription_plan       text,       -- 'pro_monthly' | 'pro_annual' | null
    add column if not exists subscription_renews_at  timestamptz;

-- ── team_shares: team season billing ─────────────────────────────────────────

alter table public.team_shares
    add column if not exists plan           text default null,   -- 'active' | null
    add column if not exists plan_expires_at timestamptz;

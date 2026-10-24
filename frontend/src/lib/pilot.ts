/**
 * Centralized pilot-mode helper.
 *
 * `isPilotPublic()` reads NEXT_PUBLIC_PILOT_MODE which is baked at build time.
 * It works on both server and client, for both logged-out and logged-in users,
 * without requiring a /me/limits API call.
 *
 * To activate: set NEXT_PUBLIC_PILOT_MODE=true in the deployment .env file
 * and rebuild the Next.js app (NEXT_PUBLIC_* values are baked at build time).
 */
export function isPilotPublic(): boolean {
  return process.env.NEXT_PUBLIC_PILOT_MODE === 'true';
}

export const PILOT_COPY = {
  title: 'Free Pilot',
  notice:
    'Unlimited access through November 1, 2026. ' +
    'Standard free-plan limits and optional paid plans begin November 2. ' +
    'You will not be charged automatically.',
  buttonLabel: 'Available Nov 2',
  pricingNote: 'Plans shown below will be available starting November 2. No action needed now.',
} as const;

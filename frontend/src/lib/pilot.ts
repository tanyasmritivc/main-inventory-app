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
    'Unlimited access through September 11, 2026. ' +
    'Standard free-plan limits and optional paid plans begin September 12. ' +
    'You will not be charged automatically.',
  buttonLabel: 'Available Sept 12',
  pricingNote: 'Plans shown below will be available starting September 12. No action needed now.',
} as const;

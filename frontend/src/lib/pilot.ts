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
    'Free pre-launch access. Plan quotas are not enforced during this period. ' +
    'There is no automatic cutoff date. ' +
    'You will not be charged automatically.',
  buttonLabel: 'Coming soon',
  pricingNote: 'Plans shown below are for launch. Current pre-launch access is unchanged.',
} as const;

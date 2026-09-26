/** Official FindEZ App Store listing. */
export const APP_STORE_ID = "6760401697";
export const APP_STORE_URL = `https://apps.apple.com/us/app/findez-ai/id${APP_STORE_ID}`;

/** Canonical Universal Link origin (listed in the iOS app's Associated Domains). */
export const INVITE_LINK_ORIGIN = "https://www.findez.ai";

export function invitationUniversalLink(kind: "space" | "team", code: string): string {
  const path = kind === "team" ? `/join/team/${code}` : `/join/${code}`;
  return `${INVITE_LINK_ORIGIN}${path}`;
}

/** Custom-scheme fallback that opens an installed app when Universal Links are bypassed. */
export function invitationAppSchemeLink(kind: "space" | "team", code: string): string {
  const host = kind === "team" ? "team-invite" : "space-invite";
  return `findez://${host}?code=${encodeURIComponent(code)}`;
}

/** iPhone, iPod, and iPad (including iPadOS, which reports a Mac user agent with touch). */
export function isIosDevice(userAgent: string, maxTouchPoints = 0): boolean {
  if (/iPhone|iPad|iPod/i.test(userAgent)) return true;
  return /Macintosh/i.test(userAgent) && maxTouchPoints > 1;
}

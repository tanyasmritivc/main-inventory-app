/**
 * Authenticated workspace routes. middleware.ts redirects anonymous requests for
 * these before any HTML streams (routes with loading.tsx would otherwise stream a
 * skeleton first and redirect only on the client). Every page also calls
 * `requireUser()` on the server; a test keeps this list and those pages in sync.
 */
export const PROTECTED_ROUTE_PREFIXES = [
  "/assist",
  "/checkout",
  "/collections",
  "/documents",
  "/home",
  "/inventory",
  "/labels",
  "/notifications",
  "/onboarding",
  "/project-kits",
  "/review",
  "/scan",
  "/settings",
  "/sharing",
  "/teams",
] as const;

export function isProtectedPath(pathname: string): boolean {
  return PROTECTED_ROUTE_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));
}

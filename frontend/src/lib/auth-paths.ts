/** Sign-in URL that returns to `returnTo` (a local path) after authentication. */
export function signInPath(returnTo: string): string {
  return `/signin?redirect=${encodeURIComponent(returnTo)}`;
}

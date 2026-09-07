export function userFacingError(error: unknown, fallback: string): string {
  const message = error instanceof Error ? error.message.toLowerCase() : "";

  if (message.includes("invalid login credentials")) return "The email or password is incorrect.";
  if (message.includes("email rate limit") || message.includes("too many requests")) return "Too many attempts. Please wait a moment and try again.";
  if (message.includes("network") || message.includes("failed to fetch")) return "FindEZ could not connect. Check your connection and try again.";
  if (message.includes("permission") || message.includes("not allowed")) return "You do not have permission to do that.";

  return fallback;
}

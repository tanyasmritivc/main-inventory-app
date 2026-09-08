// Only allow local paths as authentication destinations.
export function safeAuthRedirect(value: string | null): string {
  if (!value || !value.startsWith("/") || value.startsWith("//") || /[\\\x00-\x20]/.test(value)) {
    return "/inventory";
  }
  return value;
}

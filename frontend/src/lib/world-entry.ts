export const worldPreferenceKey = (accountId: string) =>
  `findez-last-world:${accountId}`;
export function chooseWorld(
  organizations: { organization_id: string }[],
  remembered: string | null,
): string {
  if (remembered === "personal") return "personal";
  if (remembered && organizations.some((o) => o.organization_id === remembered))
    return remembered;
  return organizations.length === 1
    ? organizations[0].organization_id
    : "personal";
}
export function rememberWorld(accountId: string, worldId: string) {
  try {
    localStorage.setItem(worldPreferenceKey(accountId), worldId);
  } catch {
    /* Navigation works without storage. */
  }
}

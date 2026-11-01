export const INVITATION_METADATA_KEY = "findez_pending_invitation";
export type InvitationHandoff = { v: 1; kind: "space" | "team" | "access"; code: string; created_at: number };

/** Private metadata carries a prompt, never membership or authorization. */
export function invitationHandoff(path: string, now = Date.now()): InvitationHandoff | null {
  const access = /^\/join\/access\?code=([A-Za-z2-9]{12})(?:&download=1)?$/.exec(path);
  if (access) return { v: 1, kind: "access", code: access[1].toUpperCase(), created_at: now };
  const match = /^\/join\/(team\/)?([A-Za-z0-9]{6})(?:\?download=1)?$/.exec(path);
  if (!match) return null;
  return { v: 1, kind: match[1] ? "team" : "space", code: match[2].toUpperCase(), created_at: now };
}
export function normalizeInvitationCode(code: string): string {
  return /^[A-Za-z0-9]{6}$/.test(code) ? code.toUpperCase() : "";
}

import { normalizeAuthNext } from "@/lib/auth-callback";

const emailTypes = ["signup", "recovery", "magiclink", "invite", "email_change", "email"] as const;
export type EmailLinkType = typeof emailTypes[number];
export type EmailLink = { tokenHash: string; type: EmailLinkType; destination: string };
const trustedOrigins = new Set(["https://findez.ai", "https://www.findez.ai", "https://findezapp.openstack.ftctools.com"]);

function emailDestination(redirectTo: string | null, type: EmailLinkType) {
  if (type === "recovery") return "/reset-password";
  let target = redirectTo || "/home";
  if (!target.startsWith("/")) {
    try {
      const url = new URL(target);
      if (!trustedOrigins.has(url.origin)) return "/home";
      target = url.pathname + url.search;
    } catch { return "/home"; }
  }
  target = normalizeAuthNext(target);
  const parsed = new URL(target, "https://findez.ai");
  if (parsed.pathname === "/auth/callback") target = normalizeAuthNext(parsed.searchParams.get("next"));
  // An email must not send the newly authenticated session into another auth flow.
  if (/^\/(?:auth(?:\/|$)|reset-password(?:[/?#]|$)|signin(?:[/?#]|$)|signup(?:[/?#]|$))/.test(target)) return "/home";
  return normalizeAuthNext(target);
}

export function parseEmailLink(fragment: string): EmailLink | null {
  const params = new URLSearchParams(fragment.replace(/^#/, ""));
  const tokenHash = params.get("token_hash");
  const type = params.get("type");
  if (params.getAll("token_hash").length !== 1 || params.getAll("type").length !== 1 ||
      !tokenHash || !/^[a-zA-Z0-9_-]{20,512}$/.test(tokenHash) ||
      !emailTypes.includes(type as EmailLinkType)) return null;
  return { tokenHash, type: type as EmailLinkType, destination: emailDestination(params.get("redirect_to"), type as EmailLinkType) };
}

type VerifiedSession = { access_token: string; user: { id: string } };
type EmailAuth = { verifyOtp: (input: { token_hash: string; type: EmailLinkType }) => Promise<{
  data: { session: VerifiedSession | null }; error: { code?: string } | null;
}> };
export type EmailVerification = { destination: string; error?: never; awaitingConfirmation?: never } |
  { error: string; destination?: never; awaitingConfirmation?: never } |
  { awaitingConfirmation: true; destination?: never; error?: never };

export async function verifyEmailLink(auth: EmailAuth, link: EmailLink): Promise<EmailVerification> {
  try {
    // Verify the one-time email proof itself. A previously signed-in account is
    // never evidence that this link succeeded; no local PKCE verifier is needed.
    const { data, error } = await auth.verifyOtp({ token_hash: link.tokenHash, type: link.type });
    if (error) return { error: error.code === "otp_expired"
      ? "This link has expired or has already been used. Request a new email and open the latest link."
      : "This link could not be verified. Request a new email and try again." };
    if (!data.session?.access_token || !data.session.user?.id) {
      // Secure email changes may require confirmation from both addresses.
      if (link.type === "email_change") return { awaitingConfirmation: true };
      return { error: "This link could not establish a session. Request a new email and try again." };
    }
    return { destination: link.destination };
  } catch {
    return { error: "Verification could not finish. Check your connection and reopen the email. If the link was already used, request a new one." };
  }
}

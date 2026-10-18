"use client";

import Link from "next/link";
import { AppThemeProvider } from "@/components/site/use-app-theme";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { InvitationPreview, joinShare, joinTeam, previewInvitation } from "@/lib/api";
import { APP_STORE_URL, invitationAppSchemeLink, isIosDevice } from "@/lib/app-store";
import { invitationHandoff, INVITATION_METADATA_KEY } from "@/lib/invitation";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";

const primary: React.CSSProperties = { display: "block", width: "100%", padding: "14px 18px", border: 0, borderRadius: 12, background: "var(--foreground)", color: "var(--background)", textAlign: "center", textDecoration: "none", font: "inherit", fontWeight: 600, cursor: "pointer", boxSizing: "border-box" };
const secondary: React.CSSProperties = { ...primary, background: "transparent", color: "var(--foreground)", border: "1px solid var(--border)" };

export function JoinInvitationClient({ code, kind, navigate = (url) => window.location.assign(url) }: {
  code: string; kind: "space" | "team"; navigate?: (url: string) => void;
}) {
  return <AppThemeProvider><JoinReview code={code} kind={kind} navigate={navigate} /></AppThemeProvider>;
}
function JoinReview({ code, kind, navigate }: { code: string; kind: "space" | "team"; navigate: (url: string) => void }) {
  const router = useRouter();
  const { token, loading, supabase } = useApiSession();
  const [preview, setPreview] = useState<InvitationPreview | null>(null);
  const [checking, setChecking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ios, setIos] = useState(false);
  const path = kind === "team" ? `/join/team/${code}` : `/join/${code}`;
  const downloadPath = `${path}?download=1`;
  const downloadSignUp = `/signup?redirect=${encodeURIComponent(downloadPath)}`;

  useEffect(() => { setIos(isIosDevice(navigator.userAgent, navigator.maxTouchPoints)); }, []);
  useEffect(() => {
    let current = true;
    setPreview(null); setError(null);
    if (!token || !code) { setChecking(false); return; }
    setChecking(true);
    void previewInvitation({ token, kind, code }).then((data) => {
      if (current) setPreview(data);
    }).catch((reason) => {
      if (current) setError(userFacingError(reason, "This invitation is unavailable. Ask the owner for a new link."));
    }).finally(() => { if (current) setChecking(false); });
    return () => { current = false; };
  }, [code, kind, token]);

  async function accept() {
    if (!token || busy || !preview) return;
    setBusy(true); setError(null);
    try {
      const { data, error: sessionError } = await supabase.auth.getSession();
      if (sessionError) throw sessionError;
      const owner = data.session?.user.id;
      if (!owner || data.session?.access_token !== token) throw new Error("Please refresh this invitation before joining.");
      let destination: string;
      if (kind === "team") {
        const joined = await joinTeam({ token, code, bindToToken: true });
        if (!joined.membership?.team_id || joined.membership.team_id !== preview.target_id) throw new Error("Invitation destination changed. Refresh the invitation.");
        destination = `/workspaces/${encodeURIComponent(joined.membership.team_id)}`;
      } else {
        const share = await joinShare({ token, share_code: code, bindToToken: true });
        if (!share.share_id || share.share_id !== preview.target_id) throw new Error("Invitation destination changed. Refresh the invitation.");
        destination = `/sharing/${encodeURIComponent(share.share_id)}`;
      }
      const { data: current } = await supabase.auth.getSession();
      if (current.session?.user.id === owner) router.replace(destination);
    } catch (reason) { setError(userFacingError(reason, "This invitation could not be accepted. Ask the owner for a current link.")); }
    finally { setBusy(false); }
  }

  async function saveAndDownload() {
    if (!token || busy || !preview) return;
    setBusy(true); setError(null);
    try {
      const { data: session, error: sessionError } = await supabase.auth.getSession();
      if (sessionError) throw sessionError;
      const owner = session.session?.user.id;
      if (!owner || session.session?.access_token !== token) throw new Error("Please sign in again to save this invitation.");
      const handoff = invitationHandoff(path);
      if (!handoff) throw new Error("This invitation link is incomplete.");
      const { error: saveError } = await supabase.auth.updateUser({ data: { [INVITATION_METADATA_KEY]: handoff } });
      if (saveError) throw saveError;
      const { data: current } = await supabase.auth.getSession();
      if (current.session?.user.id !== owner) throw new Error("Your account changed. Please save the invitation again.");
      navigate(APP_STORE_URL);
    } catch (reason) { setError(userFacingError(reason, "The invitation could not be saved. Keep this link and try again.")); }
    finally { setBusy(false); }
  }

  return <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24, background: "var(--background)", color: "var(--foreground)", fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" }}>
    <section aria-label="Invitation" style={{ width: "100%", maxWidth: 440, padding: "32px 28px", border: "1px solid var(--border)", borderRadius: 24, background: "var(--card)", boxSizing: "border-box" }}>
      <Link href="/" style={{ color: "var(--foreground)", textDecoration: "none", fontWeight: 600 }}>FindEZ</Link>
      <p style={{ margin: "32px 0 12px", color: "var(--muted-foreground)", fontSize: 11, letterSpacing: ".12em", textTransform: "uppercase" }}>{kind === "team" ? "Workspace" : "Space"} invitation</p>
      <h1 style={{ margin: "0 0 16px", fontSize: 30, fontWeight: 600, letterSpacing: "-.04em", overflowWrap: "anywhere" }}>{preview?.name ?? `You're invited to ${kind === "team" ? "a workspace" : "a space"}`}</h1>
      <p style={{ color: "var(--muted-foreground)", lineHeight: 1.6 }}>Open the invitation in FindEZ, or review it here. You choose whether to join.</p>
      {preview && <p style={{ fontSize: 14 }}>Access: {kind === "team" ? "Workspace member" : preview.permission === "edit" ? "Can edit" : "View only"}</p>}
      {!code ? <p role="alert" style={{ color: "var(--destructive)" }}>This invitation link is incomplete. Ask the owner for a new one.</p> : <>
        {ios && <a href={invitationAppSchemeLink(kind, code)} style={{ ...primary, marginTop: 24 }}>Open in FindEZ</a>}
        {(loading || checking) && <p role="status" style={{ color: "var(--muted-foreground)" }}>Checking invitation...</p>}
        {!loading && !checking && token && preview && <button type="button" onClick={() => void accept()} disabled={busy} style={{ ...secondary, marginTop: 16, opacity: busy ? .6 : 1 }}>{busy ? "Please wait..." : preview.already_joined ? `Open ${kind === "team" ? "workspace" : "space"} on web` : `Join ${kind === "team" ? "workspace" : "space"}`}</button>}
        {!loading && !token && <Link href={`/signin?redirect=${encodeURIComponent(path)}`} style={{ ...secondary, marginTop: 16 }}>Sign in to join</Link>}
        <div style={{ marginTop: 28, paddingTop: 24, borderTop: "1px solid var(--border)" }}>
          <h2 style={{ margin: "0 0 8px", fontSize: 17, fontWeight: 500 }}>New to the app?</h2>
          <p style={{ margin: "0 0 18px", color: "var(--muted-foreground)", lineHeight: 1.6, fontSize: 14 }}>Save this invitation to your account before downloading. Sign into the same account in FindEZ and your join prompt will appear.</p>
          {token ? <button type="button" onClick={() => void saveAndDownload()} disabled={busy || !preview || checking} style={{ ...primary, opacity: busy || !preview || checking ? .6 : 1 }}>Save invitation &amp; download</button> : <Link href={downloadSignUp} style={primary}>Create account &amp; get the app</Link>}
          {!token && <Link href={`/signin?redirect=${encodeURIComponent(downloadPath)}`} style={{ display: "block", marginTop: 16, color: "var(--muted-foreground)", textAlign: "center", fontSize: 13 }}>Already have an account? Save your invitation</Link>}
          <p style={{ margin: "18px 0 0", color: "var(--muted-foreground)", fontSize: 12, lineHeight: 1.6 }}>Prefer to <a href={APP_STORE_URL} style={{ color: "var(--muted-foreground)" }}>download first</a>? Return to this link after installing. iOS does not carry an invitation through the App Store.</p>
        </div>
        <p style={{ margin: "24px 0 0", color: "var(--muted-foreground)", fontSize: 12 }}>Invitation code: <span style={{ letterSpacing: ".1em", color: "var(--muted-foreground)" }}>{code}</span></p>
      </>}
      {error && <p role="alert" style={{ marginTop: 18, color: "var(--destructive)", lineHeight: 1.5 }}>{error}</p>}
    </section>
  </main>;
}

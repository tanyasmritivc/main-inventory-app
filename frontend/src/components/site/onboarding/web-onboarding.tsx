"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";
import { continuePreview } from "@/lib/landing-preview";
import { FindEZWordmark } from "../findez-brand";
import styles from "./web-onboarding.module.css";

type Setup = { request_id: string; name: string; space: string; personal: boolean };
export function WebOnboarding({ userId, initialPrompt: prompt = "" }: { userId: string; initialPrompt?: string }) {
  const { accountId } = useApiSession();
  const router = useRouter();
  const [personal, setPersonal] = useState(true), [name, setName] = useState("");
  const [space, setSpace] = useState(""), [pending, setPending] = useState<Setup>();
  const [attempt, setAttempt] = useState(0);
  const [busy, setBusy] = useState(false), [ready, setReady] = useState(false), [error, setError] = useState("");
  const locked = useRef(false);
  const key = `findez-organization-setup:${userId}`;
  useEffect(() => {
    if (accountId !== userId) return;
    let live = true;
    try {
      if (localStorage.getItem(`fz_web_onboarding_done_${userId}`)) { router.replace(continuePreview("/worlds", prompt)); return; }
      const raw = localStorage.getItem(key);
      if (raw) {
        const saved = JSON.parse(raw) as Setup;
        if (!saved.request_id || typeof saved.space !== "string" || typeof saved.name !== "string") throw new Error("Saved setup could not be verified.");
        setPending(saved); setPersonal(saved.personal); setName(saved.name); setSpace(saved.space); setReady(true);
        return;
      }
      accountRequest<{ organizations: { is_personal?: boolean }[] }>(userId, "/organizations").then(result => {
        if (!live) return;
        if (result.organizations.some(org => !org.is_personal)) router.replace(continuePreview("/worlds", prompt));
        else setReady(true);
      }).catch(reason => { if (live) setError(userFacingError(reason, "Setup could not be loaded.")); });
    } catch (reason) { setError(userFacingError(reason, "Saved setup could not be loaded.")); }
    return () => { live = false; };
  }, [accountId, userId, key, router, prompt, attempt]);
  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (locked.current || accountId !== userId) return;
    locked.current = true; setBusy(true); setError("");
    try {
      const request = pending || { request_id: crypto.randomUUID(), name: personal ? "Personal" : name.trim(), space: space.trim(), personal };
      localStorage.setItem(key, JSON.stringify(request));
      setPending(request);
      const saved = await accountRequest<{ organization_id: string; space: { id: string } }>(userId, "/organization-setup", { method: "POST", body: request });
      if (!saved.organization_id || !saved.space?.id) throw new Error("Setup could not be confirmed. Retry this request.");
      localStorage.setItem(`fz_web_onboarding_done_${userId}`, "1");
      localStorage.removeItem(key);
      router.replace(continuePreview(`/worlds/${encodeURIComponent(request.personal ? "personal" : saved.organization_id)}?view=spaces`, prompt));
    } catch (reason) { setError(userFacingError(reason, "Setup could not complete. Retry safely.")); }
    finally { locked.current = false; setBusy(false); }
  }
  return <main className={styles.loading}>
    <FindEZWordmark />
    <section style={{ width: "min(440px, 90vw)", textAlign: "left" }}>
      <h1>Organization. Spaces. Your things.</h1>
      <p>Create your first Space. Everyone enrolled in your organization can view it.</p>
      {error && <p role="alert">{error}{!ready && <button onClick={() => { setError(""); setAttempt(v => v + 1); }}>Retry</button>}</p>}
      {!ready ? <p role="status">Loading your account...</p> : <form onSubmit={submit} className={styles.field}>
        <label>Organization
          <select disabled={busy || !!pending} value={personal ? "personal" : "new"} onChange={e => setPersonal(e.target.value === "personal")}>
            <option value="personal">My personal organization</option><option value="new">New team organization</option>
          </select>
        </label>
        {!personal && <label>Organization name<input required maxLength={100} disabled={busy || !!pending} value={name} onChange={e => setName(e.target.value)} /></label>}
        <label>First Space<input required maxLength={100} placeholder="Workshop, kitchen, parts shelf..." disabled={busy || !!pending} value={space} onChange={e => setSpace(e.target.value)} /></label>
        <button className="workspace-button primary" disabled={busy || !space.trim() || (!personal && !name.trim())}>{busy ? "Creating..." : pending ? "Retry setup" : "Create Space"}</button>
        <button className="workspace-button" type="button" disabled={busy} onClick={() => { localStorage.setItem(`fz_web_onboarding_done_${userId}`, "1"); router.replace(continuePreview("/worlds", prompt)); }}>Continue to FindEZ</button>
      </form>}
    </section>
  </main>;
}

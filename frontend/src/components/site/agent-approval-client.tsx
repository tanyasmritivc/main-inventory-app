"use client";

import Link from "next/link";
import { FormEvent, useCallback, useEffect, useRef, useState } from "react";
import { apiBase } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import styles from "./api-keys-client.module.css";

type Approval = {
  id: string; kind: "item" | "space" | "inventory" | "workspace";
  key_name: string; key_revoked: boolean; expires_at: string;
  status: "pending" | "confirmed" | "cancelled";
  preview: { name: string; impact: { items: number; spaces?: number; inventories?: number; workspaces?: number } };
};
const labels = { item: "item", space: "Space", inventory: "inventory", workspace: "workspace" };

export function AgentApprovalClient({ approvalId }: { approvalId: string }) {
  const session = useApiSession();
  if (!session.accountId || !session.token) return <div className={styles.page}>
    <h1>Review agent request</h1><p role="status">{session.loading ? "Checking your account..." : session.error || "Sign in to review this request."}</p>
  </div>;
  return <AccountApproval key={`${session.accountId}:${approvalId}`} session={session} approvalId={approvalId} />;
}

function AccountApproval({ session, approvalId }: { session: ReturnType<typeof useApiSession>; approvalId: string }) {
  const [approval, setApproval] = useState<Approval | null>(null);
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [refreshRequired, setRefreshRequired] = useState(false);
  const active = useRef(true);
  const lock = useRef(false);
  const generation = useRef(0);
  const { supabase, accountId } = session;
  useEffect(() => { active.current = true; return () => { active.current = false; generation.current++; }; }, []);

  const request = useCallback(async (decision?: "confirm" | "cancel", typedName = "") => {
    if (!/^[a-f0-9-]{36}$/i.test(approvalId)) throw new Error("This request link is invalid.");
    const { data, error: authError } = await supabase.auth.getSession();
    if (!active.current || authError || !data.session || data.session.user.id !== accountId)
      throw new Error("Your account changed. Sign in again to review this request.");
    const result = await fetch(`${apiBase().replace(/\/$/, "")}/agent-approvals/${approvalId}${decision ? "/decision" : ""}`, {
      method: decision ? "POST" : "GET", cache: "no-store", redirect: "error", signal: AbortSignal.timeout(30_000),
      headers: { Authorization: `Bearer ${data.session.access_token}`, ...(decision ? { "Content-Type": "application/json" } : {}) },
      ...(decision ? { body: JSON.stringify({ decision, name: typedName }) } : {}),
    });
    const body = await result.json().catch(() => null);
    if (!result.ok) throw new Error(result.status === 409
      ? "The preview expired or changed. Ask your agent to prepare a new request."
      : result.status === 403 || result.status === 404
        ? "This request is unavailable to your account, or the key no longer has permission."
        : "The request could not be confirmed. Refresh its status before trying again.");
    if (!body || body.id !== approvalId || !["pending", "confirmed", "cancelled"].includes(body.status))
      throw new Error("FindEZ could not verify this request. Refresh its status.");
    if (body.status === "confirmed" && body.receipt?.deleted !== true)
      throw new Error("FindEZ has not returned a completed deletion receipt. Refresh its status.");
    return body;
  }, [supabase, accountId, approvalId]);

  const load = useCallback(async () => {
    const current = ++generation.current;
    setLoading(true); setError(null);
    try {
      const result = await request();
      if (!result.preview || typeof result.preview.name !== "string" || !result.preview.impact || !Number.isFinite(Date.parse(result.expires_at)))
        throw new Error("The deletion preview is incomplete. Ask the agent for a new request.");
      if (active.current && current === generation.current) { setApproval(result); setRefreshRequired(false); }
    } catch (reason) {
      if (active.current && current === generation.current) { setError(reason instanceof Error ? reason.message : "Could not load this request."); setRefreshRequired(true); }
    } finally { if (active.current && current === generation.current) setLoading(false); }
  }, [request]);
  useEffect(() => { void load(); }, [load]);

  async function decide(decision: "confirm" | "cancel", event?: FormEvent) {
    event?.preventDefault();
    if (lock.current || !approval || refreshRequired || approval.status !== "pending") return;
    if (decision === "confirm" && (name !== approval.preview.name || approval.key_revoked || Date.parse(approval.expires_at) <= Date.now())) return;
    lock.current = true; setBusy(true); setError(null);
    try {
      const result = await request(decision, name);
      if (result.status === "pending") throw new Error("The decision is still pending. Refresh its status.");
      if (active.current) setApproval({ ...approval, status: result.status });
    } catch (reason) {
      if (active.current) { setError(reason instanceof Error ? reason.message : "The decision could not be confirmed. Refresh its status."); setRefreshRequired(true); }
    } finally { lock.current = false; if (active.current) setBusy(false); }
  }

  const expired = approval ? Date.parse(approval.expires_at) <= Date.now() : false;
  return <div className={styles.page}>
    <Link className={styles.back} href="/settings/api-keys">API keys</Link>
    <h1>Review deletion request</h1>
    {loading && <p role="status">Loading the saved preview...</p>}
    {error && <p role="alert" className={styles.error}>{error}</p>}
    {!loading && <button disabled={busy} onClick={() => void load()}>Refresh status</button>}
    {approval && !loading && <section className={styles.card}>
      {approval.status === "confirmed" ? <><h2>Deletion completed</h2><p role="status">{approval.preview.name} was deleted. Your agent can now check the completed request.</p></>
        : approval.status === "cancelled" ? <><h2>Request cancelled</h2><p role="status">This request did not delete anything.</p></>
          : <>
            <p>Requested by the API key <strong>{approval.key_name}</strong>.</p>
            <h2>Delete {labels[approval.kind]}: {approval.preview.name}</h2>
            <p>This permanently removes the selected {labels[approval.kind]} and its saved contents. It cannot be undone.</p>
            <dl>{(["workspaces", "inventories", "spaces", "items"] as const).map((kind) => {
              const count = approval.preview.impact[kind];
              return count !== undefined && count > 0 ? <div key={kind}><dt>{kind === "spaces" ? "Spaces" : kind.charAt(0).toUpperCase() + kind.slice(1)}</dt><dd>{count.toLocaleString()}</dd></div> : null;
            })}</dl>
            <p>Dependent records are removed and links to this content may be detached. If the saved contents change, you will need a new preview.</p>
            {expired || approval.key_revoked ? <p role="alert">{expired ? "This request has expired. Ask your agent for a new preview." : "This API key has been revoked. Deletion is disabled."}</p>
              : <form onSubmit={(event) => void decide("confirm", event)}>
                <label htmlFor="confirmation-name">Type “{approval.preview.name}” to confirm</label>
                <input id="confirmation-name" autoComplete="off" value={name} onChange={(event) => setName(event.target.value)} disabled={busy || refreshRequired} />
                <div className={styles.actions}>
                  <button type="submit" className={styles.danger} disabled={busy || refreshRequired || name !== approval.preview.name}>{busy ? "Saving decision..." : "Permanently delete"}</button>
                  <button type="button" disabled={busy || refreshRequired} onClick={() => void decide("cancel")}>Cancel request</button>
                </div>
              </form>}
          </>}
    </section>}
  </div>;
}

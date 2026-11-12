"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import { gmailRedirect } from "@/lib/gmail";
import styles from "./commerce-client.module.css";

type Purchase = { title: string; order_id: string | null; asin: string | null;
  ordered_quantity: number | null; statuses: string[];
  observations: { status: string; quantity: number | null; evidence_quote: string }[] };
type Inbox = { account: { status: string; email: string | null; last_sync_at: string | null; last_error: string | null } | null;
  has_more: boolean; purchases: Purchase[];
  messages: { id: string; status: string; result: object | null }[] };
type Request = <T>(path: string, options?: Parameters<typeof accountRequest>[2]) => Promise<T>;

export function PurchaseEmailClient({ accountId, inventoryId, configured, available, request }: {
  accountId: string; inventoryId: string; configured: boolean; available: boolean; request: Request;
}) {
  const [inbox, setInbox] = useState<Inbox | null>(null);
  const [busy, setBusy] = useState(false), [error, setError] = useState("");
  const alive = useRef(false), locked = useRef(false);
  const { confirmAction } = useAppDialog();
  const refresh = useCallback(async () => {
    const value = await request<Inbox>(`/commerce/gmail?inventory_id=${encodeURIComponent(inventoryId)}`);
    if (alive.current) setInbox(value);
  }, [request, inventoryId]);
  useEffect(() => {
    alive.current = true;
    if (available) void refresh().catch((reason) => { if (alive.current) setError(reason instanceof Error ? reason.message : "Purchase emails could not be loaded."); });
    return () => { alive.current = false; };
  }, [available, refresh]);
  async function perform(action?: "connect" | "disconnect" | "purge") {
    if (locked.current) return;
    locked.current = true; setBusy(true); setError("");
    try {
      if (action === "connect") {
        sessionStorage.setItem("findez.gmail.check", "1"); sessionStorage.removeItem("findez.gmail.check");
        const result = await request<{ connection_id: string; authorization_url: string; expires_in: number }>("/commerce/gmail/connect", { method: "POST", body: { inventory_id: inventoryId } });
        if (!alive.current) return;
        window.location.assign(gmailRedirect(result, accountId, inventoryId, window.location.origin, sessionStorage));
        return;
      }
      if (action === "purge") {
        const confirmed = await confirmAction({ title: "Delete Gmail purchase records?", message: "This disconnects Gmail and deletes its imported purchase evidence from FindEZ. Your Gmail messages and physical inventory stay unchanged.", confirmLabel: "Delete records", danger: true });
        if (!confirmed || !alive.current) return;
      }
      if (action) {
        const result = await request<{ google_revocation_confirmed: boolean }>(`/commerce/gmail?inventory_id=${encodeURIComponent(inventoryId)}&purge=${action === "purge"}`, { method: "DELETE" });
        if (!result.google_revocation_confirmed) setError("Disconnected in FindEZ. Google revocation was not confirmed; remove FindEZ access in your Google Account permissions too.");
      }
      await refresh();
    } catch (reason) {
      if (alive.current) setError(reason instanceof Error ? reason.message : "Gmail connection could not be updated.");
    } finally { locked.current = false; if (alive.current) setBusy(false); }
  }
  return <section className={styles.card} aria-label="Amazon shopping purchases">
    <h2>Amazon purchases</h2>
    <p>Connect your Gmail to automatically find Amazon purchase and order-update emails.</p>
    <p>Google grants read-only mailbox access. FindEZ searches Amazon order emails from the last 90 days, then checks for new updates. It does not send, delete, or mark emails as read.</p>
    <p>Purchase email text is processed by FindEZ AI to extract products, quantities, and status. Purchases stay separate from physical stock until reconciled.</p>
    {!configured && <p className={styles.hint}>Gmail purchase imports are not enabled yet.</p>}
    {error && <p role="alert" className={styles.error}>{error}</p>}
    {(!inbox?.account || inbox.account.status === "disconnected") && <button className={styles.primary} disabled={!configured || busy}
      onClick={() => void perform("connect")}>Connect Gmail</button>}
    {inbox?.account && <>
      <p><strong>{inbox.account.status}</strong> {inbox.account.email}</p>
      {inbox.account.last_sync_at && <p>Last checked: {new Date(inbox.account.last_sync_at).toLocaleString()}</p>}
      {inbox.account.last_error && <p role="alert">{inbox.account.last_error}</p>}
      {["pending", "authorizing"].includes(inbox.account.status) && <p>If authorization was interrupted, disconnect this attempt before connecting again.</p>}
      <div className={styles.actions}>
        <button disabled={busy} onClick={() => void perform()}>Refresh purchases</button>
        {inbox.account.status !== "disconnected" && <button disabled={busy} onClick={() => void perform("disconnect")}>Disconnect Gmail</button>}
        <button className={styles.danger} disabled={busy} onClick={() => void perform("purge")}>Delete Gmail purchase records</button>
      </div>
      {inbox.account.status === "disconnected" && <p>Disconnected. Saved purchase evidence is historical.</p>}
      <h3>Purchase evidence</h3>
      <p>Ordered quantities are units of the listed product, which may be packs. Delivery notices do not prove what you currently own. Check against existing items before adding stock.</p>
      {inbox.messages.some((m) => ["queued", "processing"].includes(m.status)) && <p role="status">Purchase emails are being processed. Refresh shortly.</p>}
      {inbox.messages.some((m) => m.status === "failed") && <p role="alert">Some emails could not be read after retries. Check their original receipts; the list below may be incomplete.</p>}
      {!inbox.purchases.length && <p>No purchase details found yet.</p>}
      {inbox.has_more && <p>Showing the latest 1,000 emails. This is not your full purchase history.</p>}
      {inbox.purchases.length > 0 && <div className={styles.tableWrap}><table>
        <thead><tr><th>Product / order</th><th>Reported ordered quantity</th><th>Updates</th><th>Evidence</th></tr></thead>
        <tbody>{inbox.purchases.map((p, index) => <tr key={index}>
          <td>{p.title}<small>{p.order_id || "Order unknown"}</small><small>{p.asin}</small></td>
          <td>{p.ordered_quantity ?? "Needs review"}</td><td>{p.statuses.join(", ")}<small>Not verified in inventory</small></td>
          <td><details><summary>Review email evidence</summary>{p.observations.map((o, i) => <p key={i}>{o.status}: {o.quantity ?? "quantity unknown"}<br />{o.evidence_quote}</p>)}</details></td>
        </tr>)}</tbody>
      </table></div>}
    </>}
  </section>;
}

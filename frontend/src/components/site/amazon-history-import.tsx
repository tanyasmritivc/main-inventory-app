"use client";

import { useEffect, useRef, useState } from "react";
import type { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import { matchesScope, scopeQuery, type ConnectionScope, type CommerceConnection, type ConnectResult } from "@/lib/commerce";
import styles from "./commerce-client.module.css";

type Purchase = { external_id: string; order_id: string; title: string; asin: string | null;
  quantity: number; ordered_at: string; source_status: string };
type Preview = { sha256: string; count: number; order_count: number; duplicates_in_file: number;
  records: Purchase[]; committed: false; stock_effect: "none" };
type Request = <T>(path: string, options?: Parameters<typeof accountRequest>[2]) => Promise<T>;

function importError(reason: unknown) {
  if (reason instanceof ApiError) {
    if (reason.status === 413) return "This file is too large. Upload up to 10 MB, with at most 10,000 order rows.";
    if (reason.status === 422) return "We could not read this export. Choose the Amazon order-history CSV or its ZIP, with Order ID, Product Name (or Title), Quantity and Order Date. Check that quantities and dates are valid.";
    if (reason.status === 409) return "The file or import destination changed. Preview the file again before saving.";
  }
  return reason instanceof Error ? reason.message : "The import could not be confirmed. You can retry the same file without duplicating matching purchases.";
}

export function AmazonHistoryImport({ inventoryId, scope, ownerName = "Personal", configured, loading, request, onSaved }: {
  inventoryId?: string; scope?: ConnectionScope; ownerName?: string; configured: boolean; loading: boolean; request: Request;
  onSaved: (connection: CommerceConnection) => Promise<void>;
}) {
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [busy, setBusy] = useState(false), [error, setError] = useState(""), [notice, setNotice] = useState("");
  const [visible, setVisible] = useState(20);
  const alive = useRef(false), locked = useRef(false), input = useRef<HTMLInputElement>(null);
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  function choose(value: File | null) {
    setPreview(null); setNotice(""); setError(""); setVisible(20); setFile(value);
    if (value && (value.size > 10 * 1024 * 1024 || !/\.(csv|zip)$/i.test(value.name))) {
      setFile(null); setError("Choose an Amazon order-history CSV or ZIP, up to 10 MB.");
    }
  }
  async function upload(save: boolean) {
    if (locked.current || !file || !configured || (save && !preview)) return;
    locked.current = true; setBusy(true); setError(""); setNotice("");
    try {
      const body = new FormData(); body.append("file", file);
      if (!save) {
        if (scope) { body.append("scope_type", scope.scope_type); if (scope.organization_id) body.append("organization_id", scope.organization_id); }
        else body.append("inventory_id", inventoryId!);
        const result = await request<Preview>("/commerce/purchase-file/preview", { method: "POST", body });
        if (alive.current) { setPreview(result); setVisible(20); }
      } else {
        // A lost create response is recoverable: look up the actor's existing
        // destination before every save, rather than creating a second import.
        const existing = await request<{ connections: CommerceConnection[] }>(`/commerce/connections?${scope ? scopeQuery(scope) : `inventory_id=${encodeURIComponent(inventoryId!)}`}`);
        let connection = existing.connections.find(c => c.provider === "amazon_consumer" && c.status === "connected" && (!scope || matchesScope(c, scope)));
        if (!connection) {
          const result = await request<ConnectResult>("/commerce/connections", { method: "POST", body: { ...(scope || { inventory_id: inventoryId }), provider: "amazon_consumer" } });
          connection = result.connection;
        }
        if (connection.provider !== "amazon_consumer" || (scope ? !matchesScope(connection, scope) : connection.inventory_id !== inventoryId) || connection.status !== "connected") throw new Error("The import destination could not be verified. Refresh Connections.");
        body.append("confirmed_sha256", preview!.sha256);
        const result = await request<{ committed: boolean; count: number; sha256: string; stock_effect: string }>(`/commerce/connections/${connection.id}/purchase-file`, { method: "POST", body });
        if (!result.committed || result.sha256 !== preview!.sha256 || result.stock_effect !== "none") throw new Error("Import was not confirmed. Refresh your records before retrying.");
        if (!alive.current) return;
        setPreview(null); setFile(null); if (input.current) input.current.value = "";
        setNotice(`Saved ${result.count} purchase records. Matching order items were updated, not added twice. Your inventory quantities have not changed.`);
        await onSaved(connection);
      }
    } catch (reason) { if (alive.current) setError(importError(reason)); }
    finally { locked.current = false; if (alive.current) setBusy(false); }
  }
  return <section className={styles.card} aria-label="Amazon order history">
    <p className={styles.eyebrow}>One-time import</p><h2>Your Amazon order history</h2>
    <p>See what you ordered, all in one place. Import your past purchases once; add a newer export whenever you want to update them. No Amazon connection or Gmail access needed.</p>
    <ol className={styles.steps}>
      <li><strong>Request your orders.</strong> Open <a href="https://www.amazon.com/hz/privacy-central/data-requests/preview.html" target="_blank" rel="noopener noreferrer">Amazon’s Request Your Data page ↗</a>, choose your order data and follow Amazon’s confirmation steps. Availability and labels vary by region; use your local Amazon account if needed.</li>
      <li><strong>Download the export.</strong> When Amazon makes it available, download the ZIP. You can also upload its order-history CSV, usually named Retail.OrderHistory. This covers the orders included in that export.</li>
      <li><strong>Review and save.</strong> Check the products, dates, quantities and statuses below before saving your purchase history.</li>
    </ol>
    <p className={styles.hint}>Previously purchased does not mean currently owned. Returned, cancelled, gifted or used items may no longer be available. Confirm what you still own and its location in your inventory before counting it toward a build.</p>
    {!loading && !configured && <p role="status">Order-history imports are temporarily unavailable. Please try again later.</p>}
    <label htmlFor="amazon-history-file">Amazon order-history file</label>
    <input ref={input} id="amazon-history-file" type="file" accept=".csv,.zip,text/csv,application/zip" disabled={busy || loading || !configured}
      onChange={event => choose(event.target.files?.[0] ?? null)} />
    <p className={styles.hint}>CSV or ZIP · Up to 10 MB and 10,000 rows. Only purchase fields are saved; addresses and payment details are discarded. The uploaded file is not retained.</p>
    {error && <p role="alert" className={styles.error}>{error}</p>}
    {notice && <p role="status" className={styles.notice}>{notice}</p>}
    {busy && <p role="status">{preview ? "Saving purchase history…" : "Reading your order history…"}</p>}
    {!preview && <button className={styles.primary} disabled={!file || busy || loading || !configured} onClick={() => void upload(false)}>Preview order history</button>}
    {preview && <div aria-label="Order history preview">
      <h3>{preview.count} purchase records · {preview.order_count} orders</h3>
      <p>Saving to <strong>{ownerName}</strong>. {scope?.scope_type === "organization" ? "Organization owners and administrators will be able to view these purchases." : "Only you can view these purchases."}</p>
      <p>No purchases have been saved yet. Quantities are ordered units or packs, not a count of what you still own.</p>
      {preview.duplicates_in_file > 0 && <p>{preview.duplicates_in_file} identical rows in the file were ignored.</p>}
      <div className={styles.tableWrap}><table><thead><tr><th>Product / order</th><th>Ordered</th><th>Quantity</th><th>Status</th></tr></thead>
        <tbody>{preview.records.slice(0, visible).map(row => <tr key={row.external_id}><td>{row.title}<small>{row.order_id}</small><small>{row.asin}</small></td>
          <td>{row.ordered_at.slice(0, 10)}</td><td>{row.quantity}</td><td>{row.source_status}<small>Ownership unconfirmed</small></td></tr>)}</tbody></table></div>
      <div className={styles.actions}>
        {visible < preview.records.length && <button disabled={busy} onClick={() => setVisible(v => v + 100)}>Show more purchases</button>}
        <button className={styles.primary} disabled={busy} onClick={() => void upload(true)}>Save purchase history</button>
        <button disabled={busy} onClick={() => { setPreview(null); setFile(null); if (input.current) input.current.value = ""; }}>Cancel import</button>
      </div>
    </div>}
  </section>;
}

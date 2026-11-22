"use client";
import { cadWorldPath } from "@/lib/cad-links";
import { useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { activeInventory } from "@/lib/inventory-selection";
import styles from "./cad.module.css";

type Connection = { id: string; inventory_id: string; session_expires_at: string };
export function FusionConnect({ code }: { code: string }) {
  const inventory = activeInventory()!;
  return <ConnectionForm key={`${inventory.accountId}:${inventory.inventory_id}`} code={code} inventory={inventory} />;
}

function ConnectionForm({ code, inventory }: { code: string; inventory: NonNullable<ReturnType<typeof activeInventory>> }) {
  const actor = inventory.accountId;
  const [value, setValue] = useState(code);
  const [confirmed, setConfirmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [approved, setApproved] = useState(false);
  const [error, setError] = useState("");
  const [connections, setConnections] = useState<Connection[]>([]);
  const [writesEnabled, setWritesEnabled] = useState(false);
  const [allowWrites, setAllowWrites] = useState(false);
  const [purchasingEnabled, setPurchasingEnabled] = useState(false);
  const [allowPurchasing, setAllowPurchasing] = useState(false);
  const mounted = useRef(true);
  const locked = useRef(false);
  const request = useRef<AbortController | null>(null);
  useEffect(() => {
    mounted.current = true;
    const controller = new AbortController();
    void accountRequest<{ connections: Connection[]; cad_writes_enabled?: boolean; purchasing_enabled?: boolean }>(actor, "/fusion/connections", { signal: controller.signal })
      .then(data => { if (!controller.signal.aborted && mounted.current) { setConnections(data.connections); setWritesEnabled(data.cad_writes_enabled === true); setPurchasingEnabled(data.purchasing_enabled === true); } })
      .catch(() => { if (!controller.signal.aborted) setError("Connections could not be loaded. Reload to try again."); });
    return () => { mounted.current = false; controller.abort(); request.current?.abort(); };
  }, [actor]);
  async function connect() {
    if (locked.current || !confirmed || !/^[A-HJ-NP-Z2-9]{10}$/.test(value)) return;
    locked.current = true; setBusy(true); setError("");
    const controller = new AbortController(); request.current = controller;
    try {
      const receipt = await accountRequest<{approved: boolean}>(actor, "/fusion/pairing/approve", { method: "POST", body: { code: value, inventory_id: inventory.inventory_id, ...(allowPurchasing && purchasingEnabled && inventory.can_edit ? { allow_purchasing: true } : {}), ...(allowWrites && writesEnabled && inventory.can_edit ? { allow_cad_writes: true } : {}) }, signal: controller.signal });
      if (receipt.approved !== true) throw new Error("Connection was not confirmed. Start again in Fusion.");
      if (!controller.signal.aborted && mounted.current) setApproved(true);
    } catch (e) { if (mounted.current) setError(e instanceof Error ? e.message : "Connection failed. Start again in Fusion."); }
    finally { locked.current = false; if (mounted.current) setBusy(false); }
  }
  async function disconnect(id: string) {
    if (locked.current) return;
    locked.current = true; setBusy(true); setError("");
    const controller = new AbortController(); request.current = controller;
    try {
      const receipt = await accountRequest<{disconnected: boolean}>(actor, `/fusion/connections/${encodeURIComponent(id)}`, { method: "DELETE", signal: controller.signal });
      if (receipt.disconnected !== true) throw new Error("Disconnect was not confirmed. Try again.");
      if (!controller.signal.aborted && mounted.current) setConnections(current => current.filter(c => c.id !== id));
    } catch (e) { if (mounted.current) setError(e instanceof Error ? e.message : "Disconnect failed. Try again."); }
    finally { locked.current = false; if (mounted.current) setBusy(false); }
  }
  return <section className={styles.page}>
    <header className={styles.hero}><a href={cadWorldPath("/docs/cad#connect", inventory.workspace?.organization_id)}>← CAD Intelligence</a><h1>Connect FindEZ to Fusion.</h1><p>Read parts and compare your assembly with this inventory.</p><a href={cadWorldPath("/docs/cad#downloads", inventory.workspace?.organization_id)}>Downloads and installation</a><p>Setup, generation permissions, and troubleshooting are in CAD Intelligence. <a href={cadWorldPath("/docs/cad#connect", inventory.workspace?.organization_id)}>Read the CAD documentation</a>.</p></header>
    <div className={styles.card}>
      {approved ? <div role="status"><h2>Connection approved</h2><p>{allowWrites ? "Model generation and shared BOM saves are enabled for this session." : "This session can browse and compare. To generate models or save BOMs, reconnect and enable the optional CAD writing permission."}</p><p>{allowPurchasing ? "Purchase plans and confirmed receiving are enabled. Approvals and ordering still require your inventory owner/admin role." : "Purchasing access is disabled for this session."}</p><p>Return to Fusion. The panel will connect automatically. If it timed out, start again there.</p></div> : <>
        <h2>{inventory.name}</h2>
        <p>Fusion can read this inventory and the public parts catalog, and compare a parts list. By default it cannot change stock or manage purchases. Optional permissions below apply only to this inventory.</p>
        <label className={styles.file}>Code shown in your Fusion panel<input autoComplete="off" spellCheck={false} maxLength={10} value={value} onChange={e => { setValue(e.target.value.toUpperCase().replace(/\s/g, "")); setConfirmed(false); }} /></label>
        <label className={styles.permissionOption}><input type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} /><span>I started this connection in Fusion and the code matches.</span></label>
        {writesEnabled && inventory.can_edit && <label className={styles.permissionOption}><input type="checkbox" checked={allowWrites} onChange={e => setAllowWrites(e.target.checked)} /><span><strong>Enable model generation and saved BOMs (optional)</strong>Also allow this Fusion session to save shared BOM versions and match corrections, and generate STEP models through RexCAD. Generation sends the specifications you submit to RexCAD. This does not permit stock changes or purchases.</span></label>}
        {purchasingEnabled && inventory.can_edit && <label className={styles.permissionOption}><input type="checkbox" checked={allowPurchasing} onChange={e => setAllowPurchasing(e.target.checked)} /><span><strong>Enable purchase plans and receiving (optional)</strong>Allow this Fusion session to read quotes and orders, create purchase plans, record supplier quotes, and add delivered quantities to existing stock after an explicit confirmation. Approvals and order recording require an owner/admin role. No vendor checkout or payment is performed.</span></label>}
        <p>Only approve a code displayed in your own Fusion add-in. Access expires after eight hours. Assembly comparison does not upload geometry. Model generation sends only the specification you explicitly submit.</p>
        <button disabled={busy || !confirmed || !/^[A-HJ-NP-Z2-9]{10}$/.test(value)} onClick={connect}>{busy ? "Connecting..." : "Connect this inventory"}</button>
        <p><a href={cadWorldPath(`/cad/fusion/connect${value ? `?code=${encodeURIComponent(value)}` : ""}`, inventory.workspace?.organization_id)}>Choose a different inventory</a></p>
      </>}
      {error && <p role="alert">{error}</p>}
    </div>
    <div className={styles.card}><h2>Your active Fusion connections</h2>
      {connections.length ? <ul>{connections.map(c => <li key={c.id}>Inventory {c.inventory_id === inventory.inventory_id ? inventory.name : c.inventory_id}. Expires {new Date(c.session_expires_at).toLocaleString()} <button disabled={busy} onClick={() => disconnect(c.id)}>Disconnect</button></li>)}</ul> : <p>No active connections were found when this page opened. Reload after Fusion connects to refresh this list.</p>}
    </div>
  </section>;
}

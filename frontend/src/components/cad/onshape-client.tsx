"use client";
import { useEffect, useRef, useState } from "react";
import { useApiSession } from "@/lib/use-api-session";
import { accountRequest } from "@/lib/account-request";
import { activeInventory } from "@/lib/inventory-selection";
import { onshapeQuery, parseOnshapeUrl, type OnshapeAssembly } from "@/lib/onshape";
import type { CadComparison } from "@/lib/cad";
import { CadEntry } from "./cad-entry";
import { CadResults } from "./cad-results";
import styles from "./cad.module.css";

export function OnshapeEntry({ destination }: { destination: string }) {
  const { accountId, error } = useApiSession();
  const [choose, setChoose] = useState(false);
  useEffect(() => {
    if (!accountId) return;
    try {
      const inventory = localStorage.getItem(`findez:onshape:inventory:${accountId}`);
      if (inventory && /^[a-f0-9-]{36}$/.test(inventory)) {
        window.location.replace(`${destination}${destination.includes("?") ? "&" : "?"}inventory=${encodeURIComponent(inventory)}`);
        return;
      }
    } catch { /* Browser storage is optional. */ }
    // Storage is only available after hydration; reveal the picker after reading it.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setChoose(true);
  }, [accountId, destination]);
  return error ? <p role="alert">{error} <a href="/cad">Choose inventory</a></p> : choose ? <CadEntry destination={destination} /> : <p role="status">Opening your inventory...</p>;
}

export function OnshapeClient({ initial }: { initial: OnshapeAssembly | null }) {
  const inventory = activeInventory()!;
  const actor = inventory.accountId;
  const [connection, setConnection] = useState<{ enabled: boolean; connected: boolean } | null>(null);
  const [context, setContext] = useState(initial);
  const [url, setUrl] = useState("");
  const [result, setResult] = useState<CadComparison | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const controller = useRef<AbortController | null>(null);
  const automatic = useRef(false);
  useEffect(() => {
    let live = true;
    try { localStorage.setItem(`findez:onshape:inventory:${actor}`, inventory.inventory_id); } catch { /* Optional preference only. */ }
    void accountRequest<{ enabled: boolean; connected: boolean }>(actor, "/onshape/connection")
      .then(data => { if (live) setConnection(data); }).catch(e => { if (live) setError(e instanceof Error ? e.message : "Connection could not be checked."); });
    return () => { live = false; controller.current?.abort(); };
  }, [actor, inventory.inventory_id]);

  async function check(assembly = context) {
    if (!assembly || busy) return;
    const request = new AbortController(); controller.current = request;
    setBusy(true); setError(""); setResult(null);
    try {
      const data = await accountRequest<CadComparison>(actor, "/cad/onshape/compare", { method: "POST", body: JSON.stringify(assembly), signal: request.signal });
      if (!request.signal.aborted) setResult(data);
    } catch (e) { if (!request.signal.aborted) setError(e instanceof Error ? e.message : "The assembly could not be checked."); }
    finally { if (!request.signal.aborted) setBusy(false); }
  }
  useEffect(() => {
    if (connection?.connected && initial && !automatic.current) {
      automatic.current = true;
      void check(initial);
    }
    // A launch checks exactly once. Later checks are explicit.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connection?.connected, initial]);

  async function connect() {
    setBusy(true); setError("");
    const request = new AbortController(); controller.current = request;
    try {
      const query = onshapeQuery(context);
      sessionStorage.setItem(`findez:onshape:return:${actor}`, `/cad/onshape?inventory=${encodeURIComponent(inventory.inventory_id)}${query ? `&${query}` : ""}`);
      const data = await accountRequest<{ authorization_url: string }>(actor, "/onshape/connect", { method: "POST", signal: request.signal });
      const authorization = new URL(data.authorization_url);
      if (authorization.origin !== "https://oauth.onshape.com" || authorization.pathname !== "/oauth/authorize") throw new Error("Invalid Onshape authorization destination.");
      if (!request.signal.aborted) window.location.assign(authorization.href);
    } catch (e) { if (!request.signal.aborted) { setError(e instanceof Error ? e.message : "Onshape could not connect."); setBusy(false); } }
  }
  async function disconnect() {
    const request = new AbortController(); controller.current = request;
    setBusy(true); setError("");
    try {
      await accountRequest(actor, "/onshape/connection", { method: "DELETE", signal: request.signal });
      if (!request.signal.aborted) { setConnection({ enabled: true, connected: false }); setResult(null); }
    } catch (e) { if (!request.signal.aborted) setError(e instanceof Error ? e.message : "Disconnect failed."); }
    finally { if (!request.signal.aborted) setBusy(false); }
  }
  function changeInventory() {
    try { localStorage.removeItem(`findez:onshape:inventory:${actor}`); } catch { /* Optional preference only. */ }
    // Reset the inventory boundary and the one-shot launch state together.
    // eslint-disable-next-line @next/next/no-location-assign-relative-destination
    window.location.assign(`/cad/onshape?${onshapeQuery(context)}`);
  }
  return <section className={styles.page}>
    <header className={styles.hero}><h1>Check your Onshape assembly.</h1><p>See what you have and what you still need to buy.</p></header>
    <div className={styles.inventoryStrip}>Comparing with {inventory.name}<button onClick={changeInventory} disabled={busy}>Change inventory</button></div>
    <div className={styles.card}>
      {connection?.enabled === false ? <p>Direct Onshape connection is awaiting app registration. <a href={`/cad?inventory=${encodeURIComponent(inventory.inventory_id)}`}>Use your flattened BOM CSV today.</a></p>
        : <><p>{connection?.connected ? "Onshape connected" : "Connect your own Onshape account to authorize read-only access."}</p>
          <button onClick={() => void connect()} disabled={busy || !connection}>{connection?.connected ? "Reconnect Onshape" : "Connect Onshape"}</button>
          {connection?.connected && <button onClick={() => void disconnect()} disabled={busy}>Disconnect</button>}</>}
      <label>Onshape assembly link<input type="url" value={url} onChange={e => setUrl(e.target.value)} placeholder="https://cad.onshape.com/documents/..." disabled={busy} /></label>
      <button disabled={busy || !connection?.connected || (!context && !url)} onClick={() => {
        try { const next = url ? parseOnshapeUrl(url) : context; setContext(next); void check(next); }
        catch { setError("Use an assembly link from https://cad.onshape.com."); }
      }}>{busy ? "Checking assembly..." : "Check in FindEZ"}</button>
      <p className={styles.muted}>Only parts-list metadata is read. Your geometry stays in Onshape. Stock and the design are not changed.</p>
      <a href="/docs/cad#onshape">Onshape setup and CSV instructions</a>
      {error && <p role="alert">{error}</p>}
    </div>
    {result && <CadResults key={result.extraction_id} result={result} onRefresh={() => void check()} />}
  </section>;
}

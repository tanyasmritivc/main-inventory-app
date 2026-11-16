"use client";
import { useEffect, useRef, useState } from "react";
import { activeInventory } from "@/lib/inventory-selection";
import { accountRequest } from "@/lib/account-request";
import type { CadComparison } from "@/lib/cad";
import { CadResults } from "./cad-results";
import styles from "./cad.module.css";

type Version = { id: string; project_id: string; version: number; created_at: string; document: { name: string } };
export function CadHistory() {
  const inventory = activeInventory();
  return inventory ? <History key={`${inventory.accountId}:${inventory.inventory_id}`} inventory={inventory} /> : null;
}
function History({ inventory }: { inventory: NonNullable<ReturnType<typeof activeInventory>> }) {
  const [versions, setVersions] = useState<Version[] | null>(null);
  const [selected, setSelected] = useState<{ version: number; created_at: string; comparison: CadComparison } | null>(null);
  const [offset, setOffset] = useState(0);
  const [next, setNext] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const request = useRef<AbortController | null>(null);
  useEffect(() => () => request.current?.abort(), []);
  async function load(start = 0, id?: string) {
    if (!inventory || busy) return;
    const controller = new AbortController(); request.current = controller;
    setBusy(true); setError(""); setSelected(null);
    try {
      if (id) {
        const result = await accountRequest<{ inventory_id: string; version: number; created_at: string; comparison: CadComparison }>(inventory.accountId, `/cad/versions/${encodeURIComponent(id)}`, { signal: controller.signal });
        if (result.inventory_id !== inventory.inventory_id) throw new Error("The inventory changed. Reopen its history.");
        if (!controller.signal.aborted) setSelected(result);
      } else {
        const result = await accountRequest<{ inventory_id: string; versions: Version[]; next_offset: number | null }>(inventory.accountId, `/cad/versions?offset=${start}`, { signal: controller.signal });
        if (result.inventory_id !== inventory.inventory_id) throw new Error("The inventory changed. Reopen its history.");
        if (!controller.signal.aborted) { setVersions(result.versions); setOffset(start); setNext(result.next_offset); }
      }
    } catch (e) { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : "Saved versions could not be loaded."); }
    finally { if (!controller.signal.aborted) setBusy(false); }
  }
  return <section className={styles.preparation} aria-label="Saved BOM history"><h2>Saved BOM versions</h2><p>Save a version from the connected Fusion panel, then review it here with your team. Each version keeps the design metadata and inventory comparison as they were when saved.</p>
    <button disabled={busy} onClick={() => void load()}>Load saved versions</button>
    {error && <p role="alert">{error}</p>}
    {versions && !versions.length && <p>No BOM versions have been saved in this inventory.</p>}
    {versions && <ul>{versions.map(v => <li key={v.id}><button disabled={busy} onClick={() => void load(0, v.id)}>{v.document.name} / BOM {v.version} / {new Date(v.created_at).toLocaleString()}</button></li>)}</ul>}
    {offset > 0 && <button disabled={busy} onClick={() => void load(Math.max(0, offset - 50))}>Newer versions</button>}
    {next !== null && <button disabled={busy} onClick={() => void load(next)}>Older versions</button>}
    {selected && <><p><strong>Historical BOM {selected.version}.</strong> Saved {new Date(selected.created_at).toLocaleString()}. This is not current stock availability. Compare again in Fusion to refresh it.</p><button onClick={() => setSelected(null)}>Close saved version</button><CadResults key={selected.created_at} result={selected.comparison} onRefresh={() => {}} /></>}
  </section>;
}

"use client";
import { useEffect, useRef, useState } from "react";
import { activeInventory } from "@/lib/inventory-selection";
import { accountRequest } from "@/lib/account-request";
import type { CadComparison } from "@/lib/cad";
import { CadResults } from "./cad-results";
import { CadPlanning } from "./cad-planning";
import { CadPurchasing } from "./cad-purchasing";
import styles from "./cad.module.css";

type Version = { id: string; project_id: string; version: number; created_at: string; document: { name: string } };
export function CadHistory() {
  const inventory = activeInventory();
  return inventory ? <History key={`${inventory.accountId}:${inventory.inventory_id}`} inventory={inventory} /> : null;
}
function History({ inventory }: { inventory: NonNullable<ReturnType<typeof activeInventory>> }) {
  const [versions, setVersions] = useState<Version[] | null>(null);
  const [selected, setSelected] = useState<{ id: string; version: number; created_at: string; comparison: CadComparison } | null>(null);
  const [baseline, setBaseline] = useState("");
  const [diff, setDiff] = useState<{ name: string; before: number; after: number; delta: number; change: string; needs_review: boolean }[] | null>(null);
  const [offset, setOffset] = useState(0);
  const [next, setNext] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const request = useRef<AbortController | null>(null);
  useEffect(() => () => request.current?.abort(), []);
  async function load(start = 0, id?: string) {
    if (!inventory || busy) return;
    const controller = new AbortController(); request.current = controller;
    setBusy(true); setError(""); setSelected(null); setDiff(null); setBaseline("");
    try {
      if (id) {
        const result = await accountRequest<{ inventory_id: string; version: number; created_at: string; comparison: CadComparison }>(inventory.accountId, `/cad/versions/${encodeURIComponent(id)}`, { signal: controller.signal });
        if (result.inventory_id !== inventory.inventory_id) throw new Error("The inventory changed. Reopen its history.");
        if (!controller.signal.aborted) setSelected({ ...result, id });
      } else {
        const result = await accountRequest<{ inventory_id: string; versions: Version[]; next_offset: number | null }>(inventory.accountId, `/cad/versions?offset=${start}`, { signal: controller.signal });
        if (result.inventory_id !== inventory.inventory_id) throw new Error("The inventory changed. Reopen its history.");
        if (!controller.signal.aborted) { setVersions(result.versions); setOffset(start); setNext(result.next_offset); }
      }
    } catch (e) { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : "Saved versions could not be loaded."); }
    finally { if (!controller.signal.aborted) setBusy(false); }
  }
  async function compareVersions() {
    if (!selected || !baseline || busy) return;
    const controller = new AbortController(); request.current = controller;
    setBusy(true); setError(""); setDiff(null);
    try {
      const result = await accountRequest<{ inventory_id: string; changes: NonNullable<typeof diff> }>(inventory.accountId,
        `/cad/revision-diff?before=${encodeURIComponent(baseline)}&after=${encodeURIComponent(selected.id)}`, { signal: controller.signal });
      if (result.inventory_id !== inventory.inventory_id) throw new Error("The inventory changed. Reopen its history.");
      if (!controller.signal.aborted) setDiff(result.changes);
    } catch (e) { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : "Versions could not be compared."); }
    finally { if (!controller.signal.aborted) setBusy(false); }
  }
  return <section className={styles.preparation} aria-label="Saved BOM history"><h2>Saved BOM versions</h2><p>Save a version from the connected Fusion panel, then review it here with your team. Each version keeps the design metadata and inventory comparison as they were when saved.</p>
    <button disabled={busy} onClick={() => void load()}>Load saved versions</button>
    {error && <p role="alert">{error}</p>}
    {versions && !versions.length && <p>No BOM versions have been saved in this inventory.</p>}
    {versions && <ul>{versions.map(v => <li key={v.id}><button disabled={busy} onClick={() => void load(0, v.id)}>{v.document.name} / BOM {v.version} / {new Date(v.created_at).toLocaleString()}</button></li>)}</ul>}
    {offset > 0 && <button disabled={busy} onClick={() => void load(Math.max(0, offset - 50))}>Newer versions</button>}
    {next !== null && <button disabled={busy} onClick={() => void load(next)}>Older versions</button>}
    {selected && <><p><strong>Historical BOM {selected.version}.</strong> Saved {new Date(selected.created_at).toLocaleString()}. This is not current stock availability. Compare again in Fusion to refresh it.</p><button disabled={busy} onClick={() => { setSelected(null); setDiff(null); }}>Close saved version</button>
      <label>Compare requirements with <select disabled={busy} value={baseline} onChange={event => { setBaseline(event.target.value); setDiff(null); }}><option value="">Choose another version</option>{versions?.filter(v => v.id !== selected.id && v.project_id === versions.find(s => s.id === selected.id)?.project_id).map(v => <option key={v.id} value={v.id}>BOM {v.version} / {new Date(v.created_at).toLocaleString()}</option>)}</select></label>
      <button disabled={busy || !baseline} onClick={() => void compareVersions()}>Compare saved requirements</button>
      {diff && <div><p>Design quantity changes only. This does not refresh stock or check geometry and compatibility.</p>{diff.length ? <ul>{diff.map((row, i) => <li key={i}>{row.name}: {row.before} to {row.after} ({row.delta > 0 ? "+" : ""}{row.delta}){row.needs_review ? " / identity needs review" : ""}</li>)}</ul> : <p>No requirement quantity changes.</p>}</div>}
      <CadResults key={selected.created_at} result={selected.comparison} onRefresh={() => {}} /></>}
    {versions && versions.length > 0 && <CadPlanning versions={versions} />}
    <CadPurchasing versionId={selected?.id} />
  </section>;
}

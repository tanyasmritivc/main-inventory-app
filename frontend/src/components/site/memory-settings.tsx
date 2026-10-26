"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { activeInventory } from "@/lib/inventory-selection";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import styles from "./memory-settings.module.css";
import { ApiError } from "@/lib/api";

type Entry = { key: string; kind: string; payload: { value?: string; alias?: string; space_id?: string }; source: string; confirmed_at: string };
type Snapshot = { enabled: boolean; revision: number; entries: Entry[]; legacy: { key: string; value: string; state: string }[]; legacy_truncated: boolean };
export function MemorySettings({ accountId }: { accountId: string | null }) {
  const inventoryId = activeInventory()?.inventory_id;
  return <MemoryEditor key={`${accountId}:${inventoryId}`} accountId={accountId} inventoryId={inventoryId} />;
}
function MemoryEditor({ accountId, inventoryId }: { accountId: string | null; inventoryId?: string }) {
  const { confirmAction } = useAppDialog();
  const [data, setData] = useState<Snapshot>();
  const [spaces, setSpaces] = useState<{id:string;name:string}[]>([]);
  const [alias, setAlias] = useState(""), [spaceId, setSpaceId] = useState("");
  const [busy, setBusy] = useState(false), [error, setError] = useState(""), [notice, setNotice] = useState("");
  const epoch = useRef(0);
  const pending = useRef<Record<string, unknown> | null>(null), alive = useRef(true);
  const [hasPending, setHasPending] = useState(false);
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  const load = useCallback(async () => {
    if (!accountId) return;
    const generation=++epoch.current;
    setBusy(true); setError(""); setData(undefined); setSpaces([]);
    try {
      const next = await accountRequest<Snapshot>(accountId, "/memory" + (inventoryId ? `?inventory_id=${inventoryId}` : ""));
      if (!alive.current || generation!==epoch.current) return;
      if (!Array.isArray(next.entries) || typeof next.revision !== "number") throw new Error("Unavailable");
      setData(next);
      if (inventoryId) {
        const locations = await accountRequest<{spaces:{id:string;name:string}[]}>(accountId, `/inventories/${inventoryId}/spaces`);
        if (alive.current && generation===epoch.current) setSpaces(locations.spaces);
      }
    } catch { if (alive.current && generation===epoch.current) setError("Memory could not be loaded. Please try again."); }
    finally { if (alive.current && generation===epoch.current) setBusy(false); }
  }, [accountId, inventoryId]);
  useEffect(() => { void load(); }, [load]);
  async function write(values?: Record<string, unknown>) {
    if (!accountId || busy || (!data && !pending.current)) return;
    if (values && !data) return;
    if (values) pending.current = { operation_id: crypto.randomUUID(), expected_revision: data!.revision, ...values };
    if (!pending.current) return;
    epoch.current++;
    setBusy(true); setError(""); setNotice(""); setHasPending(true);
    try {
      const result = await accountRequest<{saved:boolean}>(accountId, "/memory", { method:"POST", body:pending.current });
      if (!alive.current) return;
      if (!result.saved) throw new Error("Unconfirmed");
      pending.current = null; setHasPending(false); setNotice("Memory saved.");
      await load();
    } catch (reason) {
      if (!alive.current) return;
      if (reason instanceof ApiError && [403,409,422].includes(reason.status)) {
        pending.current=null; setHasPending(false);
        setError(reason.status===409 ? "Memory changed. Refresh before trying again." : "That preference could not be saved. Refresh and check your access.");
      } else setError("The save could not be confirmed. Retry save uses the same request.");
    } finally { if (alive.current) setBusy(false); }
  }
  async function forget() {
    if (await confirmAction({title:"Forget personalization?",message:"This removes your saved preferences, aliases and unverified legacy memory. Your chats and inventory stay saved.",confirmLabel:"Forget",danger:true})) void write({action:"clear"});
  }
  async function exportMemory() {
    if (!accountId) return;
    setBusy(true); setError("");
    try {
      const result = await accountRequest<{partial:boolean}>(accountId,"/memory/export");
      if (!alive.current) return;
      const url=URL.createObjectURL(new Blob([JSON.stringify(result,null,2)],{type:"application/json"}));
      const link=document.createElement("a");link.href=url;link.download="findez-memory.json";link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
      setNotice(result.partial ? "Export downloaded. It is partial because older memory exceeded the export limit." : "Memory export downloaded.");
    } catch { if (alive.current) setError("Memory could not be exported. Please try again."); }
    finally { if (alive.current) setBusy(false); }
  }
  const blocked=busy || hasPending;
  return <section className={`settings-panel ${styles.panel}`} aria-label="Memory">
    <header><h2>Memory</h2><p>Save only the preferences you choose. Preferences are private to your account across devices.</p></header>
    {error && <p role="alert">{error}</p>}
    <p aria-live="polite">{busy ? "Loading or saving memory..." : notice}</p>
    <button type="button" className="product-button" disabled={busy} onClick={()=>void load()}>Refresh memory</button>
    {hasPending && <button type="button" className="product-button" disabled={busy} onClick={()=>void write()}>Retry save</button>}
    {data && <>
      <div className="settings-form-row"><label><input type="checkbox" checked={data.enabled} disabled={blocked} onChange={event=>void write({action:"settings",enabled:event.target.checked})}/> Use personalization</label></div>
      <p>Turning this off stops using preferences. It keeps them until you forget them.</p>
      {([['answer_length','Answer length',['brief','standard','detailed']],['answer_format','Answer format',['paragraphs','bullets']]] as const).map(([key,label,options])=><div className="settings-form-row" key={key}>
        <label htmlFor={`memory-${key}`}>{label}</label>
        <select id={`memory-${key}`} value={data.entries.find(entry=>entry.key===key)?.payload.value || ""} disabled={blocked || !data.enabled} onChange={event=>void write(event.target.value ? {action:"set",key,value:event.target.value} : {action:"delete",key})}>
          <option value="">Default</option>{options.map(value=><option key={value} value={value}>{value}</option>)}
        </select>
      </div>)}
      <ul>{data.entries.filter(entry=>entry.kind==='preference').map(entry=><li key={entry.key}>{entry.key.replaceAll('_',' ')}: {entry.payload.value}. {entry.source}. Saved {entry.confirmed_at.slice(0,10)}.</li>)}</ul>
      {inventoryId && <><h3>Location aliases</h3><p>Private names for saved locations in this inventory. An alias does not move any item.</p>
        <label htmlFor="memory-alias">Alias</label><input id="memory-alias" value={alias} maxLength={60} disabled={blocked || !data.enabled} onChange={event=>setAlias(event.target.value)}/>
        <label htmlFor="memory-space">Saved location</label><select id="memory-space" value={spaceId} disabled={blocked || !data.enabled} onChange={event=>setSpaceId(event.target.value)}><option value="">Choose a location</option>{spaces.map(space=><option key={space.id} value={space.id}>{space.name}</option>)}</select>
        <button className="product-button" disabled={blocked || !data.enabled || !alias.trim() || !spaceId} onClick={()=>void write({action:"set",inventory_id:inventoryId,alias:alias.trim(),space_id:spaceId})}>Save alias</button>
        {data.entries.filter(entry=>entry.kind==='alias').map(entry=><div key={entry.key}>{entry.payload.alias}: {spaces.find(space=>space.id===entry.payload.space_id)?.name || 'Unavailable location'} <button disabled={blocked} onClick={()=>void write({action:"delete",inventory_id:inventoryId,alias:entry.payload.alias})}>Forget alias</button></div>)}
      </>}
      {data.legacy.length>0 && <details><summary>Unverified legacy memory, excluded from personalization</summary>{data.legacy.map((entry,index)=><p key={index}>{entry.key}: {entry.value}</p>)}{data.legacy_truncated && <p>Only the first records are shown.</p>}</details>}
      <footer><button type="button" className="product-button" disabled={blocked} onClick={()=>void exportMemory()}>Export memory</button><button type="button" className="settings-text-button" disabled={blocked} onClick={()=>void forget()}>Forget personalization</button></footer>
    </>}
  </section>;
}

"use client";
import { usePermissionRefresh } from "@/lib/use-permission-refresh";
import { useCallback, useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { activeInventory } from "@/lib/inventory-selection";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import styles from "./memory-settings.module.css";
import { Sparkles, RefreshCw, Download, Trash2 } from "lucide-react";
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
  const load = useCallback(async (quiet = false) => {
    if (!accountId) return;
    const generation=++epoch.current;
    setBusy(true); setError(""); if (!quiet) { setData(undefined); setSpaces([]); }
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
  usePermissionRefresh(() => load(true), busy || hasPending || !!alias);
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
  return <section className={styles.panel} aria-label="Memory">
    <header className={styles.header}>
      <div className={styles.heading}><span className={styles.icon}><Sparkles size={21}/></span><div><h2>Make FindEZ yours</h2><p>Your preferences, synced privately across devices.</p></div></div>
      <button type="button" className={styles.refresh} disabled={busy} onClick={()=>void load()} aria-label="Refresh memory" title="Refresh memory"><RefreshCw size={17}/><span>Refresh memory</span></button>
    </header>
    {error && <p className={styles.feedback} role="alert">{error}</p>}
    {(busy || notice) && <p className={styles.feedback} role="status">{busy ? "Updating memory..." : notice}</p>}
    {hasPending && <div className={styles.feedback}><button type="button" className="product-button" disabled={busy} onClick={()=>void write()}>Retry save</button></div>}
    {data && <>
      <div className={styles.section}>
        <div className={styles.toggleRow}><div><label htmlFor="memory-enabled">Use personalization</label><p>Use your saved preferences in answers.</p></div><input id="memory-enabled" className={styles.toggle} type="checkbox" checked={data.enabled} disabled={blocked} onChange={event=>void write({action:"settings",enabled:event.target.checked})}/></div>
        {!data.enabled && <p className={styles.hint}>Paused. Your saved preferences are kept until you forget them.</p>}
      </div>
      <section className={styles.section} aria-labelledby="memory-response-title">
        <h3 id="memory-response-title">Response style</h3>
        <div className={styles.preferences}>
          {([['answer_length','Answer length',['brief','standard','detailed']],['answer_format','Answer format',['paragraphs','bullets']]] as const).map(([key,label,options])=><div className={styles.field} key={key}>
            <label htmlFor={`memory-${key}`}>{label}</label>
            <select id={`memory-${key}`} value={data.entries.find(entry=>entry.key===key)?.payload.value || ""} disabled={blocked || !data.enabled} onChange={event=>void write(event.target.value ? {action:"set",key,value:event.target.value} : {action:"delete",key})}>
              <option value="">Default</option>{options.map(value=><option key={value} value={value}>{value[0].toUpperCase()+value.slice(1)}</option>)}
            </select>
          </div>)}
        </div>
      </section>
      {inventoryId && <section className={styles.section} aria-labelledby="memory-alias-title"><h3 id="memory-alias-title">Location aliases</h3><p className={styles.hint}>Private names for saved locations. Items stay where they are.</p>
        <div className={styles.preferences}><div className={styles.field}><label htmlFor="memory-alias">Alias</label><input id="memory-alias" value={alias} maxLength={60} disabled={blocked || !data.enabled} onChange={event=>setAlias(event.target.value)}/></div>
        <div className={styles.field}><label htmlFor="memory-space">Saved location</label><select id="memory-space" value={spaceId} disabled={blocked || !data.enabled} onChange={event=>setSpaceId(event.target.value)}><option value="">Choose a location</option>{spaces.map(space=><option key={space.id} value={space.id}>{space.name}</option>)}</select></div></div>
        <button className={`product-button ${styles.saveAlias}`} disabled={blocked || !data.enabled || !alias.trim() || !spaceId} onClick={()=>void write({action:"set",inventory_id:inventoryId,alias:alias.trim(),space_id:spaceId})}>Save alias</button>
        {data.entries.filter(entry=>entry.kind==='alias').map(entry=><div className={styles.aliasRow} key={entry.key}><span><strong>{entry.payload.alias}</strong><small>{spaces.find(space=>space.id===entry.payload.space_id)?.name || 'Unavailable location'}</small></span><button className={styles.textButton} disabled={blocked} onClick={()=>void write({action:"delete",inventory_id:inventoryId,alias:entry.payload.alias})}>Forget alias</button></div>)}
      </section>}
      {data.legacy.length>0 && <details className={styles.section}><summary>Older memory</summary><p className={styles.hint}>Unverified and excluded from personalization.</p>{data.legacy.map((entry,index)=><p key={index}>{entry.key}: {entry.value}</p>)}{data.legacy_truncated && <p>Only the first records are shown.</p>}</details>}
      <footer className={styles.footer}><button type="button" className={styles.textButton} disabled={blocked} onClick={()=>void exportMemory()}><Download size={16}/>Export memory</button><button type="button" className={`${styles.textButton} ${styles.danger}`} disabled={blocked} onClick={()=>void forget()}><Trash2 size={16}/>Forget personalization</button></footer>
    </>}
  </section>;
}

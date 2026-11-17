"use client";
import { useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { activeInventory } from "@/lib/inventory-selection";
import styles from "./cad.module.css";
type Version = { id: string; project_id: string; version: number; document: { name: string } };
type Result = { inventory_id: string; note: string; inventory_as_of: string; warnings: string[];
  projects: { version_id: string; name: string; priority: number; required: number; assigned: number; missing: number; review_lines: number; items: { key: string; name: string; missing: number; status: string }[] }[];
  incoming: { plan_id: string; project: string; name: string; quantity: number }[] };
export function CadPlanning({ versions }: { versions: Version[] }) {
  const inventory=activeInventory();
  return inventory ? <Planning key={`${inventory.accountId}:${inventory.inventory_id}`} inventory={inventory} versions={versions} /> : null;
}
function Planning({ inventory,versions }: { inventory: NonNullable<ReturnType<typeof activeInventory>>; versions:Version[] }) {
  const [chosen,setChosen]=useState<Version[]>([]),[result,setResult]=useState<Result|null>(null),[error,setError]=useState("");
  const [busy,setBusy]=useState(false);const request=useRef<AbortController|null>(null),locked=useRef(false);
  useEffect(()=>()=>request.current?.abort(),[]);
  async function compare(){
    if(locked.current || !chosen.length)return;locked.current=true;setBusy(true);setError("");setResult(null);
    const controller=new AbortController();request.current=controller;
    try{const data=await accountRequest<Result>(inventory.accountId,"/cad/planning",{method:"POST",body:{version_ids:chosen.map(v=>v.id)},signal:controller.signal});
      if(data.inventory_id!==inventory.inventory_id)throw Error("Inventory changed. Reopen planning.");
      if(!controller.signal.aborted)setResult(data);
    }catch(e){if(!controller.signal.aborted)setError(e instanceof Error?e.message:"Planning could not be loaded.");}
    finally{locked.current=false;if(!controller.signal.aborted)setBusy(false);}
  }
  return <details className={styles.preparation}><summary>Plan multiple projects</summary><p>Choose one saved BOM per project. Earlier projects receive free stock first. Preview only; no reservations or purchases are made.</p>
    {versions.map(v=><label key={v.id} className={styles.permissionOption}><input type="checkbox" disabled={busy || (!chosen.some(c=>c.id===v.id) && (chosen.length>=20 || chosen.some(c=>c.project_id===v.project_id)))} checked={chosen.some(c=>c.id===v.id)} onChange={e=>{setChosen(current=>e.target.checked?[...current,v]:current.filter(c=>c.id!==v.id));setResult(null);}} />{v.document.name} / BOM {v.version}</label>)}
    <ol>{chosen.map((v,index)=><li key={v.id}>{v.document.name} / BOM {v.version} {index>0 && <button disabled={busy} onClick={()=>{setChosen(current=>{const next=[...current];[next[index-1],next[index]]=[next[index],next[index-1]];return next;});setResult(null);}}>Move earlier</button>} <button disabled={busy} onClick={()=>{setChosen(c=>c.filter(x=>x.id!==v.id));setResult(null);}}>Remove</button></li>)}</ol>
    <button disabled={busy || !chosen.length} onClick={()=>void compare()}>{busy?"Comparing…":"Compare shared stock"}</button>{error && <p role="alert">{error}</p>}
    {result && <div><p>{result.note}</p><p>Inventory read {new Date(result.inventory_as_of).toLocaleString()}</p>{result.warnings.map((w,i)=><p key={i}>{w}</p>)}
      {result.projects.map(p=><section key={p.version_id}><h3>{p.priority}. {p.name}</h3><p>{p.assigned} assigned / {p.required} required · {p.missing} unmatched · {p.review_lines} review lines</p><ul>{p.items.filter(l=>l.missing || l.status==="needs_review").map(l=><li key={l.key}>{l.name}: {l.missing} unmatched ({l.status.replaceAll("_"," ")})</li>)}</ul></section>)}
      <h3>On order — not on hand</h3>{result.incoming.length?<ul>{result.incoming.map((l,i)=><li key={i}>{l.name}: {l.quantity} units / {l.project}</li>)}</ul>:<p>No open incoming order lines.</p>}
    </div>}
  </details>;
}

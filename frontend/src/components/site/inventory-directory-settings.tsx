"use client";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import type { DirectoryInventory } from "@/lib/workspace-directory";
import { userFacingError } from "@/lib/user-facing-error";
export function InventoryDirectorySettings({inventoryId}:{inventoryId:string}) {
 const {accountId}=useApiSession();
 return <Settings key={`${accountId}:${inventoryId}`} inventoryId={inventoryId}/>;
}
function Settings({inventoryId}:{inventoryId:string}){
 const {accountId}=useApiSession();
 const [entry,setEntry]=useState<DirectoryInventory|null>(null),[visibility,setVisibility]=useState("workspace"),[description,setDescription]=useState(""),[error,setError]=useState(""),[busy,setBusy]=useState(false),[saved,setSaved]=useState(false);
 const live=useRef(true);
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 useEffect(()=>{if(!accountId)return;let active=true;
  void accountRequest<{inventory:DirectoryInventory}>(accountId,`/inventory-directory/${inventoryId}`).then(value=>{if(active){setEntry(value.inventory);setVisibility(value.inventory.directory_visibility||"workspace");setDescription(value.inventory.description||"");}}).catch(reason=>{if(active)setError(userFacingError(reason,"Directory settings could not be loaded."));});
  return()=>{active=false;};
 },[accountId,inventoryId]);
 async function submit(e:FormEvent){e.preventDefault();if(!accountId||busy)return;setBusy(true);setError("");setSaved(false);
  try{const result=await accountRequest<{inventory:DirectoryInventory}>(accountId,`/inventory-directory/${inventoryId}`,{method:"PATCH",body:{directory_visibility:visibility,description}});
   if(live.current){if(result.inventory?.inventory_id!==inventoryId)throw new Error("Settings could not be confirmed saved.");setEntry(result.inventory);setSaved(true);}
  }catch(reason){if(live.current)setError(userFacingError(reason,"Settings could not be saved."));}
  finally{if(live.current)setBusy(false);}
 }
 return <section>{error&&<p role="alert" className="notice-error">{error}</p>}{entry?entry.can_manage?<form className="inventory-directory-form" onSubmit={submit}>
  <label>Directory visibility<select className="product-select" value={visibility} onChange={e=>{setVisibility(e.target.value);setSaved(false);}}><option value="workspace">Visible to workspace members</option><option value="hidden">Hidden from members without access</option></select></label>
  <label>Directory description<textarea className="product-input" maxLength={500} rows={3} value={description} onChange={e=>{setDescription(e.target.value);setSaved(false);}}/></label>
  <p className="workspace-muted">The name and this description are shared in the workspace directory. Item records, quantities, documents and locations still require inventory access.</p>
  <button className="product-button" disabled={busy}>{busy?"Saving...":"Save directory settings"}</button>{saved&&<p role="status">Directory settings saved.</p>}
 </form>:<p className="workspace-muted">An inventory administrator manages directory visibility.</p>:!error&&<p role="status">Loading directory settings...</p>}</section>;
}

"use client";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { AppShell } from "@/components/site/app-shell";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";
import { workspaceNavigation } from "@/lib/context-navigation";
import { type InventoryWorkspace } from "@/lib/inventory-selection";
import type { DirectoryInventory } from "@/lib/workspace-directory";

type Request = {request_id:string;status:string;expires_at?:string};
type Entry = {inventory:DirectoryInventory;workspace:InventoryWorkspace;request:Request|null};
export function InventoryAccessRequest({ inventoryId }: {inventoryId:string}) {
 const {accountId}=useApiSession();
 return <RequestScreen key={`${accountId}:${inventoryId}`} inventoryId={inventoryId}/>;
}
function RequestScreen({inventoryId}:{inventoryId:string}) {
 const {accountId}=useApiSession();
 const [data,setData]=useState<Entry|null>(null),[error,setError]=useState(""),[busy,setBusy]=useState(false),[revision,setRevision]=useState(0);
 const live=useRef(true);
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 useEffect(()=>{
  if(!accountId)return;let active=true;
  void accountRequest<Entry>(accountId,`/inventory-directory/${encodeURIComponent(inventoryId)}`).then(value=>{if(active){setData(value);setError("");}}).catch(reason=>{if(active){setData(null);setError(userFacingError(reason,"This inventory is unavailable."));}});
  return()=>{active=false;};
 },[accountId,inventoryId,revision]);
 useEffect(()=>{const refresh=()=>setRevision(v=>v+1);window.addEventListener("focus",refresh);return()=>window.removeEventListener("focus",refresh);},[]);
 async function decide(cancel=false){
  if(!accountId||busy||!data)return;setBusy(true);setError("");
  try{
   const result=await accountRequest<{request:Request}>(accountId,cancel?`/inventory-access-requests/${data.request!.request_id}/decision`:`/inventory-directory/${encodeURIComponent(inventoryId)}/request`,{method:"POST",...(cancel?{body:{action:"cancel"}}:{})});
   if(!live.current)return;
   if(!result.request?.request_id||!result.request.status)throw new Error("The request could not be confirmed. Refresh before retrying.");
   setData({...data,request:result.request.status==="pending"?result.request:null});
  }catch(reason){if(live.current)setError(userFacingError(reason,"The request could not be saved."));}
  finally{if(live.current)setBusy(false);}
 }
 return <AppShell context={data?workspaceNavigation(data.workspace,"inventories"):undefined}><section className="product-page restricted-inventory">
  <header className="product-page-header"><h1>{data?.inventory.can_open?data.inventory.name:"Inventory access"}</h1></header>
  {error&&<p role="alert" className="notice-error">{error} <button className="product-button" onClick={()=>setRevision(v=>v+1)}>Retry</button></p>}
  {!data&&!error?<p role="status">Checking access...</p>:data&&<>
   {data.inventory.can_open?<Link className="product-button" href={`/home?inventory=${encodeURIComponent(inventoryId)}`}>Open inventory</Link>:<>
    <h2>{data.inventory.name}</h2>{data.inventory.description&&<p>{data.inventory.description}</p>}
    <p className="workspace-muted">Access restricted. Request permission to view this inventory.</p>
    {data.request?<><p role="status">Your request for viewer access is pending.</p><button className="product-button" disabled={busy} onClick={()=>setRevision(v=>v+1)}>Check access</button><button className="product-button" disabled={busy} onClick={()=>void decide(true)}>Cancel request</button></>:<><button className="product-button" disabled={busy} onClick={()=>void decide()}>{busy?"Sending...":"Request viewer access"}</button><p className="workspace-muted">An inventory administrator must approve. Requests expire after 7 days.</p></>}
   </>}
   <Link className="workspace-return" href={`/workspaces/${encodeURIComponent(data.workspace.workspace_id)}?view=inventories`}>Back to inventories</Link>
  </>}
  {!data&&error&&<Link href="/workspaces">Choose a workspace</Link>}
 </section></AppShell>;
}

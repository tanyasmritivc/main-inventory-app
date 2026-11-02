"use client";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";
import type { InventoryWorkspace } from "@/lib/inventory-selection";
import { directoryInventoryHref, type DirectoryInventory } from "@/lib/workspace-directory";

type Task={task_id:string;title:string;status:string;assigned_to?:string;due_at?:string};
const activityLabel=(action:string)=>({directory_approve:"Inventory access approved",directory_decline:"Access request declined",directory_cancel:"Access request cancelled",directory_request:"Inventory access requested",directory_settings:"Directory settings updated",inventory_location:"Inventory location updated",inventory_access:"Inventory permissions updated",inventory_member:"Inventory member updated",workspace_member:"Workspace member updated",inventory_create:"Inventory created"}[action]||action.replaceAll("_"," "));
type Activity={audit_id:string;action:string;created_at:string;inventory_id?:string};
export function WorkspaceOverview({workspace,inventories}:{workspace:InventoryWorkspace;inventories:DirectoryInventory[]}){
 const {accountId}=useApiSession();
 const [checkedAt,setCheckedAt]=useState(0);
 const [tasks,setTasks]=useState<Task[]>([]),[activity,setActivity]=useState<Activity[]>([]),[error,setError]=useState("");
 useEffect(()=>{
  if(!accountId)return;let live=true;
  void Promise.all([accountRequest<{tasks:Task[]}>(accountId,`/teams/${workspace.workspace_id}/board`),accountRequest<{activity:Activity[]}>(accountId,`/inventory-workspaces/${workspace.workspace_id}/audit`)]).then(([board,audit])=>{if(live){setCheckedAt(Date.now());setTasks(board.tasks);setActivity(audit.activity);setError("");}}).catch(reason=>{if(live)setError(userFacingError(reason,"The workspace overview could not be loaded."));});
  return()=>{live=false;};
 },[accountId,workspace.workspace_id]);
 const home=`/workspaces/${encodeURIComponent(workspace.workspace_id)}`;
 const assigned=tasks.filter(task=>task.assigned_to===accountId&&task.status!=="done").sort((a,b)=>(a.due_at||"9999").localeCompare(b.due_at||"9999")).slice(0,6);
 return <div className="workspace-overview">
  {error&&<p role="alert" className="notice-error">{error}</p>}
  <section><div className="workspace-section-heading"><h2>Inventories</h2><Link href={`${home}?view=inventories`}>View all</Link></div>
   <div className="directory-rows">{inventories.slice(0,6).map(inv=><Link className="directory-row" key={inv.inventory_id} href={directoryInventoryHref(inv)}><strong>{inv.name}</strong><span className="workspace-muted">{inv.can_open===false?"Access restricted":typeof inv.item_count==="number"?`${inv.item_count.toLocaleString()} items`:"Open inventory"}</span></Link>)}</div>
   {!inventories.length&&<p className="workspace-muted">No inventories yet.</p>}
  </section>
  <section><div className="workspace-section-heading"><h2>Your tasks</h2><Link href={`${home}?view=board`}>Tasks</Link></div>
   {assigned.length?<div className="directory-rows">{assigned.map(task=><Link className="directory-row" href={`${home}?view=board`} key={task.task_id}><strong>{task.title}</strong>{task.due_at&&<time dateTime={task.due_at} className={new Date(task.due_at).getTime()<checkedAt?"is-overdue":"workspace-muted"}>{new Date(task.due_at).getTime()<checkedAt?"Overdue · ":"Due "}{new Date(task.due_at).toLocaleDateString()}</time>}</Link>)}</div>:<p className="workspace-muted">No open tasks assigned to you.</p>}
  </section>
  <section><div className="workspace-section-heading"><h2>Recent inventory activity</h2><Link href={`${home}?view=activity`}>View history</Link></div>
   {activity.length?<div className="directory-rows">{activity.slice(0,5).map(row=><div className="directory-row" key={row.audit_id}><span>{activityLabel(row.action)}</span><time className="workspace-muted" dateTime={row.created_at}>{new Date(row.created_at).toLocaleDateString()}</time></div>)}</div>:<p className="workspace-muted">No recorded changes you can access.</p>}
  </section>
  <AccessRequests workspaceId={workspace.workspace_id}/>
 </div>;
}
type AccessRequest={request_id:string;inventory_name:string;requester_name:string;created_at:string};
export function AccessRequests({workspaceId}:{workspaceId:string}){
 const {accountId}=useApiSession();
 const [rows,setRows]=useState<AccessRequest[]>([]),[error,setError]=useState(""),[busy,setBusy]=useState(false),[revision,setRevision]=useState(0);
 const live=useRef(true);
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 useEffect(()=>{if(!accountId)return;let active=true;
  void accountRequest<{requests:AccessRequest[]}>(accountId,`/inventory-workspaces/${workspaceId}/access-requests`).then(value=>{if(active){setRows(value.requests);setError("");}}).catch(reason=>{if(active)setError(userFacingError(reason,"Access requests could not be loaded."));});
  return()=>{active=false;};
 },[accountId,workspaceId,revision]);
 async function decide(id:string,action:"approve"|"decline"){
  if(!accountId||busy)return;setBusy(true);setError("");
  try{const result=await accountRequest<{request:{request_id:string;status:string}}>(accountId,`/inventory-access-requests/${id}/decision`,{method:"POST",body:{action}});
   if(!live.current)return;
   if(result.request?.request_id!==id||!result.request.status||result.request.status==="pending")throw new Error("The decision could not be confirmed. Refresh before retrying.");
   setRows(current=>current.filter(row=>row.request_id!==id));setRevision(v=>v+1);
  }catch(reason){if(live.current)setError(userFacingError(reason,"The decision could not be saved."));}
  finally{if(live.current)setBusy(false);}
 }
 if(!rows.length&&!error)return null;
 return <section className="workspace-access-requests"><h2>Access requests</h2>{error&&<p role="alert" className="notice-error">{error} <button className="product-button" onClick={()=>setRevision(v=>v+1)}>Retry</button></p>}
  {rows.map(row=><div className="directory-row" key={row.request_id}><div><strong>{row.requester_name}</strong><p className="workspace-muted">Viewer access to {row.inventory_name}</p></div><div className="product-actions"><button className="product-button" disabled={busy} onClick={()=>void decide(row.request_id,"decline")}>Decline</button><button className="product-button" disabled={busy} onClick={()=>void decide(row.request_id,"approve")}>Approve viewer access</button></div></div>)}
 </section>;
}

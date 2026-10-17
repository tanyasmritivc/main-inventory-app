"use client";
import { useEffect, useRef, useState } from "react";
import { MoreHorizontal } from "lucide-react";
import { Dialog, DialogContent, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { RenameResourceDialog } from "./rename-resource-dialog";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
import styles from "./directory-design.module.css";
export function WorkspaceManagementActions({id,name,accountId,onRenamed,onDeleted}:{id:string;name:string;accountId:string;onRenamed:(name:string)=>void;onDeleted:()=>void}) {
 const [mode,setMode]=useState<"rename"|"delete"|null>(null);
 const opening=useRef(false);
 return <>
  <DropdownMenu modal={false}><DropdownMenuTrigger asChild><button className={styles.menuButton} aria-label={`Manage workspace ${name}`}><MoreHorizontal size={18}/></button></DropdownMenuTrigger>
   <DropdownMenuContent align="end" onCloseAutoFocus={e=>{if(opening.current){e.preventDefault();opening.current=false;}}}>
    <DropdownMenuItem onSelect={()=>{opening.current=true;setMode("rename");}}>Rename workspace</DropdownMenuItem>
    <DropdownMenuItem variant="destructive" onSelect={()=>{opening.current=true;setMode("delete");}}>Delete workspace</DropdownMenuItem>
   </DropdownMenuContent>
  </DropdownMenu>
  {mode==="rename"&&<RenameResourceDialog accountId={accountId} target={{kind:"workspace",id,name}} onClose={()=>setMode(null)} onSaved={saved=>{setMode(null);onRenamed(saved);}}/>}
  {mode==="delete"&&<DeleteWorkspaceDialog id={id} name={name} accountId={accountId} onClose={()=>setMode(null)} onDeleted={onDeleted}/>}
 </>;
}
export function DeleteWorkspaceDialog({id,name,accountId,onClose,onDeleted}:{id:string;name:string;accountId:string;onClose:()=>void;onDeleted:()=>void}) {
 const [entered,setEntered]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState("");
 const active=useRef(true),pending=useRef(false);
 useEffect(()=>()=>{active.current=false;},[]);
 async function remove(event:React.FormEvent){
  event.preventDefault();if(pending.current||entered!==name)return;pending.current=true;setBusy(true);setError("");
  try {
   const result=await accountRequest<{deleted:boolean}>(accountId,`/teams/${encodeURIComponent(id)}`,{method:"DELETE"});
   if(!active.current)return;
   if(result.deleted!==true)throw new Error("Deletion could not be confirmed. Refresh before retrying.");
   onDeleted();
  }catch(reason){if(active.current)setError(userFacingError(reason,"Could not delete workspace. Please try again."));}
  finally{pending.current=false;if(active.current)setBusy(false);}
 }
 return <Dialog open onOpenChange={open=>{if(!open&&!pending.current)onClose();}}><DialogContent className="workspace-dialog inventory-creation-dialog">
  <DialogTitle>Delete workspace</DialogTitle><DialogDescription>This removes collaboration, tasks and workspace files. Physical inventories are retained for their owners in Personal. This cannot be undone.</DialogDescription>
  <form onSubmit={remove}><label>Type {name} to confirm<input autoFocus className="product-input" value={entered} disabled={busy} onChange={e=>setEntered(e.target.value)}/></label>
   {error&&<p role="alert" className="notice-error">{error}</p>}
   <div className="product-actions"><button type="button" className="product-button" disabled={busy} onClick={onClose}>Cancel</button><button className="product-button" style={{color:"#b42318"}} disabled={busy||entered!==name}>{busy?"Deleting...":"Delete workspace"}</button></div>
  </form>
 </DialogContent></Dialog>;
}

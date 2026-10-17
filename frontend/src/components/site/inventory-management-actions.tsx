"use client";
import { useEffect, useRef, useState } from "react";
import { MoreHorizontal } from "lucide-react";
import { Dialog, DialogContent, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
import type { DirectoryInventory } from "@/lib/workspace-directory";
import styles from "./directory-design.module.css";
export function InventoryManagementActions({inventory,onRename,onDelete}:{inventory:DirectoryInventory;onRename:()=>void;onDelete:()=>void}) {
 const opening=useRef(false);
 return <div className={styles.actions}><DropdownMenu modal={false}>
  <DropdownMenuTrigger asChild><button className={styles.menuButton} aria-label={`Manage ${inventory.name}`}><MoreHorizontal size={18}/></button></DropdownMenuTrigger>
  <DropdownMenuContent align="end" onCloseAutoFocus={event=>{if(opening.current){event.preventDefault();opening.current=false;}}}>
   {inventory.can_rename&&<DropdownMenuItem onSelect={()=>{opening.current=true;onRename();}}>Rename</DropdownMenuItem>}
   {inventory.can_manage&&<DropdownMenuItem variant="destructive" onSelect={()=>{opening.current=true;onDelete();}}>Delete inventory</DropdownMenuItem>}
  </DropdownMenuContent>
 </DropdownMenu></div>;
}
export function DeleteInventoryDialog({inventory,accountId,onClose,onDeleted}:{inventory:DirectoryInventory;accountId:string;onClose:()=>void;onDeleted:(pending?:boolean)=>void}) {
 const [name,setName]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState(""),[deleteContents,setDeleteContents]=useState(false);
 const active=useRef(true);
 useEffect(()=>()=>{active.current=false;},[]);
 // Account-bound requests reject responses from a different session.
 async function remove(event:React.FormEvent){
  event.preventDefault();if(busy||name!==inventory.name)return;setBusy(true);setError("");
  try { const result=await accountRequest<{deleted:boolean;inventory_id:string;file_cleanup_pending?:boolean}>(accountId,`/inventories/${encodeURIComponent(inventory.inventory_id)}`,{method:"DELETE",body:{name,...(deleteContents?{delete_contents:true}:{})}});
   if(!active.current)return;
   if(!result.deleted||result.inventory_id!==inventory.inventory_id)throw new Error("Deletion was not confirmed. Refresh before retrying.");onDeleted(result.file_cleanup_pending);
  } catch(reason){if(active.current)setError(userFacingError(reason,"Deletion could not be confirmed. Refresh before retrying."));}
  finally{if(active.current)setBusy(false);}
 }
 return <Dialog open onOpenChange={open=>{if(!open&&!busy){active.current=false;onClose();}}}><DialogContent className="workspace-dialog inventory-creation-dialog">
  <DialogTitle>Delete inventory</DialogTitle><DialogDescription>Delete an empty inventory, or explicitly include all its saved contents. Other inventories are preserved.</DialogDescription>
  <form onSubmit={remove}><label style={{display:"flex",gap:10,alignItems:"start",marginBottom:16}}><input type="checkbox" checked={deleteContents} disabled={busy} onChange={event=>setDeleteContents(event.target.checked)}/>Also permanently delete everything in this inventory</label>{deleteContents&&<p role="note" style={{color:"#b42318",marginBottom:16}}>Items, Spaces, documents, photos and inventory conversations will be removed. This cannot be undone. Files still referenced elsewhere are retained.</p>}<label>Type {inventory.name} to confirm<input autoFocus className="product-input" value={name} onChange={event=>setName(event.target.value)} disabled={busy}/></label>
   {error&&<p role="alert" className="notice-error">{error}</p>}
   <div className="product-actions"><button type="button" className="product-button" disabled={busy} onClick={()=>{active.current=false;onClose();}}>Cancel</button><button className="product-button" disabled={busy||name!==inventory.name} style={{color:"#b42318"}}>{busy?"Deleting...":"Delete inventory"}</button></div>
  </form>
 </DialogContent></Dialog>;
}

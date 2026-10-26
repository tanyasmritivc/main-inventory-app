"use client";
import { ResourceRemovalDialog } from "./resource-removal-dialog";
import { useRef } from "react";
import { MoreHorizontal } from "lucide-react";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
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
 return <ResourceRemovalDialog kind="inventory" id={inventory.inventory_id} name={inventory.name} accountId={accountId} onClose={onClose} onDone={()=>onDeleted()}/>;
}

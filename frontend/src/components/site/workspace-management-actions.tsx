"use client";
import { ResourceRemovalDialog } from "./resource-removal-dialog";
import { useRef, useState } from "react";
import { MoreHorizontal } from "lucide-react";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { RenameResourceDialog } from "./rename-resource-dialog";
import styles from "./directory-design.module.css";
export function WorkspaceManagementActions({id,name,accountId,onRenamed,onDeleted,canDelete=true}:{id:string;name:string;accountId:string;onRenamed:(name:string)=>void;onDeleted:()=>void;canDelete?:boolean}) {
 const [mode,setMode]=useState<"rename"|"delete"|null>(null);
 const opening=useRef(false);
 return <>
  <DropdownMenu modal={false}><DropdownMenuTrigger asChild><button className={styles.menuButton} aria-label={`Manage workspace ${name}`}><MoreHorizontal size={18}/></button></DropdownMenuTrigger>
   <DropdownMenuContent align="end" onCloseAutoFocus={e=>{if(opening.current){e.preventDefault();opening.current=false;}}}>
    <DropdownMenuItem onSelect={()=>{opening.current=true;setMode("rename");}}>Rename workspace</DropdownMenuItem>
    {canDelete && <DropdownMenuItem variant="destructive" onSelect={()=>{opening.current=true;setMode("delete");}}>Delete workspace</DropdownMenuItem>}
   </DropdownMenuContent>
  </DropdownMenu>
  {mode==="rename"&&<RenameResourceDialog accountId={accountId} target={{kind:"workspace",id,name}} onClose={()=>setMode(null)} onSaved={saved=>{setMode(null);onRenamed(saved);}}/>}
  {mode==="delete"&&<DeleteWorkspaceDialog id={id} name={name} accountId={accountId} onClose={()=>setMode(null)} onDeleted={onDeleted}/>}
 </>;
}
export function DeleteWorkspaceDialog({id,name,accountId,onClose,onDeleted}:{id:string;name:string;accountId:string;onClose:()=>void;onDeleted:()=>void}) {
 return <ResourceRemovalDialog kind="workspace" id={id} name={name} accountId={accountId} onClose={onClose} onDone={onDeleted}/>;
}

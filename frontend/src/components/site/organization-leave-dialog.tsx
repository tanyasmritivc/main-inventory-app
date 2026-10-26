"use client";
import { useLayoutEffect, useRef, useState } from "react";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import { userFacingError } from "@/lib/user-facing-error";
import type { OrganizationTarget } from "./organization-delete-dialog";

export function OrganizationLeaveDialog({ accountId, organization, isOwner, onClose, onLeft }: {
 accountId: string; organization: OrganizationTarget; isOwner: boolean; onClose: () => void; onLeft: () => void;
}) {
 const [busy,setBusy]=useState(false), [error,setError]=useState("");
 const pending=useRef(false), live=useRef(true);
 useLayoutEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 async function leave() {
  if(pending.current || isOwner) return;
  pending.current=true;setBusy(true);setError("");
  try {
   const result=await accountRequest<{left:boolean;organization_id:string}>(accountId,`/organizations/${encodeURIComponent(organization.organization_id)}/leave`,{method:"DELETE",body:{name:organization.name}});
   if(!live.current)return;
   if(result.left!==true || result.organization_id!==organization.organization_id) throw new Error("Leaving could not be confirmed. Refresh before retrying.");
   onLeft();
  } catch(reason) {
   if(live.current) setError(reason instanceof ApiError && typeof reason.limitData==="string" ? reason.limitData : userFacingError(reason,"The organization could not be left."));
  } finally {pending.current=false;if(live.current)setBusy(false);}
 }
 return <Dialog open onOpenChange={open=>{if(!open&&!pending.current)onClose();}}><DialogContent className="workspace-dialog inventory-creation-dialog">
  <DialogTitle>Leave {organization.name}?</DialogTitle>
  <DialogDescription>{isOwner ? "Transfer organization ownership to another member before leaving." : "You will lose access to this organization and its workspaces, inventories and Spaces. The team's items, photos, tasks and files will stay. You will need an invitation to rejoin."}</DialogDescription>
  {error && <p role="alert" className="notice-error">{error}</p>}
  <div className="product-actions"><button className="product-button" disabled={busy} onClick={onClose}>{isOwner?"Close":"Cancel"}</button>{!isOwner&&<button className="product-button" disabled={busy} onClick={()=>void leave()}>{busy?"Leaving...":"Leave organization"}</button>}</div>
 </DialogContent></Dialog>;
}

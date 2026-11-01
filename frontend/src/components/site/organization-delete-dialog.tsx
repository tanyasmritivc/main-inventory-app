"use client";
import { ResourceRemovalDialog } from "./resource-removal-dialog";
export type OrganizationTarget = {organization_id:string;name:string};
export function OrganizationDeleteDialog({accountId,organization,onClose,onDeleted}:{accountId:string;organization:OrganizationTarget;onClose:()=>void;onDeleted:()=>void}) {
 return <ResourceRemovalDialog kind="organization" id={organization.organization_id} name={organization.name} accountId={accountId} onClose={onClose} onDone={onDeleted}/>;
}

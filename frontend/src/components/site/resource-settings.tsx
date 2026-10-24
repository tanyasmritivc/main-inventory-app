"use client";

import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { TransferOwnership } from "./transfer-ownership";

type Props = {
  scope: "organization" | "workspace"; id: string; name: string; role: string;
  ownerName?: string; organization?: { id: string; name: string };
  canRename: boolean; canTransfer: boolean; canDelete: boolean; isOwner: boolean;
  inheritedAdmin?: boolean;
  onRename: () => void; onDelete: () => void; onLeave: () => void; onTransferred: () => void;
};
export function ResourceSettings(props: Props) {
  const { scope, id, name, role, organization, canRename, canTransfer, canDelete, isOwner, inheritedAdmin } = props;
  const home = `/${scope === "organization" ? "organizations" : "workspaces"}/${encodeURIComponent(id)}`;
  const roleLabel = ({ mentor: "Admin", member: scope === "workspace" ? "Editor" : "Member" } as Record<string, string>)[role] || role.charAt(0).toUpperCase() + role.slice(1);
  const links = [
    { title: "People and invitations", text: "View members, manage roles and review pending invitations.", href: `${home}?view=people` },
    scope === "organization"
      ? { title: "Workspaces", text: "Manage the workspaces belonging to this organization.", href: home }
      : { title: "Inventories and access", text: "Open an inventory to manage its members and access settings.", href: home },
    ...(scope === "workspace" ? [
      { title: "Tasks and assignments", text: "Coordinate work and see who assigned each task.", href: `${home}?view=board` },
      { title: "Files", text: "Find and manage shared workspace files.", href: `${home}?view=files` },
      { title: "Activity", text: "Review changes recorded in this workspace.", href: `${home}?view=activity` },
      ...(["owner", "mentor"].includes(role) || inheritedAdmin ? [{ title: "Physical locations", text: "Organize shared locations within the workspace.", href: `${home}?view=locations` }] : []),
    ] : []),
  ];
  return <div className="resource-settings">
    <section className="resource-settings-card" aria-labelledby="resource-general">
      <header><h2 id="resource-general">General</h2><p>Details for this {scope}.</p></header>
      <div className="resource-setting-row"><div><span>Name</span><strong>{name}</strong></div>{canRename && <button className="product-button" onClick={props.onRename}>Rename {scope}</button>}</div>
      <div className="resource-setting-row"><div><span>Your access</span><strong>{roleLabel}</strong>{inheritedAdmin && <small>Includes organization administrator access.</small>}</div></div>
      {props.ownerName && <div className="resource-setting-row"><div><span>Owner</span><strong>{props.ownerName}</strong></div></div>}
      {organization && <div className="resource-setting-row"><div><span>Organization</span><Link href={`/organizations/${encodeURIComponent(organization.id)}`}>{organization.name}</Link></div></div>}
    </section>
    <section className="resource-settings-card" aria-labelledby="resource-access">
      <header><h2 id="resource-access">People and shared work</h2><p>{scope === "organization" ? "Members receive workspace access separately. Organization Owners and Admins can access every workspace and inventory." : "Viewers can read. Editors can update items and workspace details. Owners and Admins manage access and deletion."}</p></header>
      {links.map(link => <Link className="resource-setting-link" key={link.href} href={link.href}><span><strong>{link.title}</strong><small>{link.text}</small></span><ChevronRight size={18} aria-hidden="true" /></Link>)}
    </section>
    <section className="resource-settings-card" aria-labelledby="resource-ownership">
      <header><h2 id="resource-ownership">Ownership and leaving</h2><p>Review the consequences before making a change.</p></header>
      {canTransfer && <div className="resource-setting-row"><div><strong>Transfer ownership</strong><small>Choose an existing member and confirm the transfer.</small></div><TransferOwnership scope={scope} resourceId={id} name={name} onTransferred={props.onTransferred} /></div>}
      {isOwner ? <p className="resource-settings-note">Transfer ownership before leaving this {scope}.</p> : inheritedAdmin && scope === "workspace" ? <p className="resource-settings-note">Your workspace access comes from the organization. Manage your organization membership to leave.</p> : <div className="resource-setting-row"><div><strong>Leave {scope}</strong><small>Remove your membership. Shared content stays with the team.</small></div><button className="product-button" onClick={props.onLeave}>Leave {scope}</button></div>}
      {canDelete && <div className="resource-setting-row resource-danger"><div><strong>Delete {scope}</strong><small>Review affected content and choose whether to keep it elsewhere or delete it.</small></div><button className="product-button" onClick={props.onDelete}>Delete {scope}</button></div>}
    </section>
  </div>;
}

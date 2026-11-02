"use client";

import Link from "next/link";
import { MemberAvatar, MemberIdentityLabel, type MemberIdentity } from "./member-avatar";
import { usePermissionRefresh } from "@/lib/use-permission-refresh";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";
import type { InvitationDelivery } from "@/lib/access-invitation";
import { InvitationDeliveryDetails, PendingInvitations } from "@/components/site/access-invitation-tools";

type Member = MemberIdentity & { display_name: string; role: string; workspace_role?: string; override?: string; source?: string };
type Location = { location_id: string; name: string; parent_id: string | null };
type Access = {
  workspace?: { name: string; role: string; organization_id?: string; organization_role?: string };
  inventory?: { name: string; can_manage: boolean; access_mode?: string; default_role?: string; team_id: string | null };
  members: Member[]; candidates?: Member[]; locations: Location[];
};
const roleName = (role: string) => ({ mentor: "Admin", member: "Editor", none: "No access", inherit: "Use default" }[role] || role.charAt(0).toUpperCase() + role.slice(1));
export function locationPath(location: Location, locations: Location[]): string {
  const parts = [location.name], seen = new Set([location.location_id]);
  let parent = location.parent_id;
  while (parent && !seen.has(parent)) {
    seen.add(parent);
    const row = locations.find((entry) => entry.location_id === parent);
    if (!row) break;
    parts.unshift(row.name); parent = row.parent_id;
  }
  return parts.join(" / ");
}

export type CollaborationSection = "all" | "policy" | "people" | "locations" | "activity";
export function CollaborationPanel({ workspaceId, inventoryId, section = "all" }: { workspaceId?: string; inventoryId?: string; section?: CollaborationSection }) {
  const { accountId } = useApiSession();
  return <AccessPanel key={`${accountId}:${workspaceId}:${inventoryId}`} workspaceId={workspaceId} inventoryId={inventoryId} section={section} />;
}
function AccessPanel({ workspaceId, inventoryId, section }: { workspaceId?: string; inventoryId?: string; section: CollaborationSection }) {
  const { accountId } = useApiSession();
  const [data, setData] = useState<Access | null>(null), [error, setError] = useState("");
  const [revision, setRevision] = useState(0), [busy, setBusy] = useState(false);
  const [delivery, setDelivery] = useState<InvitationDelivery | null>(null);
  const [policy, setPolicy] = useState("workspace");
  const [memberId, setMemberId] = useState(""), [memberRole, setMemberRole] = useState("viewer");
  const [name, setName] = useState(""), [parent, setParent] = useState(""), [location, setLocation] = useState("");
  const [activity, setActivity] = useState<{ audit_id: string; action: string; actor_id: string; created_at: string; changes: { before?: { location?: string; quantity?: number }; after?: { location?: string; quantity?: number } } }[]>([]);
  const alive = useRef(true);
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  usePermissionRefresh(() => setRevision(v => v + 1), busy);
  const base = inventoryId ? `/inventories/${inventoryId}` : `/inventory-workspaces/${workspaceId}`;
  useEffect(() => {
    if (!accountId) return;
    let live = true;
    void accountRequest<Access>(accountId, `${base}/${inventoryId ? "access" : "overview"}`).then((result) => {
      if (!live) return;
      setData(result); setPolicy(result.inventory?.access_mode === "restricted" ? "restricted" : "workspace");
      setError("");
    }).catch((reason) => { if (live) { setData(null); setActivity([]); setDelivery(null); setError(userFacingError(reason, "Access could not be loaded.")); } });
    if (section === "all" || section === "activity") void accountRequest<{ activity: typeof activity }>(accountId, `${base}/audit`).then((result) => { if (live) setActivity(result.activity); }).catch((reason) => { if (live) { setActivity([]); setError(userFacingError(reason, "Activity could not be loaded.")); } });
    return () => { live = false; };
  }, [accountId, base, inventoryId, revision, section]);
  async function save(path: string, method: "POST" | "PUT" | "PATCH", body: Record<string, unknown>) {
    if (!accountId || busy) return;
    setBusy(true); setError(""); setDelivery(null);
    try {
      const result = await accountRequest<Partial<InvitationDelivery>>(accountId, path, { method, body });
      if (alive.current) { setRevision((v) => v + 1); setName(""); window.dispatchEvent(new Event("findez-permissions-changed")); if (result.invitation && result.code && result.invite_url) setDelivery(result as InvitationDelivery); }
    } catch (reason) { if (alive.current) setError(userFacingError(reason, "The change could not be saved.")); }
    finally { if (alive.current) setBusy(false); }
  }
  function submit(event: FormEvent, path: string, method: "POST" | "PUT" | "PATCH", body: Record<string, unknown>) { event.preventDefault(); void save(path, method, body); }
  const manager = inventoryId ? data?.inventory?.can_manage && data.inventory.team_id : ["owner", "mentor"].includes(data?.workspace?.role || "");
  const candidates = inventoryId ? data?.members : data?.candidates;
  const show = (value: CollaborationSection) => section === "all" || section === value;
  const existing = data?.members.find((m) => m.user_id === memberId);
  const invites = memberId && (!existing || existing.role === "none") && memberRole !== "none";
  return <div className={`collaboration-sections ${section !== "all" ? "context-single-section" : ""}`}>
    {error && <p role="alert" className="notice-error">{error} <button className="product-button" onClick={() => setRevision((v) => v + 1)}>Retry</button></p>}
    {!data ? !error && <p role="status">Loading access...</p> : <>
      {show("policy") && inventoryId && manager && <section>{section === "all" && <h2>Inventory access</h2>}
        <form className="collaboration-form" onSubmit={(e) => submit(e, `${base}/access`, "PATCH", { access_mode: policy, default_role: "viewer" })}>
          <label>Access<select className="product-select" value={policy} onChange={(e) => setPolicy(e.target.value)}><option value="workspace">Inherited workspace access</option><option value="restricted">Custom access</option></select></label>
          <button className="product-button" disabled={busy}>Save access</button>
        </form>
        <p className="workspace-muted">Inherited access follows each workspace role. Custom access requires individual assignments. Explicit roles and No access override workspace inheritance. Organization Owners and Admins always have access.</p>
      </section>}
      {show("policy") && inventoryId && !manager && <p className="workspace-muted">{!data.inventory?.team_id ? "This inventory is private to you." : data.inventory.access_mode === "restricted" ? "Access is assigned individually." : "Access follows this workspace's permissions."}</p>}
      {show("people") && <section>{section === "all" && <h2>{inventoryId ? "People with access" : "Workspace members"}</h2>}
        <div className="directory-rows">{data.members.filter((m) => m.role !== "none").map((member) => <div className="directory-row" key={member.user_id}>
          <span className="member-identity-label"><MemberAvatar member={member} />{member.display_name === "Member" ? `Member ${member.user_id.slice(0, 8)}` : member.display_name}</span><span>{roleName(member.role)}{inventoryId && member.source === "workspace" ? " · inherited" : ""}</span>
        </div>)}</div>
        {manager && (inventoryId || data.workspace?.organization_id) && <form className="collaboration-form" onSubmit={(e) => submit(e, `${base}/${inventoryId ? "access" : "members"}/${memberId}`, "PUT", { role: memberRole })}>
          <label>Member<select required className="product-select" value={memberId} onChange={(e) => setMemberId(e.target.value)}><option value="">Choose member</option>{candidates?.map((m) => <option key={m.user_id} value={m.user_id}>{m.display_name === "Member" ? `Member ${m.user_id.slice(0, 8)}` : m.display_name}</option>)}</select></label>
          <label>Role<select className="product-select" value={memberRole} onChange={(e) => setMemberRole(e.target.value)}>
            <option value="viewer">Viewer</option><option value="editor">Editor</option>{(inventoryId || (data.workspace?.role === "owner" || ["owner", "admin"].includes(data.workspace?.organization_role || ""))) && <option value="admin">Admin</option>}<option value="none">{inventoryId ? "No access" : "Remove from workspace"}</option>{inventoryId && <option value="inherit">Use workspace role</option>}
          </select></label><button className="product-button" disabled={busy || !memberId}>{invites ? "Send invitation" : "Save role"}</button>
        </form>}
        {delivery && <><InvitationDeliveryDetails delivery={delivery} />{memberId === accountId && <Link className="product-button" href={`/join/access?code=${encodeURIComponent(delivery.code)}`}>Review your access invitation</Link>}</>}
        {manager && <PendingInvitations scope={inventoryId ? "inventory" : "workspace"} resourceId={inventoryId || workspaceId!} revision={revision} />}
      </section>}
      {show("locations") && manager && <section>{section === "all" && <h2>Physical locations</h2>}
        {!inventoryId && <div className="directory-rows">{data.locations.map((loc) => <div className="directory-row" key={loc.location_id}>{locationPath(loc, data.locations)}</div>)}</div>}
        {inventoryId ? <form className="collaboration-form" onSubmit={(e) => submit(e, `${base}/locations`, "POST", { location_id: location })}>
          <label>Workspace location<select required className="product-select" value={location} onChange={(e) => setLocation(e.target.value)}><option value="">Choose location</option>{data.locations.map((loc) => <option key={loc.location_id} value={loc.location_id}>{locationPath(loc, data.locations)}</option>)}</select></label>
          <button className="product-button" disabled={busy || !location}>Add to inventory</button>
        </form> : <form className="collaboration-form" onSubmit={(e) => submit(e, `${base}/locations`, "POST", { name, parent_id: parent || null })}>
          <label>Name<input required maxLength={100} className="product-input" value={name} onChange={(e) => setName(e.target.value)} /></label>
          <label>Inside<select className="product-select" value={parent} onChange={(e) => setParent(e.target.value)}><option value="">Top level</option>{data.locations.map((loc) => <option key={loc.location_id} value={loc.location_id}>{locationPath(loc, data.locations)}</option>)}</select></label>
          <button className="product-button" disabled={busy || !name.trim()}>Add location</button>
        </form>}
      </section>}
      {show("locations") && !manager && <p className="workspace-muted">{inventoryId && !data.inventory?.team_id ? "Manage the locations in this inventory in Spaces." : "Workspace owners and admins manage shared locations."}</p>}
      {show("activity") && <section>{section === "all" && <h2>History</h2>}{activity.length ? <div className="directory-rows">{activity.map((entry) => <div className="collaboration-event" key={entry.audit_id}>
        <span>{entry.action.replaceAll("_", " ")}</span><time dateTime={entry.created_at}>{new Date(entry.created_at).toLocaleString()}</time>
        <small className="workspace-muted"><MemberIdentityLabel member={data.members.find((m) => m.user_id === entry.actor_id)} prefix="By " /></small>
        {entry.changes.after?.location !== undefined && <span>Recorded location: {entry.changes.after.location || "Not recorded"}</span>}
        {entry.changes.before?.quantity !== entry.changes.after?.quantity && entry.changes.after?.quantity !== undefined && <span>Quantity: {entry.changes.before?.quantity ?? "New"} → {entry.changes.after.quantity}</span>}
      </div>)}</div> : <p className="workspace-muted">No recorded changes yet.</p>}</section>}
    </>}
  </div>;
}

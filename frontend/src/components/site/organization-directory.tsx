"use client";
import Link from "next/link";
import { useEffect, useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { AppShell } from "@/components/site/app-shell";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { organizationNavigation, type OrganizationView } from "@/lib/context-navigation";
import { requireInventoryContext, selectInventory } from "@/lib/inventory-selection";
import { userFacingError } from "@/lib/user-facing-error";
type Org = { organization_id: string; name: string; role: string };
type Overview = { attachable?: { team_id: string; name: string }[]; organization: Org; workspaces: { team_id: string; name: string }[]; members: { user_id: string; display_name: string; role: string }[] };
export function OrganizationDirectory({ organizationId, view = "workspaces" }: { organizationId?: string; view?: OrganizationView }) {
 const { accountId } = useApiSession();
 return <Directory key={`${accountId}:${organizationId}:${view}`} organizationId={organizationId} view={view} />;
}
function Directory({ organizationId, view }: { organizationId?: string; view: OrganizationView }) {
 const { accountId, error: sessionError } = useApiSession(), router = useRouter();
 const [organizations, setOrganizations] = useState<Org[]>([]), [overview, setOverview] = useState<Overview | null>(null);
 const [query, setQuery] = useState("");
 const [mode, setMode] = useState<"organization" | "workspace" | "member" | "attach" | null>(null);
 const [existingWorkspace, setExistingWorkspace] = useState("");
 const [name, setName] = useState(""), [email, setEmail] = useState(""), [role, setRole] = useState("member");
 const [error, setError] = useState(""), [busy, setBusy] = useState(false), [loading, setLoading] = useState(true), [revision, setRevision] = useState(0);
 const live = useRef(true);
 useLayoutEffect(() => { requireInventoryContext(false); selectInventory(null); }, []);
 useEffect(() => { live.current = true; return () => { live.current = false; }; }, []);
 const base = organizationId ? `/organizations/${organizationId}` : "/organizations";
 useEffect(() => {
  if (!accountId) return;
  let active = true;
  void accountRequest<Overview & { organizations: Org[] }>(accountId, base).then((result) => { if (active) { if (organizationId) setOverview(result); else setOrganizations(result.organizations); setError(""); } }).catch((reason) => { if (active) setError(userFacingError(reason, "Organizations could not be loaded.")); }).finally(() => { if (active) setLoading(false); });
  return () => { active = false; };
 }, [accountId, base, organizationId, revision]);
 function open(value: NonNullable<typeof mode>) { setError(""); setName(""); setEmail(""); setRole("member"); setExistingWorkspace(""); setMode(value); }
 async function save(event: FormEvent) {
  event.preventDefault(); if (!accountId || busy || !mode) return; setBusy(true); setError("");
  try {
   const path = mode === "member" ? `${base}/members` : mode === "attach" ? `${base}/workspaces/${existingWorkspace}` : mode === "workspace" ? `${base}/workspaces` : base;
   const body = mode === "member" ? { email, role } : mode === "attach" ? undefined : { name };
   const result = await accountRequest<{ organization?: Org; workspace?: { team_id: string } }>(accountId, path, { method: "POST", ...(body ? { body } : {}) });
   if (!live.current) return;
   setMode(null); setRevision((v) => v + 1);
   if (mode === "workspace" && result.workspace) router.push(`/workspaces/${result.workspace.team_id}`);
   else if (mode === "organization" && result.organization) router.push(`/organizations/${result.organization.organization_id}`);
  } catch (reason) { if (live.current) setError(userFacingError(reason, "The change could not be saved.")); }
  finally { if (live.current) setBusy(false); }
 }
 async function removeMember(id: string) {
  if (!accountId || busy) return; setBusy(true); setError("");
  try { await accountRequest(accountId, `${base}/members/${id}`, { method: "DELETE" }); if (live.current) setRevision((v) => v + 1); }
  catch (reason) { if (live.current) setError(userFacingError(reason, "The member could not be removed.")); }
  finally { if (live.current) setBusy(false); }
 }
 const manager = overview && ["owner", "admin"].includes(overview.organization.role);
 const people = !!organizationId && view === "people";
 const matches = (value: string) => value.toLowerCase().includes(query.trim().toLowerCase());
 const context = organizationId ? organizationNavigation(organizationId, overview?.organization.name || "Organization", view) : undefined;
 return <AppShell context={context}><section className="product-page context-directory">
  <header className="product-page-header"><h1>{organizationId ? people ? "People" : "Workspaces" : "Organizations"}</h1><div className="product-actions">
   {!organizationId && <button className="product-button" onClick={() => open("organization")}>New organization</button>}
   {manager && <>{!people && !!overview?.attachable?.length && <button className="product-button" onClick={() => open("attach")}>Add existing workspace</button>}<button className="product-button" onClick={() => open(people ? "member" : "workspace")}>{people ? "Add member" : "New workspace"}</button></>}
  </div></header>
  {!mode && (error || sessionError) && <p role="alert" className="notice-error">{error || sessionError} <button className="product-button" onClick={() => setRevision((v) => v + 1)}>Retry</button></p>}
  <input className="product-input directory-search" type="search" aria-label={people ? "Search people" : organizationId ? "Search workspaces" : "Search organizations"} placeholder={people ? "Search people" : organizationId ? "Search workspaces" : "Search organizations"} value={query} onChange={(e) => setQuery(e.target.value)} />
  {loading ? <p role="status" className="workspace-muted">Loading...</p> : organizationId ? people ? <>
   <div className="context-people-list">{overview?.members.filter((m) => matches(m.display_name)).map((m) => <div className="context-person" key={m.user_id}><strong>{m.display_name === "Member" ? `Member ${m.user_id.slice(0,8)}` : m.display_name}</strong><span>{m.role.charAt(0).toUpperCase() + m.role.slice(1)}</span>{manager && m.role !== "owner" && (m.role !== "admin" || overview?.organization.role === "owner") && <button className="directory-rename" disabled={busy} onClick={() => void removeMember(m.user_id)}>Remove</button>}</div>)}</div>
   {!overview?.members.some((m) => matches(m.display_name)) && <p className="workspace-muted">No matching people.</p>}
  </> : <>
   <div className="context-card-grid">{overview?.workspaces.filter((ws) => matches(ws.name)).map((ws) => <Link className="context-card" href={`/workspaces/${ws.team_id}`} key={ws.team_id}><strong>{ws.name}</strong><span>Workspace</span></Link>)}</div>
   {!overview?.workspaces.some((ws) => matches(ws.name)) && <p className="workspace-muted">{query ? "No matching workspaces." : "No assigned workspaces yet."}</p>}
  </> : <>
   <div className="context-card-grid">{matches("Personal") && <Link className="context-card" href="/workspaces/personal"><strong>Personal</strong><span>Private inventory</span></Link>}{organizations.filter((org) => matches(org.name)).map((org) => <Link className="context-card" key={org.organization_id} href={`/organizations/${org.organization_id}`}><strong>{org.name}</strong><span>{org.role.charAt(0).toUpperCase() + org.role.slice(1)}</span></Link>)}</div>
   {query && !matches("Personal") && !organizations.some((org) => matches(org.name)) && <p className="workspace-muted">No matching organizations.</p>}
  </>}
  <Dialog open={mode !== null} onOpenChange={(value) => { if (!value && !busy) setMode(null); }}><DialogContent className="workspace-dialog inventory-creation-dialog" aria-describedby={undefined}>
   <DialogTitle>{mode === "member" ? "Add organization member" : mode === "attach" ? "Add existing workspace" : mode === "workspace" ? "New workspace" : "New organization"}</DialogTitle>
   <form onSubmit={save}>
    {mode === "member" ? <><label>Account email<input type="email" required className="product-input" value={email} onChange={(e) => setEmail(e.target.value)} /></label><label>Role<select className="product-select" value={role} onChange={(e) => setRole(e.target.value)}><option value="member">Member</option>{overview?.organization.role === "owner" && <option value="admin">Admin</option>}</select></label><p className="workspace-muted">Use an existing FindEZ account. Workspace access is assigned separately.</p></> : mode === "attach" ? <label>Workspace<select required className="product-select" value={existingWorkspace} onChange={(e) => setExistingWorkspace(e.target.value)}><option value="">Choose your workspace</option>{overview?.attachable?.map((ws) => <option key={ws.team_id} value={ws.team_id}>{ws.name}</option>)}</select></label> : <label>{mode === "workspace" ? "Workspace name" : "Organization name"}<input required maxLength={100} className="product-input" value={name} onChange={(e) => setName(e.target.value)} /></label>}
    {error && <p role="alert" className="notice-error">{error}</p>}
    <div className="product-actions"><button type="button" className="product-button" disabled={busy} onClick={() => setMode(null)}>Cancel</button><button className="product-button" disabled={busy || (mode === "member" ? !email.trim() : mode === "attach" ? !existingWorkspace : !name.trim())}>{busy ? "Saving..." : mode === "member" ? "Add member" : mode === "attach" ? "Add workspace" : mode === "workspace" ? "Create workspace" : "Create organization"}</button></div>
   </form>
  </DialogContent></Dialog>
 </section></AppShell>;
}

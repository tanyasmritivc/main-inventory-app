"use client";
import Link from "next/link";
import { useEffect, useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { AppThemeProvider } from "@/components/site/use-app-theme";
import { FindEZWordmark } from "@/components/site/findez-brand";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { requireInventoryContext, selectInventory } from "@/lib/inventory-selection";
import { userFacingError } from "@/lib/user-facing-error";
type Org = { organization_id: string; name: string; role: string };
type Overview = { attachable?: { team_id: string; name: string }[]; organization: Org; workspaces: { team_id: string; name: string }[]; members: { user_id: string; display_name: string; role: string }[] };
export function OrganizationDirectory({ organizationId }: { organizationId?: string }) {
 const { accountId } = useApiSession();
 return <Directory key={`${accountId}:${organizationId}`} organizationId={organizationId} />;
}
function Directory({ organizationId }: { organizationId?: string }) {
 const { accountId, error: sessionError } = useApiSession(), router = useRouter();
 const [organizations, setOrganizations] = useState<Org[]>([]), [overview, setOverview] = useState<Overview | null>(null);
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
 async function save(event: FormEvent, member = false) {
  event.preventDefault(); if (!accountId || busy) return; setBusy(true); setError("");
  try {
   const result = await accountRequest<{ organization?: Org; workspace?: { team_id: string } }>(accountId, `${base}${member ? "/members" : organizationId ? "/workspaces" : ""}`, { method: "POST", body: member ? { email, role } : { name } });
   if (!live.current) return;
   if (member) { setEmail(""); setRevision((v) => v + 1); }
   else if (result.workspace) router.push(`/workspaces/${result.workspace.team_id}`);
   else if (result.organization) router.push(`/organizations/${result.organization.organization_id}`);
  } catch (reason) { if (live.current) setError(userFacingError(reason, "The change could not be saved.")); }
  finally { if (live.current) setBusy(false); }
 }
 async function change(path: string, method: "POST" | "DELETE") {
  if (!accountId || busy) return; setBusy(true); setError("");
  try { await accountRequest(accountId,path,{method}); if (live.current) setRevision((v)=>v+1); }
  catch (reason) { if (live.current) setError(userFacingError(reason,"The change could not be saved.")); }
  finally { if (live.current) setBusy(false); }
 }
 const manager = overview && ["owner", "admin"].includes(overview.organization.role);
 return <AppThemeProvider><div className="app-frame workspace-directory">
  <header className="workspace-directory-header"><Link href="/organizations" aria-label="FindEZ organizations"><FindEZWordmark /></Link><nav aria-label="Organization"><Link href="/organizations">Organizations</Link>{overview && <><span>/</span><span>{overview.organization.name}</span></>}</nav><Link href="/settings" className="workspace-account">Account</Link></header>
  <main className="workspace-directory-main">
   <header className="product-page-header"><h1>{overview?.organization.name || "Organizations"}</h1><Link href="/workspaces">All my workspaces</Link></header>
   {(error || sessionError) && <p role="alert" className="notice-error">{error || sessionError} <button className="product-button" onClick={() => setRevision((v) => v + 1)}>Retry</button></p>}
   {loading ? <p role="status">Loading...</p> : organizationId ? <>
    <section><h2>Workspaces</h2><div className="directory-rows">{overview?.workspaces.map((ws) => <Link className="directory-row" href={`/workspaces/${ws.team_id}`} key={ws.team_id}><strong>{ws.name}</strong><span>Open</span></Link>)}</div>{!overview?.workspaces.length && <p className="workspace-muted">No assigned workspaces yet.</p>}</section>
    {manager && <form className="collaboration-form" onSubmit={(e) => save(e)}><label>Workspace name<input required maxLength={100} className="product-input" value={name} onChange={(e) => setName(e.target.value)} /></label><button className="product-button" disabled={busy || !name.trim()}>Create workspace</button></form>}
    {manager && !!overview?.attachable?.length && <form className="collaboration-form" onSubmit={(e)=>{e.preventDefault();void change(`${base}/workspaces/${existingWorkspace}`,"POST");}}><label>Existing workspace<select required className="product-select" value={existingWorkspace} onChange={(e)=>setExistingWorkspace(e.target.value)}><option value="">Choose your workspace</option>{overview.attachable.map((ws)=><option key={ws.team_id} value={ws.team_id}>{ws.name}</option>)}</select></label><button className="product-button" disabled={busy || !existingWorkspace}>Add workspace</button></form>}
    <section className="collaboration-sections"><h2>Organization members</h2><div className="directory-rows">{overview?.members.map((m) => <div className="directory-row" key={m.user_id}><span>{m.display_name} <small className="workspace-muted">· {m.user_id.slice(0, 8)}</small></span><span>{m.role}</span>{manager && m.role !== "owner" && (m.role !== "admin" || overview?.organization.role === "owner") && <button className="product-button" disabled={busy} onClick={()=>void change(`${base}/members/${m.user_id}`,"DELETE")}>Remove</button>}</div>)}</div>
     {manager && <form className="collaboration-form" onSubmit={(e) => save(e, true)}><label>Account email<input type="email" required className="product-input" value={email} onChange={(e) => setEmail(e.target.value)} /></label><label>Role<select className="product-select" value={role} onChange={(e) => setRole(e.target.value)}><option value="member">Member</option>{overview?.organization.role === "owner" && <option value="admin">Admin</option>}</select></label><button className="product-button" disabled={busy}>Add member</button></form>}
     {manager && <p className="workspace-muted">Use an existing FindEZ account. Workspace access is assigned separately.</p>}
    </section>
   </> : <><div className="directory-rows"><Link className="directory-row" href="/workspaces/personal"><strong>Personal</strong><span>Private inventory</span></Link>{organizations.map((org) => <Link className="directory-row" key={org.organization_id} href={`/organizations/${org.organization_id}`}><strong>{org.name}</strong><span>{org.role}</span></Link>)}</div>
    <form className="collaboration-form" onSubmit={(e) => save(e)}><label>Organization name<input required maxLength={100} className="product-input" value={name} onChange={(e) => setName(e.target.value)} /></label><button className="product-button" disabled={busy || !name.trim()}>Create organization</button></form>
   </>}
  </main>
 </div></AppThemeProvider>;
}

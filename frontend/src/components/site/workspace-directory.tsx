"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { AppShell } from "@/components/site/app-shell";
import { workspaceNavigation, type WorkspaceView } from "@/lib/context-navigation";
import { TeamsClient } from "@/components/site/teams-client";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { requireInventoryContext, selectInventory, type AppInventory, type InventoryWorkspace } from "@/lib/inventory-selection";
import { CollaborationPanel } from "@/components/site/collaboration-panel";
import { teamCategories } from "@/lib/team-categories";
import { userFacingError } from "@/lib/user-facing-error";

import { RenameResourceDialog, type RenameTarget } from "@/components/site/rename-resource-dialog";

import { WorkspaceOverview, AccessRequests } from "@/components/site/workspace-overview";
import { directoryInventoryHref, type DirectoryInventory } from "@/lib/workspace-directory";

import styles from "./directory-design.module.css";
import { InventoryManagementActions, DeleteInventoryDialog } from "./inventory-management-actions";

type InventoryPage = { workspace: InventoryWorkspace; inventories: DirectoryInventory[]; total: number; next_offset: number | null };
type SharedSpace = { share_id: string; share_name: string; team_shares?: SharedSpace | SharedSpace[] };

export function WorkspaceDirectory({ workspaceId, view = "inventories" }: { workspaceId?: string; view?: WorkspaceView }) {
  const { accountId } = useApiSession();
  return <WorkspaceDirectoryAccount key={`${accountId}:${workspaceId}:${view}`} workspaceId={workspaceId} view={workspaceId === "personal" ? "inventories" : view} />;
}
function WorkspaceDirectoryAccount({ workspaceId, view }: { workspaceId?: string; view: WorkspaceView }) {
  const { accountId, error: sessionError } = useApiSession(), router = useRouter();
  const [workspaces, setWorkspaces] = useState<InventoryWorkspace[]>([]);
  const [shared, setShared] = useState<SharedSpace[]>([]);
  const [page, setPage] = useState<InventoryPage | null>(null);
  const [query, setQuery] = useState(""), [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(true), [error, setError] = useState("");
  const [reload, setReload] = useState(0), [busy, setBusy] = useState(false);
  const [mode, setMode] = useState<"inventory" | "workspace" | "join" | "rename" | null>(null);
  const [renameWorkspace, setRenameWorkspace] = useState<RenameTarget | null>(null);
  const [deleting, setDeleting] = useState<DirectoryInventory | null>(null);
  const [renaming, setRenaming] = useState<DirectoryInventory | null>(null);
  const [joinKind, setJoinKind] = useState("workspace");
  const [name, setName] = useState(""), [category, setCategory] = useState(""), [customCategory, setCustomCategory] = useState(""), [code, setCode] = useState("");
  const actor = useRef(accountId);
  useLayoutEffect(() => { requireInventoryContext(false); selectInventory(null); }, []);
  useEffect(() => { actor.current = accountId; return () => { actor.current = null; }; }, [accountId]);
  useEffect(() => { setQuery(""); setOffset(0); setPage(null); }, [workspaceId]);
  useEffect(() => {
    if (!accountId) return;
    let live = true;
    setLoading(true); setError("");
    const timer = setTimeout(() => {
      const request = workspaceId
        ? accountRequest<InventoryPage>(accountId, `/inventory-workspaces/${encodeURIComponent(workspaceId)}/directory?q=${encodeURIComponent(query)}&offset=${offset}`).then((result) => { if (live) setPage(result); })
        : Promise.all([
          accountRequest<{ workspaces: InventoryWorkspace[] }>(accountId, "/inventory-workspaces"),
          accountRequest<{ shares: SharedSpace[] } | SharedSpace[]>(accountId, "/sharing/joined"),
        ]).then(([result, joined]) => {
          if (!live) return;
          setWorkspaces(result.workspaces);
          setShared((Array.isArray(joined) ? joined : joined.shares || []).flatMap((entry) => {
            const space = Array.isArray(entry.team_shares) ? entry.team_shares[0] : entry.team_shares || entry;
            return space?.share_id ? [space] : [];
          }));
        });
      void request.catch((reason) => { if (live) { setPage(null); setWorkspaces([]); setShared([]); setError(userFacingError(reason, "Could not load workspaces.")); } }).finally(() => { if (live) setLoading(false); });
    }, query ? 180 : 0);
    return () => { live = false; clearTimeout(timer); };
  }, [accountId, workspaceId, query, offset, reload]);

  function open(mode: "inventory" | "workspace" | "join" | "rename") {
    setName(mode === "inventory" && !page?.inventories.length ? (workspaceId === "personal" ? "My inventory" : "Inventory") : "");
    setRenaming(null); setCategory(""); setCustomCategory(""); setCode(""); setError(""); setMode(mode);
  }
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!accountId || !mode || busy) return;
    const account = accountId;
    setBusy(true); setError("");
    try {
      if (mode === "rename" && renaming) {
        const result = await accountRequest<{ inventory?: AppInventory }>(account, `/inventories/${encodeURIComponent(renaming.inventory_id)}`, { method: "PATCH", body: { name: name.trim() } });
        if (!result.inventory?.name || result.inventory.inventory_id !== renaming.inventory_id) throw new Error("The name could not be confirmed saved. Refresh before retrying.");
        if (actor.current === account) setReload((value) => value + 1);
      } else if (mode === "inventory" && workspaceId) {
        const result = await accountRequest<{ inventory: AppInventory }>(account, `/inventory-workspaces/${encodeURIComponent(workspaceId)}/inventories`, { method: "POST", body: { name } });
        if (!result.inventory?.inventory_id) throw new Error("The new inventory could not be confirmed. Refresh before retrying.");
        if (actor.current === account) { setQuery(""); setOffset(0); setReload(value=>value+1); }
      } else if (mode === "workspace") {
        const result = await accountRequest<{ team: { team_id: string } }>(account, "/teams", { method: "POST", body: { name, program: category, ...(category === "custom" ? { custom_category: customCategory } : {}) } });
        if (actor.current === account) router.push(`/workspaces/${encodeURIComponent(result.team.team_id)}`);
      } else if (joinKind === "space") {
        const result = await accountRequest<{ share_id: string }>(account, "/sharing/join", { method: "POST", body: { share_code: code } });
        if (actor.current === account) router.push(`/sharing/${encodeURIComponent(result.share_id)}`);
      } else {
        const result = await accountRequest<{ membership: { team_id: string } }>(account, "/teams/join", { method: "POST", body: { code } });
        if (actor.current === account) router.push(`/workspaces/${encodeURIComponent(result.membership.team_id)}`);
      }
      if (actor.current === account) setMode(null);
    } catch (reason) { if (actor.current === account) setError(userFacingError(reason, "That change could not be confirmed saved.")); }
    finally { if (actor.current === account) setBusy(false); }
  }

  const visible = workspaces.filter((workspace) => workspace.name.toLowerCase().includes(query.toLowerCase()));
  const canCreate = !workspaceId || page?.workspace.role === "owner" || page?.workspace.role === "mentor";
  const selectedWorkspace: InventoryWorkspace | null = workspaceId ? page?.workspace || { workspace_id: workspaceId, name: workspaceId === "personal" ? "Personal" : "Workspace", kind: workspaceId === "personal" ? "personal" : "team", team_id: workspaceId === "personal" ? null : workspaceId, role: "viewer" } : null;
  const titles = { overview: "Overview", settings: "Workspace settings", inventories: "Inventories", people: "People", locations: "Locations", board: "Tasks", files: "Files", activity: "Activity" };
  const choosing = !workspaceId || view === "inventories";
  return <div className={styles.shell}><AppShell context={selectedWorkspace ? workspaceNavigation(selectedWorkspace, view) : undefined}>
    <section className={`product-page context-directory ${styles.flow}`}>
      <header className="product-page-header"><div><span className={styles.eyebrow}>{workspaceId ? selectedWorkspace?.kind === "personal" ? "Personal" : "Workspace" : "Your workspaces"}</span><h1>{workspaceId && (choosing || view === "overview") ? page?.workspace.name || "Workspace" : workspaceId ? titles[view] : "All workspaces"}</h1></div>
        <div className="product-actions">
          {accountId && selectedWorkspace?.kind === "team" && selectedWorkspace.owner_user_id === accountId && <button className="directory-rename" onClick={() => setRenameWorkspace({kind:"workspace",id:selectedWorkspace.workspace_id,name:selectedWorkspace.name})}>Rename workspace</button>}
          {!workspaceId && <button className="product-button" onClick={() => open("join")}>Join workspace</button>}
          {(choosing || view === "overview") && canCreate && <button className="product-button" onClick={() => open(workspaceId ? "inventory" : "workspace")}>New {workspaceId ? "inventory" : "workspace"}</button>}
        </div>
      </header>
      {workspaceId && choosing && <h2 style={{fontSize:15,fontWeight:500,marginBottom:16}}>Inventories</h2>}
      {choosing && <input className="product-input directory-search" type="search" aria-label={workspaceId ? "Search inventories" : "Search workspaces"} placeholder={workspaceId ? "Search inventories" : "Search workspaces"} value={query} onChange={(event) => { setQuery(event.target.value); setOffset(0); }} />}
      {!mode && (error || sessionError) && <div role="alert" className="notice-error">{error || sessionError} <button className="product-button" onClick={() => setReload((value) => value + 1)}>Retry</button></div>}
      {loading ? <p className="workspace-muted" role="status">Loading...</p> : choosing ? <>
        <div className="context-card-grid">
          {workspaceId ? page?.inventories.map((inventory) => <div className="context-card context-inventory-card" key={inventory.inventory_id}>
            <Link className="context-card-link" href={directoryInventoryHref(inventory)}><strong>{inventory.name}</strong>{inventory.description && <span className="directory-description">{inventory.description}</span>}<span>{inventory.can_open === false ? "Access restricted" : typeof inventory.item_count === "number" ? `${inventory.item_count.toLocaleString()} items` : "Open inventory"}</span></Link>
            {(inventory.can_rename || inventory.can_manage) && <InventoryManagementActions inventory={inventory} onRename={() => { open("rename"); setRenaming(inventory); setName(inventory.name); }} onDelete={()=>setDeleting(inventory)} />}
          </div>) : visible.map((workspace) => <div className="context-card context-inventory-card" key={workspace.workspace_id}><Link className="context-card-link" href={`/workspaces/${encodeURIComponent(workspace.workspace_id)}`}>
            <strong>{workspace.name}</strong><span>{workspace.kind === "personal" ? "Private" : workspace.organization_name || (workspace.role === "viewer" ? "View only" : "Workspace")}</span>
          </Link>{accountId && workspace.kind === "team" && workspace.owner_user_id === accountId && <button className="directory-rename" aria-label={`Rename ${workspace.name}`} onClick={() => setRenameWorkspace({kind:"workspace",id:workspace.workspace_id,name:workspace.name})}>Rename</button>}</div>)}
        </div>
        {workspaceId && !page?.inventories.length && !error && <div className={styles.empty}><h2>{query ? "No matching inventories" : "No inventories yet"}</h2><p>{query ? "Try another name." : canCreate ? "Create a collection for this workspace." : "An inventory will appear here when shared with you."}</p>{canCreate && !query && <button className="product-button" onClick={()=>open("inventory")}>Create inventory</button>}</div>}
        {!workspaceId && !visible.length && !error && <p className="workspace-muted">No matching workspaces.</p>}
        {workspaceId && page && (offset > 0 || page.next_offset !== null) && <nav className="directory-pagination" aria-label="Inventory pages">
          <button className="product-button" disabled={!offset} onClick={() => setOffset(Math.max(0, offset - 100))}>Previous</button>
          <span className="workspace-muted">{offset + 1}-{offset + page.inventories.length} of {page.total}</span>
          <button className="product-button" disabled={page.next_offset === null} onClick={() => setOffset(page.next_offset!)}>Next</button>
        </nav>}
        {!workspaceId && shared.length > 0 && <section className="directory-shared"><h2>Shared with me</h2><div className="context-card-grid">
          {shared.filter((space) => space.share_name.toLowerCase().includes(query.toLowerCase())).map((space) => <Link className="context-card" href={`/sharing/${encodeURIComponent(space.share_id)}`} key={space.share_id}><strong>{space.share_name}</strong><span>Shared Space</span></Link>)}
        </div></section>}
      </> : workspaceId && page && <>
        {view === "overview" ? <WorkspaceOverview workspace={page.workspace} inventories={page.inventories} /> : view === "settings" ? <section className="workspace-settings"><dl className="directory-rows"><div className="directory-row"><dt>Name</dt><dd>{page.workspace.name}</dd></div><div className="directory-row"><dt>Your role</dt><dd>{page.workspace.role === "mentor" ? "Admin" : page.workspace.role.charAt(0).toUpperCase() + page.workspace.role.slice(1)}</dd></div></dl><Link className="workspace-return" href={`/workspaces/${encodeURIComponent(workspaceId)}?view=people`}>Members, invitations and access requests</Link></section> : <>
        {(view === "board" || view === "files" || (view === "people" && !page.workspace.organization_id)) ? <TeamsClient selectedTeamId={workspaceId} panel={view === "people" ? "people" : view === "files" ? "files" : "board"} /> : <CollaborationPanel workspaceId={workspaceId} section={view === "people" ? "people" : view === "locations" ? "locations" : "activity"} />}
        {view === "people" && <AccessRequests workspaceId={workspaceId} />}
        </>}
      </>}
    </section>
    {accountId && deleting && <DeleteInventoryDialog key={deleting.inventory_id} inventory={deleting} accountId={accountId} onClose={()=>setDeleting(null)} onDeleted={()=>{setDeleting(null);setReload(value=>value+1);}} />}
    {accountId && renameWorkspace && <RenameResourceDialog key={renameWorkspace.id} accountId={accountId} target={renameWorkspace} onClose={() => setRenameWorkspace(null)} onSaved={(savedName) => {
      setWorkspaces((rows) => rows.map((ws) => ws.workspace_id === renameWorkspace.id ? {...ws,name:savedName} : ws));
      setPage((current) => current ? {...current,workspace:{...current.workspace,name:savedName}} : current);
      setRenameWorkspace(null); setReload((value) => value + 1);
    }} />}
    <Dialog open={mode !== null} onOpenChange={(value) => { if (!value && !busy) setMode(null); }}><DialogContent className="workspace-dialog inventory-creation-dialog" aria-describedby={undefined}>
      <DialogTitle>{mode === "join" ? "Join workspace" : mode === "inventory" ? "New inventory" : mode === "rename" ? "Rename inventory" : "New workspace"}</DialogTitle>
      <form onSubmit={submit}>
        {mode === "join" ? <><label>Invitation type<select className="product-select" value={joinKind} onChange={(event) => setJoinKind(event.target.value)}><option value="workspace">Workspace</option><option value="space">Shared Space</option></select></label><label>Invitation code<input className="product-input" autoFocus required maxLength={6} value={code} onChange={(event) => setCode(event.target.value.toUpperCase())} /></label></> : <>
          <label>Name<input className="product-input" autoFocus required maxLength={100} value={name} onChange={(event) => setName(event.target.value)} /></label>
          {mode === "workspace" && <label>Category<select className="product-select" required value={category} onChange={(event) => setCategory(event.target.value)}><option value="">Choose category</option>{teamCategories.map((value) => <option key={value.value} value={value.value}>{value.label}</option>)}</select></label>}
          {mode === "workspace" && category === "custom" && <label>Custom category<input className="product-input" required maxLength={60} value={customCategory} onChange={(event) => setCustomCategory(event.target.value)} /></label>}
        </>}
        {error && <p role="alert" className="notice-error">{error}</p>}
        <div className="product-actions"><button type="button" className="product-button" disabled={busy} onClick={() => setMode(null)}>Cancel</button><button className="product-button" disabled={busy || (mode === "join" ? !code.trim() : !name.trim())}>{busy ? "Saving..." : mode === "join" ? "Join" : mode === "rename" ? "Save" : "Create"}</button></div>
      </form>
    </DialogContent></Dialog>
  </AppShell></div>;
}

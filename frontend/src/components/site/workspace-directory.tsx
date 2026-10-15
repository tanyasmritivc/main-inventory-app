"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { AppThemeProvider } from "@/components/site/use-app-theme";
import { FindEZWordmark } from "@/components/site/findez-brand";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { requireInventoryContext, selectInventory, type AppInventory, type InventoryWorkspace } from "@/lib/inventory-selection";
import { teamCategories } from "@/lib/team-categories";
import { userFacingError } from "@/lib/user-facing-error";

type InventoryPage = { workspace: InventoryWorkspace; inventories: AppInventory[]; total: number; next_offset: number | null };
type SharedSpace = { share_id: string; share_name: string; team_shares?: SharedSpace | SharedSpace[] };

export function WorkspaceDirectory({ workspaceId }: { workspaceId?: string }) {
  const { accountId } = useApiSession();
  return <WorkspaceDirectoryAccount key={accountId || "signed-out"} workspaceId={workspaceId} />;
}
function WorkspaceDirectoryAccount({ workspaceId }: { workspaceId?: string }) {
  const { accountId, error: sessionError } = useApiSession(), router = useRouter();
  const [workspaces, setWorkspaces] = useState<InventoryWorkspace[]>([]);
  const [shared, setShared] = useState<SharedSpace[]>([]);
  const [page, setPage] = useState<InventoryPage | null>(null);
  const [query, setQuery] = useState(""), [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(true), [error, setError] = useState("");
  const [reload, setReload] = useState(0), [busy, setBusy] = useState(false);
  const [mode, setMode] = useState<"inventory" | "workspace" | "join" | "rename" | null>(null);
  const [renaming, setRenaming] = useState<AppInventory | null>(null);
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
        ? accountRequest<InventoryPage>(accountId, `/inventory-workspaces/${encodeURIComponent(workspaceId)}/inventories?q=${encodeURIComponent(query)}&offset=${offset}`).then((result) => { if (live) setPage(result); })
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
      void request.catch((reason) => { if (live) setError(userFacingError(reason, "Could not load workspaces.")); }).finally(() => { if (live) setLoading(false); });
    }, query ? 180 : 0);
    return () => { live = false; clearTimeout(timer); };
  }, [accountId, workspaceId, query, offset, reload]);

  function open(mode: "inventory" | "workspace" | "join" | "rename") {
    setName(mode === "inventory" && !page?.inventories.length ? (workspaceId === "personal" ? "My inventory" : "Inventory") : "");
    setRenaming(null); setCategory(""); setCustomCategory(""); setCode(""); setError(""); setMode(mode);
  }
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!accountId || !mode) return;
    const account = accountId;
    setBusy(true); setError("");
    try {
      if (mode === "rename" && renaming) {
        await accountRequest(account, `/inventories/${encodeURIComponent(renaming.inventory_id)}`, { method: "PATCH", body: { name } });
        if (actor.current === account) setReload((value) => value + 1);
      } else if (mode === "inventory" && workspaceId) {
        const result = await accountRequest<{ inventory: AppInventory }>(account, `/inventory-workspaces/${encodeURIComponent(workspaceId)}/inventories`, { method: "POST", body: { name } });
        if (actor.current === account) router.push(`/home?inventory=${encodeURIComponent(result.inventory.inventory_id)}`);
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
  return <AppThemeProvider><div className="app-frame workspace-directory">
    <header className="workspace-directory-header">
      <Link href="/workspaces" aria-label="FindEZ workspaces"><FindEZWordmark /></Link>
      {workspaceId && <nav aria-label="Workspace"><Link href="/workspaces">Workspaces</Link><span aria-hidden="true">/</span><span>{page?.workspace.name || (workspaceId === "personal" ? "Personal" : "Workspace")}</span></nav>}
      <Link href="/settings" className="workspace-account">Account</Link>
    </header>
    <main className="workspace-directory-main">
      <header className="product-page-header"><h1>{workspaceId ? "Inventories" : "Workspaces"}</h1>
        <div className="product-actions">
          {workspaceId && page?.workspace.kind === "team" && <Link className="product-button" href={`/teams?team=${encodeURIComponent(workspaceId)}`}>Manage workspace</Link>}
          {!workspaceId && <button className="product-button" onClick={() => open("join")}>Join workspace</button>}
          {canCreate && <button className="product-button" onClick={() => open(workspaceId ? "inventory" : "workspace")}>New {workspaceId ? "inventory" : "workspace"}</button>}
        </div>
      </header>
      <input className="product-input directory-search" type="search" aria-label={workspaceId ? "Search inventories" : "Search workspaces"} placeholder={workspaceId ? "Search inventories" : "Search workspaces"} value={query} onChange={(event) => { setQuery(event.target.value); setOffset(0); }} />
      {(error || sessionError) && <div role="alert" className="notice-error">{error || sessionError} <button className="product-button" onClick={() => setReload((value) => value + 1)}>Retry</button></div>}
      {loading ? <p className="workspace-muted" role="status">Loading...</p> : <>
        <div className="directory-rows">
          {workspaceId ? page?.inventories.map((inventory) => <div className="directory-row" key={inventory.inventory_id}>
            <Link className="directory-inventory-link" href={`/home?inventory=${encodeURIComponent(inventory.inventory_id)}`}><strong>{inventory.name}</strong><span>{(inventory.item_count ?? 0).toLocaleString()} items</span></Link>
            {canCreate && <button className="directory-rename" aria-label={`Rename ${inventory.name}`} onClick={() => { open("rename"); setRenaming(inventory); setName(inventory.name); }}>Rename</button>}
          </div>) : visible.map((workspace) => <Link className="directory-row" key={workspace.workspace_id} href={`/workspaces/${encodeURIComponent(workspace.workspace_id)}`}>
            <strong>{workspace.name}</strong><span>{workspace.kind === "personal" ? "Private" : workspace.role === "viewer" ? "View only" : "Team"}</span>
          </Link>)}
        </div>
        {workspaceId && !page?.inventories.length && !error && <p className="workspace-muted">{query ? "No matching inventories." : "No inventories yet."}</p>}
        {!workspaceId && !visible.length && !error && <p className="workspace-muted">No matching workspaces.</p>}
        {workspaceId && page && (offset > 0 || page.next_offset !== null) && <nav className="directory-pagination" aria-label="Inventory pages">
          <button className="product-button" disabled={!offset} onClick={() => setOffset(Math.max(0, offset - 100))}>Previous</button>
          <span className="workspace-muted">{offset + 1}-{offset + page.inventories.length} of {page.total}</span>
          <button className="product-button" disabled={page.next_offset === null} onClick={() => setOffset(page.next_offset!)}>Next</button>
        </nav>}
        {!workspaceId && shared.length > 0 && <section className="directory-shared"><h2>Shared with me</h2><div className="directory-rows">
          {shared.filter((space) => space.share_name.toLowerCase().includes(query.toLowerCase())).map((space) => <Link className="directory-row" href={`/sharing/${encodeURIComponent(space.share_id)}`} key={space.share_id}><strong>{space.share_name}</strong><span>Shared Space</span></Link>)}
        </div></section>}
      </>}
    </main>
    <Dialog open={mode !== null} onOpenChange={(value) => { if (!value && !busy) setMode(null); }}><DialogContent className="workspace-dialog inventory-creation-dialog" aria-describedby={undefined}>
      <DialogTitle>{mode === "join" ? "Join workspace" : mode === "inventory" ? "New inventory" : mode === "rename" ? "Rename inventory" : "New workspace"}</DialogTitle>
      <form onSubmit={submit}>
        {mode === "join" ? <><label>Invitation type<select className="product-select" value={joinKind} onChange={(event) => setJoinKind(event.target.value)}><option value="workspace">Workspace</option><option value="space">Shared Space</option></select></label><label>Invitation code<input className="product-input" autoFocus required maxLength={6} value={code} onChange={(event) => setCode(event.target.value.toUpperCase())} /></label></> : <>
          <label>Name<input className="product-input" autoFocus required maxLength={100} value={name} onChange={(event) => setName(event.target.value)} /></label>
          {mode === "workspace" && <label>Category<select className="product-select" required value={category} onChange={(event) => setCategory(event.target.value)}><option value="">Choose category</option>{teamCategories.map((value) => <option key={value.value} value={value.value}>{value.label}</option>)}</select></label>}
          {mode === "workspace" && category === "custom" && <label>Custom category<input className="product-input" required maxLength={60} value={customCategory} onChange={(event) => setCustomCategory(event.target.value)} /></label>}
        </>}
        {error && <p role="alert" className="notice-error">{error}</p>}
        <button className="product-button" disabled={busy || (mode === "join" ? !code.trim() : !name.trim())}>{busy ? "Saving..." : mode === "join" ? "Join" : mode === "rename" ? "Save" : "Create"}</button>
      </form>
    </DialogContent></Dialog>
  </div></AppThemeProvider>;
}

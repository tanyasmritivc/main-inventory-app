"use client";

import { useEffect, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import type { AppInventory, InventorySelection, InventoryWorkspace } from "@/lib/inventory-selection";
import { userFacingError } from "@/lib/user-facing-error";
import { InventoryCommerce } from "./commerce-client";
import styles from "./settings-connections.module.css";

export function SettingsConnections() {
  const { accountId, loading, error } = useApiSession();
  if (loading) return <p role="status">Loading your account...</p>;
  if (error || !accountId) return <p role="alert">{error || "Sign in to manage connections."}</p>;
  return <AccountConnections key={accountId} accountId={accountId} />;
}

function AccountConnections({ accountId }: { accountId: string }) {
  const [workspaces, setWorkspaces] = useState<InventoryWorkspace[] | null>(null);
  const [workspaceId, setWorkspaceId] = useState("");
  const [error, setError] = useState("");
  const [revision, setRevision] = useState(0);
  useEffect(() => {
    let live = true;
    void accountRequest<{ workspaces: InventoryWorkspace[] }>(accountId, "/inventory-workspaces")
      .then(result => { if (live) { setWorkspaces(result.workspaces); setError(""); } })
      .catch(reason => { if (live) setError(userFacingError(reason, "Workspaces could not be loaded.")); });
    return () => { live = false; };
  }, [accountId, revision]);
  return <div className={styles.page}>
    <p className={styles.intro}>Manage Amazon purchases and Shopify store connections. Choose where to keep their records.</p>
    {error && <p role="alert">{error} <button className="workspace-button" onClick={() => setRevision(v => v + 1)}>Retry</button></p>}
    {!workspaces && !error && <p role="status">Loading workspaces...</p>}
    {workspaces && <label className={styles.selector}>Workspace
      <select value={workspaceId} onChange={event => setWorkspaceId(event.target.value)}>
        <option value="">Choose a workspace</option>
        {workspaces.map(workspace => <option key={workspace.workspace_id} value={workspace.workspace_id}>{workspace.organization_name ? `${workspace.organization_name} / ` : ""}{workspace.name}</option>)}
      </select>
    </label>}
    {workspaces?.length === 0 && <p>Create an inventory workspace to manage connections.</p>}
    {workspaceId && <WorkspaceConnections key={workspaceId} accountId={accountId} workspaceId={workspaceId} />}
  </div>;
}

type InventoryPage = { inventories: AppInventory[]; next_offset: number | null };
function WorkspaceConnections({ accountId, workspaceId }: { accountId: string; workspaceId: string }) {
  const [page, setPage] = useState<InventoryPage | null>(null);
  const [inventoryId, setInventoryId] = useState("");
  const [offset, setOffset] = useState(0);
  const [error, setError] = useState("");
  const [revision, setRevision] = useState(0);
  useEffect(() => {
    let live = true;
    void accountRequest<InventoryPage>(accountId, `/inventory-workspaces/${encodeURIComponent(workspaceId)}/inventories?offset=${offset}`)
      .then(result => { if (live) { setPage(result); setError(""); } })
      .catch(reason => { if (live) setError(userFacingError(reason, "Inventories could not be loaded.")); });
    return () => { live = false; };
  }, [accountId, workspaceId, offset, revision]);
  function move(next: number) { setPage(null); setInventoryId(""); setError(""); setOffset(next); }
  return <>
    {error && <p role="alert">{error} <button className="workspace-button" onClick={() => setRevision(v => v + 1)}>Retry</button></p>}
    {!page && !error && <p role="status">Loading inventories...</p>}
    {page && <label className={styles.selector}>Inventory
      <select value={inventoryId} onChange={event => setInventoryId(event.target.value)}>
        <option value="">Choose an inventory</option>
        {page.inventories.map(inventory => <option key={inventory.inventory_id} value={inventory.inventory_id}>{inventory.name}</option>)}
      </select>
    </label>}
    {page?.inventories.length === 0 && <p>No inventories on this page.</p>}
    {(offset > 0 || page?.next_offset != null) && <div className={styles.paging}>
      <button className="workspace-button" disabled={!page || offset === 0} onClick={() => move(Math.max(0, offset - 100))}>Previous inventories</button>
      <button className="workspace-button" disabled={page?.next_offset == null} onClick={() => { if (page?.next_offset != null) move(page.next_offset); }}>More inventories</button>
    </div>}
    {inventoryId && <SelectedConnections key={inventoryId} accountId={accountId} inventoryId={inventoryId} />}
  </>;
}

function SelectedConnections({ accountId, inventoryId }: { accountId: string; inventoryId: string }) {
  const [inventory, setInventory] = useState<InventorySelection | null>(null);
  const [error, setError] = useState("");
  useEffect(() => {
    let live = true;
    void accountRequest<{ inventory: Omit<InventorySelection, "accountId"> }>(accountId, `/inventories/${encodeURIComponent(inventoryId)}`)
      .then(result => { if (live) {
        if (result.inventory.inventory_id !== inventoryId) throw new Error("The inventory could not be verified.");
        setInventory({ ...result.inventory, accountId });
      } })
      .catch(reason => { if (live) setError(userFacingError(reason, "This inventory could not be opened.")); });
    return () => { live = false; };
  }, [accountId, inventoryId]);
  if (error) return <p role="alert">{error}</p>;
  if (!inventory) return <p role="status">Checking inventory access...</p>;
  if (!inventory.can_edit) return <p>You need editing access to manage connections for this inventory.</p>;
  // Settings has no global inventory selection. Keep that boundary intact;
  // each request carries the verified inventory ID and remains account-bound.
  return <InventoryCommerce inventory={inventory} inventoryBinding={null} embedded />;
}

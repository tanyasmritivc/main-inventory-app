"use client";

import Link from "next/link";
import { useEffect, useLayoutEffect, useState } from "react";
import { AppShell } from "@/components/site/app-shell";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { requireInventoryContext, selectInventory } from "@/lib/inventory-selection";
import { userFacingError } from "@/lib/user-facing-error";
import styles from "./cad.module.css";

type Organization = { organization_id: string; name: string };
type Inventory = { inventory_id: string; name: string; workspace_name: string };

export function CadEntry({ worldId }: { worldId?: string }) {
  const { accountId, error } = useApiSession();
  if (!accountId) return <p role={error ? "alert" : "status"}>{error || "Opening CAD Intelligence..."}</p>;
  return <AccountEntry key={`${accountId}:${worldId || "personal"}`} accountId={accountId} worldId={worldId} />;
}

function AccountEntry({ accountId, worldId }: { accountId: string; worldId?: string }) {
  const [world, setWorld] = useState(worldId || "personal");
  const [organizations, setOrganizations] = useState<Organization[] | null>(null);
  const [directory, setDirectory] = useState<{ world: string; inventories: Inventory[] } | null>(null);
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);
  useLayoutEffect(() => {
    requireInventoryContext(false);
    selectInventory(null);
  }, []);
  useEffect(() => {
    let live = true;
    void accountRequest<{ organizations: Organization[] }>(accountId, "/organizations")
      .then(result => { if (live) setOrganizations(result.organizations); })
      .catch(reason => { if (live) setError(userFacingError(reason, "Your organizations could not be loaded.")); });
    return () => { live = false; };
  }, [accountId, attempt]);
  const allowed = organizations !== null && (world === "personal" || organizations.some(o => o.organization_id === world));
  useEffect(() => {
    if (!allowed) return;
    let live = true;
    void accountRequest<{ world: string; inventories: Inventory[] }>(accountId, `/worlds/${encodeURIComponent(world)}/directory`)
      .then(result => {
        if (!live) return;
        if (result.world !== world) throw new Error("The organization could not be verified.");
        setDirectory(result);
      })
      .catch(reason => { if (live) setError(userFacingError(reason, "Your inventories could not be loaded.")); });
    return () => { live = false; };
  }, [accountId, world, allowed, attempt]);
  const ready = allowed && directory?.world === world;
  return <AppShell><section className={styles.page}>
    <header className={styles.hero}><div className={styles.topline}><a href="/docs/cad" target="_blank" rel="noreferrer">Setup guide ↗</a></div><h1>Start with your inventory.</h1>
      <p>Choose where your parts are stored. Then bring in a Fusion assembly or spreadsheet to compare.</p></header>
    <div className={`${styles.card} ${styles.inventoryPicker}`}>
      <label className={styles.file}>Organization
        <select value={world} onChange={event => { setWorld(event.target.value); setDirectory(null); setError(""); }}>
          <option value="personal">Personal</option>
          {organizations === null && world !== "personal" && <option value={world}>Loading organization...</option>}
          {organizations?.map(o => <option key={o.organization_id} value={o.organization_id}>{o.name}</option>)}
          {organizations !== null && !allowed && <option value={world}>Unavailable organization</option>}
        </select>
      </label>
      {error ? <><p role="alert">{error}</p><button onClick={() => { setError(""); setDirectory(null); setAttempt(attempt + 1); }}>Try again</button></>
        : organizations !== null && !allowed ? <p role="alert">You do not have access to this organization. Choose another organization.</p>
        : !ready ? <p role="status">Loading inventories...</p>
        : directory.inventories.length ? <ul className={styles.inventoryList}>{directory.inventories.map(inventory => <li key={inventory.inventory_id}>
          <Link href={`/cad?inventory=${encodeURIComponent(inventory.inventory_id)}`}><strong>{inventory.name}</strong><small>{inventory.workspace_name}</small><span aria-hidden="true">→</span></Link>
        </li>)}</ul>
        : <p>No inventories are available here. <Link href="/workspaces">Open workspaces</Link> to create or join one.</p>}
    </div>
    <p className={styles.muted}>New to this? <a href="/docs/cad" target="_blank" rel="noreferrer">Follow the step-by-step setup guide</a> or <a href="mailto:info@findez.ai?subject=FindEZ%20CAD%20setup%20help">email support</a>. You can also <a href="/downloads/findez-fusion-preview.zip" download>download the Fusion add-in</a> before choosing an inventory.</p>
  </section></AppShell>;
}

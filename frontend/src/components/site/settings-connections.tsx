"use client";

import { useEffect, useState, useSyncExternalStore } from "react";
import Link from "next/link";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";
import { ScopedCommerce } from "./commerce-client";
import styles from "./settings-connections.module.css";

type Organization = { organization_id: string; name: string; role: string };
function subscribeLocation(callback: () => void) { window.addEventListener("popstate", callback); return () => window.removeEventListener("popstate", callback); }
const browserSearch = () => window.location.search;
const serverSearch = () => null;

export function SettingsConnections() {
  const search = useSyncExternalStore(subscribeLocation, browserSearch, serverSearch);
  const { accountId, loading, error } = useApiSession();
  if (loading || search === null) return <p role="status">Loading your account...</p>;
  if (error || !accountId) return <p role="alert">{error || "Sign in to manage connections."}</p>;
  return <AccountConnections key={`${accountId}:${search}`} accountId={accountId} initialOwner={new URLSearchParams(search).get("organization") || "personal"} />;
}

function AccountConnections({ accountId, initialOwner }: { accountId: string; initialOwner: string }) {
  const [organizations, setOrganizations] = useState<Organization[] | null>(null);
  const [owner, setOwner] = useState(initialOwner);
  const [error, setError] = useState("");
  const [revision, setRevision] = useState(0);
  useEffect(() => {
    let live = true;
    void accountRequest<{ organizations: Organization[] }>(accountId, "/organizations")
      .then(result => { if (live) { setOrganizations(result.organizations.filter(o => ["owner", "admin"].includes(o.role))); setError(""); } })
      .catch(reason => { if (live) setError(userFacingError(reason, "Organizations could not be loaded.")); });
    return () => { live = false; };
  }, [accountId, revision]);
  const organization = organizations?.find(o => o.organization_id === owner);
  const accessible = owner === "personal" || !!organization;
  const scope = owner === "personal" ? { scope_type: "personal" as const } : { scope_type: "organization" as const, organization_id: owner };
  function selectOwner(value: string) {
    setOwner(value);
    const url = new URL(window.location.href);
    if (value === "personal") url.searchParams.delete("organization"); else url.searchParams.set("organization", value);
    window.history.replaceState(null, "", `${url.pathname}${url.search}${url.hash}`);
  }
  return <div className={styles.page}>
    <p className={styles.intro}>Keep purchase history and connected stores with your personal account or an organization. You do not need to choose an inventory to import orders.</p>
    <label className={styles.selector}>Connection owner
      <select value={owner} onChange={event => selectOwner(event.target.value)}>
        <option value="personal">Personal · only you</option>
        {!accessible && owner !== "personal" && <option value={owner}>Requested organization</option>}
        {organizations?.map(o => <option key={o.organization_id} value={o.organization_id}>{o.name} · organization</option>)}
      </select>
    </label>
    <p>Only organization owners and administrators can manage organization connections. Switching owners does not move or share existing personal records.</p>
    {error && <p role="alert">{error} <button className="workspace-button" onClick={() => setRevision(v => v + 1)}>Retry organizations</button></p>}
    {!accessible && <p role={organizations ? "alert" : "status"}>{organizations ? "You do not have administrator access to this organization. Choose Personal or another organization." : "Checking organization access…"}</p>}
    <p><Link href={owner === "personal" ? "/docs/connections" : `/docs/connections?organization=${encodeURIComponent(owner)}`}>Connections documentation ↗</Link> · Setup, imports, privacy, and troubleshooting.</p>
    {accessible && <ScopedCommerce key={`${accountId}:${owner}`} accountId={accountId} scope={scope} ownerName={organization?.name || "Personal"} embedded />}
  </div>;
}

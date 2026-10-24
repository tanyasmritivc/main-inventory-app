"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Building2, Check, ChevronDown, FolderKanban, Mail, Plus, RefreshCw, UserRound } from "lucide-react";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import styles from "./organization-switcher.module.css";

export type SelectedOrganization = { id: string; name: string };
type Organization = { organization_id: string; name: string; role: string };
type Props = { accountId: string | null; organization?: SelectedOrganization; personal?: boolean; onNavigate?: () => void };

export function OrganizationSwitcher(props: Props) {
  // Account changes discard the menu, results and outstanding requests together.
  return <AccountSwitcher key={props.accountId || "signed-out"} {...props} />;
}
function AccountSwitcher({ accountId, organization, personal, onNavigate }: Props) {
  const [open, setOpen] = useState(false);
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [revision, setRevision] = useState(0);
  function openMenu(next: boolean) {
    if (next) { setLoading(true); setError(""); setOrganizations([]); }
    setOpen(next);
  }
  useEffect(() => {
    if (!open || !accountId) return;
    let active = true;
    void accountRequest<{ organizations: Organization[] }>(accountId, "/organizations")
      .then(result => {
        if (!Array.isArray(result.organizations) || result.organizations.some(org => !org.organization_id || typeof org.name !== "string")) throw new Error("Organizations could not be loaded.");
        if (active) setOrganizations([...result.organizations].sort((a, b) => a.name.localeCompare(b.name)));
      })
      .catch(reason => { if (active) setError(userFacingError(reason, "Organizations could not be loaded.")); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [open, accountId, revision]);
  const name = organization?.name || (personal ? "Personal" : "Organizations");
  const initial = organization ? Array.from(name)[0]?.toUpperCase() : null;
  return <div className={styles.root} data-organization-switcher>
    <DropdownMenu open={open} onOpenChange={openMenu} modal={false}>
      <DropdownMenuTrigger asChild>
        <button type="button" className={styles.trigger} disabled={!accountId} aria-label={`Switch organization. Current: ${name}`} title={name}>
          <span className={styles.avatar}>{initial || (personal ? <UserRound size={16} /> : <Building2 size={16} />)}</span>
          <span className={styles.name}>{name}</span><ChevronDown size={15} className={styles.chevron} />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" sideOffset={8} collisionPadding={12} className={styles.menu} aria-label="Switch organization" onEscapeKeyDown={event => event.stopPropagation()}>
        <DropdownMenuLabel className={styles.label}>Your organizations</DropdownMenuLabel>
        {loading ? <p className={styles.message} role="status">Loading organizations...</p> : error ? <>
          <p className={styles.message} role="alert">{error}</p>
          <DropdownMenuItem onSelect={event => { event.preventDefault(); setLoading(true); setError(""); setRevision(value => value + 1); }}><RefreshCw size={16} />Try again</DropdownMenuItem>
        </> : <div className={styles.list}>
          {organizations.map(org => <DropdownMenuItem key={org.organization_id} asChild textValue={org.name}>
            <Link href={`/organizations/${encodeURIComponent(org.organization_id)}`} onClick={onNavigate} aria-current={organization?.id === org.organization_id ? "true" : undefined}>
              <span className={styles.avatar}>{Array.from(org.name)[0]?.toUpperCase()}</span>
              <span className={styles.rowCopy}><span>{org.name}</span><small>{org.role === "owner" ? "Owner" : org.role === "admin" ? "Admin" : "Member"}</small></span>
              {organization?.id === org.organization_id && <Check size={16} className={styles.check} aria-label="Selected" />}
            </Link>
          </DropdownMenuItem>)}
          {!organizations.length && <p className={styles.message}>Your organizations will appear here.</p>}
        </div>}
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild><Link href="/workspaces/personal" onClick={onNavigate}><UserRound size={16} />Personal{personal && <Check size={16} className={styles.check} aria-label="Selected" />}</Link></DropdownMenuItem>
        <DropdownMenuItem asChild><Link href="/workspaces" onClick={onNavigate}><FolderKanban size={16} />All workspaces</Link></DropdownMenuItem>
        <DropdownMenuItem asChild><Link href="/organizations" onClick={onNavigate}><Building2 size={16} />Manage organizations</Link></DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild><Link href="/organizations?new=1" onClick={onNavigate}><Plus size={16} />New organization</Link></DropdownMenuItem>
        <DropdownMenuItem asChild><Link href="/join/access" onClick={onNavigate}><Mail size={16} />Review invitation</Link></DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  </div>;
}

"use client";
import { ResourceArt, PageHeader } from "./app-theme-ui";
import Link from "next/link";
import { rememberWorld } from "@/lib/world-entry";
import { usePermissionRefresh } from "@/lib/use-permission-refresh";
import { useEffect, useLayoutEffect, useState, useRef } from "react";
import { MapPin, Plus, RefreshCw } from "lucide-react";
import { ApiError } from "@/lib/api";
import { AppShell } from "./app-shell";
import { AssistClient } from "./assist-client";
import { useApiSession } from "@/lib/use-api-session";
import { accountRequest } from "@/lib/account-request";
import {
  requireInventoryContext,
  selectInventory,
} from "@/lib/inventory-selection";
import { worldNavigation } from "@/lib/world-navigation";
import { userFacingError } from "@/lib/user-facing-error";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import styles from "./world-workspace.module.css";
import { PageTransition } from "./page-transition";
import { InteriorLoading } from "./interior-state";
import { WorldTools } from "./world-tools";
type Inventory = {
  inventory_id: string;
  name: string;
  workspace_id: string;
  workspace_name: string;
  can_edit: boolean;
  item_count?: number;
  spaces?: { id: string; name: string; item_count?: number }[];
};
type Directory = {
  world: string;
  inventories: Inventory[];
  can_create_space: boolean;
};
export function WorldWorkspace(props: {
  worldId: string;
  view: string;
  initialQuery: string;
}) {
  const { accountId, error } = useApiSession();
  if (!accountId)
    return error ? <div className="interior-loading inventory-loading" role="alert">{error}</div> : <PageTransition />;
  return (
    <WorldContent
      key={`${accountId}:${props.worldId}`}
      {...props}
      accountId={accountId}
    />
  );
}
function WorldContent({
  worldId,
  view,
  initialQuery,
  accountId,
}: {
  worldId: string;
  view: string;
  initialQuery: string;
  accountId: string;
}) {
  const alive = useRef(true),
    saving = useRef(false),
    control = useRef<AbortController | null>(null);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      control.current?.abort();
    };
  }, []);
  const [directory, setDirectory] = useState<Directory>();
  const [name, setName] = useState(
    worldId === "personal" ? "Personal" : "Organization",
  );
  const [error, setError] = useState("");
  const [revision, setRevision] = useState(0);
  const [groups, setGroups] = useState<Inventory[]>();
  const [query, setQuery] = useState("");
  const [create, setCreate] = useState(false);
  const [spaceName, setSpaceName] = useState("");
  const [busy, setBusy] = useState(false);
  const [createError, setCreateError] = useState("");
  usePermissionRefresh(() => setRevision(v => v + 1), busy || create);
  useLayoutEffect(() => {
    requireInventoryContext(false);
    selectInventory(null);
  }, []);
  useEffect(() => {
    let live = true;
    Promise.all([
      accountRequest<Directory>(
        accountId,
        `/worlds/${encodeURIComponent(worldId)}/directory`,
      ),
      worldId === "personal"
        ? Promise.resolve("Personal")
        : accountRequest<{
            organizations: { organization_id: string; name: string }[];
          }>(accountId, "/organizations").then(
            (r) =>
              r.organizations.find((o) => o.organization_id === worldId)
                ?.name || "Organization",
          ),
    ])
      .then(([data, label]) => {
        if (live) {
          if (data.world !== worldId)
            throw new Error("The organization could not be verified.");
          rememberWorld(accountId, worldId);
          setDirectory(data);
          setName(label);
          setError("");
        }
      })
      .catch((e) => {
        if (live) {
          if (e instanceof ApiError && [401, 403, 404].includes(e.status)) {
            setDirectory(undefined);
            setGroups(undefined);
          }
          setError(
            userFacingError(e, "Your organization could not be opened."),
          );
        }
      });
    return () => {
      live = false;
    };
  }, [accountId, worldId, revision]);
  useEffect(() => {
    if (!directory || !["spaces", "tools", "workspaces"].includes(view)) return;
    let live = true;
    accountRequest<{ inventories: Inventory[] }>(
      accountId,
      `/worlds/${encodeURIComponent(worldId)}/spaces`,
    )
      .then((r) => {
        if (live) {
          setGroups(r.inventories);
          setError("");
        }
      })
      .catch((e) => {
        if (live) setError(userFacingError(e, "Spaces could not be loaded."));
      });
    return () => {
      live = false;
    };
  }, [accountId, worldId, directory, view]);
  async function saveSpace(e: React.FormEvent) {
    e.preventDefault();
    if (
      saving.current ||
      !spaceName.trim() ||
      !directory?.can_create_space
    )
      return;
    saving.current = true;
    const c = new AbortController();
    control.current = c;
    setBusy(true);
    setCreateError("");
    try {
      const r = await accountRequest<{ space: { id: string; name: string } }>(
        accountId,
        `/worlds/${encodeURIComponent(worldId)}/spaces`,
        {
          method: "POST",
          signal: c.signal,
          body: JSON.stringify({ name: spaceName.trim() }),
        },
      );
      if (!r.space?.id)
        throw new Error(
          "Saving could not be confirmed. Refresh Spaces before retrying.",
        );
      if (!alive.current) return;
      setCreate(false);
      setSpaceName("");
      setGroups(undefined);
      setRevision((v) => v + 1);
    } catch (e) {
      if (alive.current)
        setCreateError(userFacingError(e, "Could not create this Space."));
    } finally {
      saving.current = false;
      if (alive.current) setBusy(false);
    }
  }
  const chosen = view === "workspaces" ? "spaces" : ["chat", "spaces", "search", "tools"].includes(
    view,
  )
    ? view
    : "chat";
  const context = worldNavigation(worldId, name, chosen);
  const filtered = (groups || [])
    .map((g) => ({
      ...g,
      spaces: (g.spaces || []).filter((s) =>
        s.name
          .toLowerCase()
          .includes(query.toLowerCase()),
      ),
    }))
    .filter((g) => g.spaces.length);
  return (
    <AppShell context={context}>
      {error && (
        <p className="notice-error" role="alert">
          {error}{" "}
          <button
            className="workspace-button"
            onClick={() => setRevision((v) => v + 1)}
          >
            Retry
          </button>
        </p>
      )}
      {!directory ? (
        !error && <InteriorLoading />
      ) : chosen === "chat" || chosen === "search" ? (
        <AssistClient
          worldId={worldId}
          initialQuery={initialQuery}
          title={
            chosen === "search"
              ? "Find it in your organization"
              : "What’s in your world?"
          }
        />
      ) : (
        <section className={styles.page}>
          <PageHeader className={styles.header}>
            <div>
              <h1>
                {chosen === "spaces"
                  ? "Spaces"
                  : chosen === "tools"
                    ? "Tools"
                    : "Spaces"}
              </h1>

            </div>
            <div className={styles.tools}>
              <button
                className="workspace-button"
                aria-label="Refresh"
                onClick={() => setRevision((v) => v + 1)}
              >
                <RefreshCw size={16} />
              </button>
              {chosen === "spaces" && directory.can_create_space && (
                <button
                  className="workspace-button primary"
                  onClick={() => {
                    setCreateError("");
                    setCreate(true);
                  }}
                >
                  <Plus size={16} />
                  New Space
                </button>
              )}

            </div>
          </PageHeader>
          {chosen === "spaces" && (
            <>
              <input
                className={styles.search}
                aria-label="Search Spaces"
                placeholder="Search Spaces"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
              {!groups && !error ? (
                <p role="status">Loading Spaces…</p>
              ) : (
                filtered.map((g) => (
                  <section className={styles.group} key={g.inventory_id}>
                    <div className={styles.grid}>
                      {g.spaces.map((s) => (
                        <Link
                          className={`${styles.card} ${styles.resource} theme-card`}
                          key={s.id}
                          href={`/inventory?${new URLSearchParams({ inventory: g.inventory_id, space: s.name })}`}
                        >
                          <ResourceArt id={s.id}>{s.item_count == null ? "View items" : `${s.item_count} ${s.item_count === 1 ? "item" : "items"}`}</ResourceArt>
                          <div className={styles.caption}>
                            <MapPin size={16} />
                            <strong>{s.name}</strong>
                            {!g.can_edit && <small>View only</small>}
                          </div>
                        </Link>
                      ))}
                    </div>
                  </section>
                ))
              )}
              {groups && !filtered.length && (
                <p className={styles.empty}>
                  {query
                    ? "No matching Spaces."
                    : "No Spaces yet. Create one or describe what you want to organize in chat."}
                </p>
              )}

            </>
          )}
          {chosen === "tools" && <WorldTools accountId={accountId} inventories={groups || []} organizationId={worldId === "personal" ? undefined : worldId} />}
        </section>
      )}
      <Dialog
        open={create}
        onOpenChange={(v) => {
          if (!busy) setCreate(v);
        }}
      >
        <DialogContent
          className="workspace-dialog"
          aria-describedby={undefined}
        >
          <DialogTitle>New Space</DialogTitle>
          <form onSubmit={saveSpace} className={styles.page}>
            <label>
              Name
              <input
                className={styles.search}
                required
                maxLength={100}
                value={spaceName}
                onChange={(e) => setSpaceName(e.target.value)}
              />
            </label>
            {createError && <p role="alert">{createError}</p>}
            <div className={styles.tools}>
              <button
                type="button"
                className="workspace-button"
                disabled={busy}
                onClick={() => setCreate(false)}
              >
                Cancel
              </button>
              <button
                className="workspace-button primary"
                disabled={busy || !spaceName.trim()}
              >
                {busy ? "Creating…" : "Create Space"}
              </button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </AppShell>
  );
}

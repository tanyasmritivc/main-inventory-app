"use client";
import Link from "next/link";
import { rememberWorld } from "@/lib/world-entry";
import { useEffect, useLayoutEffect, useState, useRef } from "react";
import { Boxes, FolderKanban, MapPin, Plus, RefreshCw } from "lucide-react";
import { ApiError } from "@/lib/api";
import { InventoryChatArchive } from "./inventory-chat-archive";
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
  workspaces: { workspace_id: string; name: string; can_create: boolean }[];
};
const tools = [
  ["Capture / Import", "/scan"],
  ["Documents", "/documents"],
  ["Review", "/review"],
  ["Activity", "/activity"],
  ["Restock", "/restock"],
  ["Check-outs", "/checkout"],
  ["Project kits", "/project-kits"],
  ["Collections", "/collections"],
  ["Labels", "/labels"],
  ["Inventory settings", "/inventory-access"],
];
export function WorldWorkspace(props: {
  worldId: string;
  view: string;
  initialQuery: string;
}) {
  const { accountId, error } = useApiSession();
  if (!accountId)
    return <p role="status">{error || "Opening your organization…"}</p>;
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
  useEffect(() => {
    const refresh = () => {
      if (document.visibilityState === "visible") setRevision((v) => v + 1);
    };
    window.addEventListener("focus", refresh);
    const timer = window.setInterval(refresh, 30000);
    return () => {
      window.removeEventListener("focus", refresh);
      window.clearInterval(timer);
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
  const [destination, setDestination] = useState("");
  const [spaceName, setSpaceName] = useState("");
  const [busy, setBusy] = useState(false);
  const [createError, setCreateError] = useState("");
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
    if (!directory || view !== "spaces") return;
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
      !directory?.inventories.some(
        (i) => i.inventory_id === destination && i.can_edit,
      )
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
        `/inventories/${encodeURIComponent(destination)}/spaces`,
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
  const chosen = ["chat", "spaces", "search", "tools", "workspaces"].includes(
    view,
  )
    ? view
    : "chat";
  const context = worldNavigation(worldId, name, chosen);
  const inventories = directory?.inventories || [];
  const filtered = (groups || [])
    .map((g) => ({
      ...g,
      spaces: (g.spaces || []).filter((s) =>
        `${s.name} ${g.name} ${g.workspace_name}`
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
        !error && <p role="status">Opening your organization…</p>
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
          <header className={styles.header}>
            <div>
              <h1>
                {chosen === "spaces"
                  ? "Spaces"
                  : chosen === "tools"
                    ? "Tools"
                    : "Workspaces"}
              </h1>
              <p>
                {name}
                {chosen === "spaces"
                  ? " · Across your accessible inventories"
                  : ""}
              </p>
            </div>
            <div className={styles.tools}>
              <button
                className="workspace-button"
                aria-label="Refresh"
                onClick={() => setRevision((v) => v + 1)}
              >
                <RefreshCw size={16} />
              </button>
              {chosen === "spaces" && inventories.some((i) => i.can_edit) && (
                <button
                  className="workspace-button is-primary"
                  onClick={() => {
                    setDestination(
                      inventories.find((i) => i.can_edit)!.inventory_id,
                    );
                    setCreateError("");
                    setCreate(true);
                  }}
                >
                  <Plus size={16} />
                  New Space
                </button>
              )}
              {chosen === "workspaces" && (
                <Link
                  href={
                    worldId === "personal"
                      ? "/workspaces"
                      : "/organizations/" +
                        encodeURIComponent(worldId) +
                        "?view=workspaces"
                  }
                >
                  Manage workspaces
                </Link>
              )}
            </div>
          </header>
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
                    <h2>
                      {g.workspace_name} / {g.name}
                    </h2>
                    <div className={styles.grid}>
                      {g.spaces.map((s) => (
                        <Link
                          className={styles.card}
                          key={s.id}
                          href={`/inventory?${new URLSearchParams({ inventory: g.inventory_id, space: s.name })}`}
                        >
                          <MapPin size={20} />
                          <div>
                            <strong>{s.name}</strong>
                            <small>
                              {s.item_count == null
                                ? "View items"
                                : `${s.item_count} ${s.item_count === 1 ? "item" : "items"}`}
                              {!g.can_edit ? " · View only" : ""}
                            </small>
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
              <section className={styles.group}>
                <h2>Browse inventories</h2>
                <div className={styles.grid}>
                  {inventories.map((i) => (
                    <Link
                      className={styles.card}
                      key={i.inventory_id}
                      href={`/inventory?inventory=${encodeURIComponent(i.inventory_id)}`}
                    >
                      <Boxes size={20} />
                      <div>
                        <strong>{i.name}</strong>
                        <small>{i.workspace_name} · All items</small>
                      </div>
                    </Link>
                  ))}
                </div>
              </section>
            </>
          )}
          {chosen === "workspaces" && (
            <div className={styles.grid}>
              {directory.workspaces.map((w) => (
                <Link
                  className={styles.card}
                  key={w.workspace_id}
                  href={`/workspaces/${encodeURIComponent(w.workspace_id)}`}
                >
                  <FolderKanban size={20} />
                  <div>
                    <strong>{w.name}</strong>
                    <small>Inventories, people, tasks and files</small>
                  </div>
                </Link>
              ))}
            </div>
          )}
          {chosen === "tools" && (
            <>
              <p>
                Choose the inventory for the task. Chat and Spaces cover the
                whole organization.
              </p>
              {inventories.map((i) => (
                <section className={styles.group} key={i.inventory_id}>
                  <h2>
                    {i.workspace_name} / {i.name}
                  </h2>
                  <div className={styles.tools}>
                    <InventoryChatArchive
                      accountId={accountId}
                      inventoryId={i.inventory_id}
                      name={i.name}
                    />
                    {tools.map(([label, path]) => (
                      <Link
                        key={path}
                        href={`${path}?inventory=${encodeURIComponent(i.inventory_id)}`}
                      >
                        {label}
                      </Link>
                    ))}
                  </div>
                </section>
              ))}
              {!inventories.length && (
                <p className={styles.empty}>
                  Create an inventory in a workspace or ask FindEZ to help you
                  organize one.
                </p>
              )}
            </>
          )}
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
              Inventory
              <select
                aria-label="Inventory"
                className="product-select"
                value={destination}
                onChange={(e) => setDestination(e.target.value)}
              >
                {inventories
                  .filter((i) => i.can_edit)
                  .map((i) => (
                    <option key={i.inventory_id} value={i.inventory_id}>
                      {i.workspace_name} / {i.name}
                    </option>
                  ))}
              </select>
            </label>
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
                className="workspace-button is-primary"
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

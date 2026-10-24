import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import type { InventoryWorkspace } from "@/lib/inventory-selection";

export type SetupStep =
  | "welcome"
  | "choose"
  | "org"
  | "purpose"
  | "inventory"
  | "world"
  | "setup";
export type SetupPath = "personal" | "team";
type Resource = "organization" | "workspace" | "inventory";
type Attempt = { baseline: string[]; uncertain: boolean };
export type SetupDraft = {
  version: 1;
  step: SetupStep;
  path: SetupPath | null;
  orgName: string;
  purpose: string;
  inventory: string;
  createdIds: Partial<Record<Resource, string>>;
  attempts: Partial<Record<Resource, Attempt>>;
};
type Organization = {
  organization_id: string;
  name: string;
  owner_user_id: string;
};
type Inventory = {
  inventory_id: string;
  name: string;
  owner_user_id: string;
  is_default?: boolean;
};
type Directory = {
  organizations: Organization[];
  workspaces: InventoryWorkspace[];
};
export type SetupRequest = typeof accountRequest;
type Store = Pick<Storage, "getItem" | "setItem" | "removeItem">;

export const pendingSetupKey = (id: string) =>
  `fz_web_onboarding_pending_${id}`;
export const doneSetupKey = (id: string) => `fz_web_onboarding_done_${id}`;
export const setupOrder = (path: SetupPath | null): SetupStep[] =>
  path === "personal"
    ? ["welcome", "choose", "purpose", "inventory", "world", "setup"]
    : ["welcome", "choose", "org", "purpose", "inventory", "world", "setup"];
export const newSetup = (): SetupDraft => ({
  version: 1,
  step: "welcome",
  path: null,
  orgName: "",
  purpose: "",
  inventory: "",
  createdIds: {},
  attempts: {},
});

export function signupDestination(next: string) {
  // Consent links and recovery retain their existing ownership and destination.
  return /^\/(?:join|reset-password|auth)(?:[/?]|$)/.test(next)
    ? next
    : "/worlds";
}

export function readSetup(store: Store, id: string): SetupDraft {
  const raw = store.getItem(pendingSetupKey(id));
  if (!raw) return newSetup();
  let value: SetupDraft;
  try {
    value = JSON.parse(raw);
  } catch {
    return newSetup();
  }
  if (
    value?.version !== 1 ||
    ![null, "personal", "team"].includes(value.path) ||
    !setupOrder(value.path).includes(value.step) ||
    typeof value.orgName !== "string" ||
    value.orgName.trim().length > 60 ||
    typeof value.purpose !== "string" ||
    value.purpose.trim().length > 40 ||
    typeof value.inventory !== "string" ||
    value.inventory.trim().length > 40
  )
    return newSetup();
  const draft = {
    ...newSetup(),
    ...value,
    createdIds: {},
    attempts: {},
  } as SetupDraft;
  for (const kind of ["organization", "workspace", "inventory"] as Resource[]) {
    const receipt = value.createdIds?.[kind],
      attempt = value.attempts?.[kind];
    if (
      typeof receipt === "string" &&
      receipt.length > 0 &&
      receipt.length < 100
    )
      draft.createdIds[kind] = receipt;
    if (
      Array.isArray(attempt?.baseline) &&
      attempt.baseline.every((id) => typeof id === "string") &&
      typeof attempt.uncertain === "boolean"
    )
      draft.attempts[kind] = attempt;
  }
  if (!draft.path && !["welcome", "choose"].includes(draft.step))
    draft.step = "choose";
  if (
    draft.path === "team" &&
    !draft.orgName.trim() &&
    ["purpose", "inventory", "world", "setup"].includes(draft.step)
  )
    draft.step = "org";
  if (
    !draft.purpose.trim() &&
    ["inventory", "world", "setup"].includes(draft.step)
  )
    draft.step = "purpose";
  if (!draft.inventory.trim() && ["world", "setup"].includes(draft.step))
    draft.step = "inventory";
  return draft;
}
export function saveSetup(store: Store, id: string, draft: SetupDraft) {
  store.setItem(pendingSetupKey(id), JSON.stringify(draft));
}
export function finishSetup(store: Store, id: string) {
  // Commit completion first so a failed storage write cannot re-arm onboarding.
  store.setItem(doneSetupKey(id), "1");
  store.removeItem(pendingSetupKey(id));
}

async function directory(
  id: string,
  request: SetupRequest,
): Promise<Directory> {
  const [orgs, spaces] = await Promise.all([
    request<{ organizations: Organization[] }>(id, "/organizations"),
    request<{ workspaces: InventoryWorkspace[] }>(id, "/inventory-workspaces"),
  ]);
  if (
    !Array.isArray(orgs.organizations) ||
    !Array.isArray(spaces.workspaces) ||
    !spaces.workspaces.some(
      (w) => w.workspace_id === "personal" && w.kind === "personal",
    )
  )
    throw new Error("The account directory could not be verified.");
  return { organizations: orgs.organizations, workspaces: spaces.workspaces };
}

// Recover only one new, actor-owned, exact-name record in the expected parent.
// A lost POST response must never cause a blind repeat of a creation request.
function recover<T>(
  rows: T[],
  attempt: Attempt | undefined,
  getId: (row: T) => string,
  matches: (row: T) => boolean,
) {
  if (!attempt) return undefined;
  const found = rows.filter(
    (row) => !attempt.baseline.includes(getId(row)) && matches(row),
  );
  if (found.length > 1)
    throw new Error("The setup result needs to be checked before retrying.");
  return found[0] ? getId(found[0]) : undefined;
}

export async function checkSetupEligibility(
  id: string,
  draft: SetupDraft,
  request: SetupRequest = accountRequest,
) {
  const current = await directory(id, request);
  if (!draft.createdIds.organization && draft.path === "team") {
    draft.createdIds.organization = recover(
      current.organizations,
      draft.attempts.organization,
      (o) => o.organization_id,
      (o) => o.owner_user_id === id && o.name === draft.orgName.trim(),
    );
  }
  if (!draft.createdIds.workspace) {
    draft.createdIds.workspace = recover(
      current.workspaces,
      draft.attempts.workspace,
      (w) => w.workspace_id,
      (w) =>
        w.owner_user_id === id &&
        w.role === "owner" &&
        w.name === draft.purpose.trim(),
    );
  }
  const ownOrg =
    draft.path === "team"
      ? current.organizations.find(
          (o) =>
            o.organization_id === draft.createdIds.organization &&
            o.owner_user_id === id &&
            o.name === draft.orgName.trim(),
        )
      : undefined;
  let ownWorkspace = current.workspaces.find(
    (w) =>
      w.workspace_id === draft.createdIds.workspace &&
      w.owner_user_id === id &&
      w.role === "owner" &&
      w.name === draft.purpose.trim(),
  );
  // The workspace list omits parent organization IDs. Verify its real parent
  // through the existing detail response before treating it as our setup receipt.
  if (ownWorkspace) {
    const { workspace } = await request<{ workspace: InventoryWorkspace }>(
      id,
      `/inventory-workspaces/${encodeURIComponent(ownWorkspace.workspace_id)}/inventories`,
    );
    if (
      (workspace.organization_id || null) !==
      (draft.path === "team" ? ownOrg?.organization_id : null)
    )
      ownWorkspace = undefined;
  }
  return (
    current.organizations.every((o) => o === ownOrg) &&
    current.workspaces.every(
      (w) => w.workspace_id === "personal" || w === ownWorkspace,
    )
  );
}

export async function personalDashboard(
  id: string,
  request: SetupRequest = accountRequest,
) {
  const { inventories } = await request<{ inventories: Inventory[] }>(
    id,
    "/inventory-workspaces/personal/inventories",
  );
  const inventory = inventories.find((i) => i.is_default) || inventories[0];
  return inventory
    ? `/home?inventory=${encodeURIComponent(inventory.inventory_id)}`
    : "/workspaces/personal";
}

export async function provisionSetup(
  id: string,
  initial: SetupDraft,
  store: Store,
  changed: (draft: SetupDraft) => void,
  request: SetupRequest = accountRequest,
) {
  const draft = structuredClone(initial);
  if (
    !draft.path ||
    !draft.purpose.trim() ||
    !draft.inventory.trim() ||
    (draft.path === "team" && !draft.orgName.trim())
  )
    throw new Error("Finish the setup questions first.");
  const commit = () => {
    saveSetup(store, id, draft);
    changed(structuredClone(draft));
  };
  draft.step = "setup";
  commit();
  if (!(await checkSetupEligibility(id, draft, request)))
    throw new Error("Your account already has a workspace.");
  commit();

  async function create(
    kind: Resource,
    rows: { id: string; matches: boolean }[],
    path: string,
    body: Record<string, unknown>,
    readId: (value: Record<string, Record<string, string>>) => string,
  ) {
    if (draft.createdIds[kind]) return;
    const attempt = draft.attempts[kind];
    const recovered = recover(
      rows,
      attempt,
      (r) => r.id,
      (r) => r.matches,
    );
    if (recovered) {
      draft.createdIds[kind] = recovered;
      commit();
      return;
    }
    if (attempt?.uncertain)
      throw new Error(
        "The previous request has not been confirmed. Try again to check its result.",
      );
    draft.attempts[kind] = { baseline: rows.map((r) => r.id), uncertain: true };
    commit(); // Durable intent before any POST, including reloads during a request.
    try {
      const result = await request<Record<string, Record<string, string>>>(
        id,
        path,
        { method: "POST", body },
      );
      const receipt = readId(result);
      if (!receipt)
        throw new Error("The created record could not be confirmed.");
      draft.createdIds[kind] = receipt;
      commit(); // Receipt must survive before the next write begins.
    } catch (reason) {
      // Only explicit validation/auth/rate-limit rejections are safe to repeat.
      // A timeout, missing receipt or 5xx can hide a committed server write.
      if (
        reason instanceof ApiError &&
        [400, 401, 403, 404, 409, 422, 429].includes(reason.status)
      ) {
        draft.attempts[kind]!.uncertain = false;
        commit();
      }
      throw reason;
    }
  }

  if (draft.path === "team") {
    const { organizations } = await request<{ organizations: Organization[] }>(
      id,
      "/organizations",
    );
    await create(
      "organization",
      organizations.map((o) => ({
        id: o.organization_id,
        matches: o.owner_user_id === id && o.name === draft.orgName.trim(),
      })),
      "/organizations",
      { name: draft.orgName.trim() },
      (r) => r.organization?.organization_id,
    );
  }
  if (!draft.createdIds.workspace) {
    const parent = draft.createdIds.organization;
    const rows = parent
      ? (
          await request<{
            workspaces: {
              team_id: string;
              name: string;
              owner_user_id: string;
            }[];
          }>(id, `/organizations/${encodeURIComponent(parent)}`)
        ).workspaces.map((w) => ({
          id: w.team_id,
          matches: w.owner_user_id === id && w.name === draft.purpose.trim(),
        }))
      : (
          await request<{ workspaces: InventoryWorkspace[] }>(
            id,
            "/inventory-workspaces",
          )
        ).workspaces.map((w) => ({
          id: w.workspace_id,
          matches: w.owner_user_id === id && w.name === draft.purpose.trim(),
        }));
    await create(
      "workspace",
      rows,
      parent
        ? `/organizations/${encodeURIComponent(parent)}/workspaces`
        : "/teams",
      { name: draft.purpose.trim(), ...(!parent ? { program: "other" } : {}) },
      (r) => (parent ? r.workspace : r.team)?.team_id,
    );
  }
  const workspace = draft.createdIds.workspace!;
  const path = `/inventory-workspaces/${encodeURIComponent(workspace)}/inventories`;
  const { inventories } = await request<{ inventories: Inventory[] }>(id, path);
  // Existing workspace creation can seed a default inventory. A custom answer
  // that is exactly that default name can use it without a conflicting POST.
  const seeded = inventories.find(
    (i) =>
      i.is_default &&
      i.owner_user_id === id &&
      i.name === draft.inventory.trim(),
  );
  if (!draft.createdIds.inventory && !draft.attempts.inventory && seeded) {
    draft.createdIds.inventory = seeded.inventory_id;
    commit();
  }
  await create(
    "inventory",
    inventories.map((i) => ({
      id: i.inventory_id,
      matches: i.owner_user_id === id && i.name === draft.inventory.trim(),
    })),
    path,
    { name: draft.inventory.trim() },
    (r) => r.inventory?.inventory_id,
  );
  // Reauthorize the final target before marking complete or navigating.
  const { inventory } = await request<{
    inventory: {
      inventory_id: string;
      workspace: InventoryWorkspace;
      can_open?: boolean;
    };
  }>(id, `/inventories/${encodeURIComponent(draft.createdIds.inventory!)}`);
  if (
    inventory.inventory_id !== draft.createdIds.inventory ||
    inventory.workspace.workspace_id !== workspace ||
    inventory.can_open === false
  )
    throw new Error("The new dashboard could not be opened.");
  finishSetup(store, id);
  return `/home?inventory=${encodeURIComponent(draft.createdIds.inventory!)}`;
}

export async function withSetupLock<T>(id: string, action: () => Promise<T>) {
  // Secure localhost and HTTPS support Web Locks in current product browsers.
  // Refuse unlocked writes rather than creating duplicates in two open tabs.
  if (!navigator.locks)
    throw new Error("Setup needs a browser that supports safe account setup.");
  return navigator.locks.request(`fz-web-onboarding-${id}`, action);
}

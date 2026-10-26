/** @jest-environment jsdom */
import { ApiError } from "@/lib/api";
import {
  checkSetupEligibility,
  doneSetupKey,
  finishSetup,
  newSetup,
  pendingSetupKey,
  personalDashboard,
  provisionSetup,
  readSetup,
  saveSetup,
  signupDestination,
  type SetupDraft,
  type SetupRequest,
} from "@/lib/web-onboarding";
beforeEach(() => {
  localStorage.clear();
  global.structuredClone = (value) => JSON.parse(JSON.stringify(value));
});
const ready = (path: "team" | "personal" = "team"): SetupDraft => ({
  ...newSetup(),
  path,
  step: "world",
  orgName: path === "team" ? "Kestrel Labs" : "",
  purpose: path === "team" ? "R&D" : "Workshop",
  inventory: path === "team" ? "Hardware" : "Tools",
});
function fixture() {
  const orgs: Record<string, string>[] = [],
    workspaces: Record<string, string>[] = [],
    inventories: Record<string, unknown>[] = [],
    writes: string[] = [];
  const personal = {
    workspace_id: "personal",
    name: "Personal",
    kind: "personal",
    role: "owner",
    owner_user_id: "actor",
  };
  let failPath = "",
    failAfterCommit = false;
  const request = jest.fn(
    async (
      _id: string,
      path: string,
      options?: { method?: string; body?: { name: string } },
    ) => {
      if (options?.method === "POST") {
        writes.push(path);
        const fails = failPath === path;
        if (fails && !failAfterCommit) {
          failPath = "";
          throw new ApiError("Rejected", 422, null);
        }
        let result;
        if (path === "/organizations") {
          const row = {
            organization_id: "org1",
            name: options.body!.name,
            owner_user_id: "actor",
          };
          orgs.push(row);
          result = { organization: row };
        } else if (path.endsWith("/workspaces") || path === "/teams") {
          const row = {
            workspace_id: "ws1",
            team_id: "ws1",
            name: options.body!.name,
            owner_user_id: "actor",
            kind: "team",
            role: "owner",
            ...(path === "/teams" ? {} : { organization_id: "org1" }),
          };
          workspaces.push(row);
          result = path === "/teams" ? { team: row } : { workspace: row };
        } else {
          const row = {
            inventory_id: "inv1",
            name: options.body!.name,
            owner_user_id: "actor",
          };
          inventories.push(row);
          result = { inventory: row };
        }
        if (fails) {
          failPath = "";
          throw new ApiError("Response lost", 503, null);
        }
        return result;
      }
      if (path === "/organizations") return { organizations: orgs };
      if (path === "/inventory-workspaces")
        return { workspaces: [personal, ...workspaces] };
      if (path === "/organizations/org1") return { workspaces };
      if (path.endsWith("/inventories"))
        return { inventories, workspace: workspaces[0] || personal };
      if (path === "/inventories/inv1")
        return {
          inventory: {
            ...inventories[0],
            workspace: workspaces[0],
            can_open: true,
          },
        };
      throw new Error(`Unexpected request ${path}`);
    },
  );
  return {
    request: request as unknown as SetupRequest,
    calls: request,
    orgs,
    workspaces,
    inventories,
    writes,
    fail: (path: string, afterCommit = false) => {
      failPath = path;
      failAfterCommit = afterCommit;
    },
  };
}
test("signup routes to onboarding while preserving consent/recovery", () => {
  expect(signupDestination("/home")).toBe("/worlds");
  expect(signupDestination("/inventory")).toBe("/worlds");
  expect(signupDestination("/join/access/ABC123?download=1")).toBe(
    "/join/access/ABC123?download=1",
  );
  expect(signupDestination("/reset-password")).toBe("/reset-password");
});
test("draft resumes exact step, answers and account-bound receipts", () => {
  const value = {
    ...ready(),
    step: "inventory" as const,
    createdIds: { organization: "org1" },
  };
  saveSetup(localStorage, "actor", value);
  expect(readSetup(localStorage, "actor")).toEqual(value);
  expect(readSetup(localStorage, "other")).toEqual(newSetup());
});
test("invalid drafts cannot crash or skip required names", () => {
  localStorage.setItem(pendingSetupKey("actor"), "{");
  expect(readSetup(localStorage, "actor")).toEqual(newSetup());
  saveSetup(localStorage, "actor", { ...ready(), orgName: " ", step: "setup" });
  expect(readSetup(localStorage, "actor").step).toBe("org");
});
test("team creates org/workspace/inventory once in order with durable receipts", async () => {
  const f = fixture(),
    changes: SetupDraft[] = [];
  expect(
    await provisionSetup(
      "actor",
      ready(),
      localStorage,
      (d) => changes.push(d),
      f.request,
    ),
  ).toBe("/home?inventory=inv1");
  expect(f.writes).toEqual([
    "/organizations",
    "/organizations/org1/workspaces",
    "/inventory-workspaces/ws1/inventories",
  ]);
  expect(
    changes.find((d) => d.createdIds.organization)?.createdIds.workspace,
  ).toBeUndefined();
  expect(
    changes.find((d) => d.createdIds.workspace)?.createdIds.organization,
  ).toBe("org1");
  expect(localStorage.getItem(doneSetupKey("actor"))).toBe("1");
  expect(localStorage.getItem(pendingSetupKey("actor"))).toBeNull();
});
test("personal creates standalone workspace and inventory without changing Personal", async () => {
  const f = fixture();
  await provisionSetup(
    "actor",
    ready("personal"),
    localStorage,
    () => {},
    f.request,
  );
  expect(f.writes).toEqual(["/teams", "/inventory-workspaces/ws1/inventories"]);
  expect(f.calls).toHaveBeenCalledWith("actor", "/teams", {
    method: "POST",
    body: { name: "Workshop", program: "other" },
  });
  expect(f.orgs).toHaveLength(0);
});
test("a workspace-seeded default with the chosen custom name is reused", async () => {
  const f = fixture();
  f.inventories.push({
    inventory_id: "inv1",
    name: "Hardware",
    owner_user_id: "actor",
    is_default: true,
  });
  await provisionSetup("actor", ready(), localStorage, () => {}, f.request);
  expect(f.writes).toEqual([
    "/organizations",
    "/organizations/org1/workspaces",
  ]);
  expect(f.inventories).toHaveLength(1);
});
test.each([
  "/organizations",
  "/organizations/org1/workspaces",
  "/inventory-workspaces/ws1/inventories",
])("validation rejection at %s retries only missing record", async (path) => {
  const f = fixture();
  f.fail(path);
  await expect(
    provisionSetup("actor", ready(), localStorage, () => {}, f.request),
  ).rejects.toThrow();
  await provisionSetup(
    "actor",
    readSetup(localStorage, "actor"),
    localStorage,
    () => {},
    f.request,
  );
  expect(f.orgs).toHaveLength(1);
  expect(f.workspaces).toHaveLength(1);
  expect(f.inventories).toHaveLength(1);
  expect(f.writes.filter((p) => p !== path)).toHaveLength(2);
});
test.each([
  "/organizations",
  "/organizations/org1/workspaces",
  "/inventory-workspaces/ws1/inventories",
])("lost response at %s reconciles without repeating POST", async (path) => {
  const f = fixture();
  f.fail(path, true);
  await expect(
    provisionSetup("actor", ready(), localStorage, () => {}, f.request),
  ).rejects.toThrow();
  await provisionSetup(
    "actor",
    readSetup(localStorage, "actor"),
    localStorage,
    () => {},
    f.request,
  );
  expect(f.writes).toHaveLength(3);
  expect(f.orgs).toHaveLength(1);
  expect(f.workspaces).toHaveLength(1);
  expect(f.inventories).toHaveLength(1);
});
test("uncertain outcomes cannot blindly create duplicates", async () => {
  const f = fixture(),
    draft = ready();
  draft.attempts.organization = { baseline: [], uncertain: true };
  await expect(
    provisionSetup("actor", draft, localStorage, () => {}, f.request),
  ).rejects.toThrow(/not been confirmed/);
  expect(f.writes).toHaveLength(0);
});
test("existing organizations and iPhone workspaces suppress onboarding", async () => {
  const f = fixture();
  expect(await checkSetupEligibility("actor", newSetup(), f.request)).toBe(
    true,
  );
  f.workspaces.push({
    workspace_id: "iphone",
    name: "Workshop",
    owner_user_id: "actor",
    role: "owner",
  });
  expect(await checkSetupEligibility("actor", newSetup(), f.request)).toBe(
    false,
  );
  f.workspaces.length = 0;
  f.orgs.push({ organization_id: "org", name: "Lab", owner_user_id: "actor" });
  expect(await checkSetupEligibility("actor", newSetup(), f.request)).toBe(
    false,
  );
});
test("only the owner's interrupted setup may resume", async () => {
  const f = fixture();
  f.fail("/organizations/org1/workspaces");
  await expect(
    provisionSetup("actor", ready(), localStorage, () => {}, f.request),
  ).rejects.toThrow();
  const pending = readSetup(localStorage, "actor");
  expect(await checkSetupEligibility("actor", pending, f.request)).toBe(true);
  f.orgs[0].owner_user_id = "someone-else";
  expect(await checkSetupEligibility("actor", pending, f.request)).toBe(false);
});
test("a same-name workspace in the wrong organization cannot satisfy a receipt", async () => {
  const f = fixture(),
    draft = ready();
  draft.createdIds = { organization: "org1", workspace: "ws1" };
  f.orgs.push({
    organization_id: "org1",
    name: "Kestrel Labs",
    owner_user_id: "actor",
  });
  f.workspaces.push({
    workspace_id: "ws1",
    name: "R&D",
    owner_user_id: "actor",
    role: "owner",
    organization_id: "different",
  });
  expect(await checkSetupEligibility("actor", draft, f.request)).toBe(false);
});
test("failed directory reads never mean empty account", async () => {
  const request = jest
    .fn()
    .mockRejectedValue(new Error("offline")) as SetupRequest;
  await expect(
    checkSetupEligibility("actor", newSetup(), request),
  ).rejects.toThrow("offline");
});
test("skip opens existing Personal default and creates nothing", async () => {
  const f = fixture();
  f.inventories.push({
    inventory_id: "default",
    name: "My inventory",
    is_default: true,
  });
  expect(await personalDashboard("actor", f.request)).toBe(
    "/home?inventory=default",
  );
  finishSetup(localStorage, "actor");
  expect(f.writes).toHaveLength(0);
  expect(localStorage.getItem(doneSetupKey("actor"))).toBe("1");
  f.inventories.length = 0;
  expect(await personalDashboard("actor", f.request)).toBe(
    "/workspaces/personal",
  );
});
test("storage failure prevents any request", async () => {
  const f = fixture(),
    store = {
      getItem: () => null,
      removeItem: () => {},
      setItem: () => {
        throw new Error("quota");
      },
    };
  await expect(
    provisionSetup("actor", ready(), store, () => {}, f.request),
  ).rejects.toThrow("quota");
  expect(f.calls).not.toHaveBeenCalled();
});

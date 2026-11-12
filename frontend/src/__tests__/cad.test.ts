import { compareCad, previewBom, shortageCsv, type CadComparison } from "@/lib/cad";
import { apiRequest } from "@/lib/api";
import { inventoryApiPath, inventoryHref, isInventoryPage, requireInventoryContext, selectInventory, type InventorySelection } from "@/lib/inventory-selection";
import { INTERIOR_PATH_PREFIXES } from "@/lib/app-theme-constants";

jest.mock("@/lib/api", () => ({ apiRequest: jest.fn() }));
const request = jest.mocked(apiRequest);
const inventory = { inventory_id: "inv-a", accountId: "actor-a" } as InventorySelection;
const result = { inventory_id: "inv-a", revision: { id: "v1" }, inventory_as_of: "2026-11-10", items: [] } as unknown as CadComparison;

beforeEach(() => { request.mockReset(); selectInventory(inventory); requireInventoryContext(true); });
afterEach(() => { selectInventory(null); requireInventoryContext(false); });

test("CAD routes require and preserve selected inventory", () => {
  expect(isInventoryPage("/cad")).toBe(true);
  expect(INTERIOR_PATH_PREFIXES).toContain("/cad");
  expect(inventoryApiPath("/cad/compare")).toBe("/inventories/inv-a/cad/compare");
  expect(inventoryHref("/cad")).toBe("/cad?inventory=inv-a");
  selectInventory(null);
  expect(() => inventoryApiPath("/cad/compare")).toThrow("Choose an inventory");
});

test("only explicit valid file uploads use the scoped request", async () => {
  request.mockResolvedValue(result);
  const file = new File(["{}"], "bom.json");
  const controller = new AbortController();
  expect(await compareCad(file, controller.signal)).toBe(result);
  expect(request).toHaveBeenCalledWith("/cad/compare", expect.objectContaining({ method: "POST", signal: controller.signal }));
  await expect(compareCad(new File(["{}"], "robot.f3d"), controller.signal)).rejects.toThrow("Fusion JSON");
  expect(request).toHaveBeenCalledTimes(1);
});

test("switching inventory while comparison runs discards response", async () => {
  request.mockImplementation(async () => { selectInventory({ ...inventory, inventory_id: "inv-b" }); return result; });
  await expect(compareCad(new File(["{}"], "bom.json"), new AbortController().signal)).rejects.toThrow("inventory changed");
});

test("wrong response inventory is rejected", async () => {
  request.mockResolvedValue({ ...result, inventory_id: "other" });
  await expect(compareCad(new File(["{}"], "bom.json"), new AbortController().signal)).rejects.toThrow("inventory changed");
});

test("CSV exports only shortages and neutralizes spreadsheet formulas", () => {
  const csv = shortageCsv({ ...result, items: [
    { name: '=HYPERLINK("evil")', manufacturer: "+Bad", part_number: "00123", required: 8, assigned: 6, missing: 2, unit: "each", status: "short" },
    { name: "Covered component", missing: 0 },
  ] } as CadComparison);
  expect(csv).toContain("'=HYPERLINK");
  expect(csv).toContain("'+Bad");
  expect(csv).toContain('"00123"');
  expect(csv).not.toContain("Covered component");
});

test("spreadsheet preview and mapped comparison stay inventory-scoped", async () => {
  request.mockResolvedValue(result);
  const file = new File(["sheet"], "bom.xlsx"); const signal = new AbortController().signal;
  await previewBom(file, signal);
  expect(request).toHaveBeenLastCalledWith("/cad/preview", expect.objectContaining({ signal }));
  await compareCad(file, signal, {sheet:"Parts",mapping:{name:0,quantity:1},confirmed:true});
  const form = (request.mock.calls[1][1] as {body:FormData}).body;
  expect(form.get("sheet")).toBe("Parts");
  expect(form.get("mapping")).toBe('{"name":0,"quantity":1}');
  expect(form.get("flat_bom_confirmed")).toBe("true");
});

test("spreadsheet preview discards a response after inventory switch", async () => {
  request.mockImplementation(async () => {selectInventory({...inventory,inventory_id:"other"});return result;});
  await expect(previewBom(new File(["csv"],"bom.csv"),new AbortController().signal)).rejects.toThrow("inventory changed");
});

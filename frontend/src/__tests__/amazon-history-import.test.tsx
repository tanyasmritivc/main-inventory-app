/** @jest-environment jsdom */
import { render, screen, fireEvent, waitFor, cleanup } from "@testing-library/react";
import { AmazonHistoryImport } from "@/components/site/amazon-history-import";
jest.mock("@/components/site/commerce-client.module.css", () => new Proxy({}, { get: (_t, key) => key }));
const connection = { id: "c1", inventory_id: "inventory", provider: "amazon_consumer", status: "connected" };
const preview = { sha256: "a".repeat(64), count: 1, order_count: 1, duplicates_in_file: 0, committed: false, stock_effect: "none",
  records: [{ external_id: "o1:sku", order_id: "o1", title: "Motor", asin: "B000000001", quantity: 2, ordered_at: "2026-11-01T00:00:00Z", source_status: "returned" }] };
let request: jest.Mock;
const saved = jest.fn();
function mount(configured = true) {
  return render(<AmazonHistoryImport inventoryId="inventory" configured={configured} loading={false} request={request} onSaved={saved} />);
}
function choose(name = "Retail.OrderHistory.1.csv") {
  fireEvent.change(screen.getByLabelText("Amazon order-history file"), { target: { files: [new File(["sample"], name, { type: "text/csv" })] } });
}
beforeEach(() => {
  saved.mockReset(); saved.mockResolvedValue(undefined);
  request = jest.fn(async (path: string) => {
    if (path.endsWith("/preview")) return preview;
    if (path.startsWith("/commerce/connections?")) return { connections: [connection] };
    if (path.endsWith("/purchase-file")) return { committed: true, count: 1, sha256: preview.sha256, stock_effect: "none" };
    throw new Error("Unexpected request");
  });
});
afterEach(cleanup);
test("preview does not create or save, and returned purchases are unconfirmed", async () => {
  mount(); choose(); fireEvent.click(screen.getByRole("button", { name: "Preview order history" })); await screen.findByText("Motor");
  expect(request).toHaveBeenCalledTimes(1);
  const body = request.mock.calls[0][1].body as FormData;
  expect(body.get("inventory_id")).toBe("inventory"); expect(body.get("confirmed_sha256")).toBeNull();
  expect(screen.getByText("Ownership unconfirmed")).toBeTruthy();
  fireEvent.click(screen.getByRole("button", { name: "Cancel import" }));
  expect(screen.queryByText("Motor")).toBeNull(); expect(request).toHaveBeenCalledTimes(1);
});
test("save reuses destination and sends reviewed digest once, without stock writes", async () => {
  mount(); choose(); fireEvent.click(screen.getByRole("button", { name: "Preview order history" })); await screen.findByText("Motor");
  const save = screen.getByRole("button", { name: "Save purchase history" }); fireEvent.click(save); fireEvent.click(save);
  await screen.findByText(/Saved 1 purchase records/); expect(request).toHaveBeenCalledTimes(3);
  const call = request.mock.calls.find(c => c[0].endsWith("/purchase-file"))!;
  expect(call[1].body.get("confirmed_sha256")).toBe(preview.sha256); expect(saved).toHaveBeenCalledWith(connection);
  expect(request.mock.calls.every(c => c[0].startsWith("/commerce/"))).toBe(true);
});
test("new file invalidates preview and failed save keeps review available", async () => {
  mount(); choose(); fireEvent.click(screen.getByRole("button", { name: "Preview order history" })); await screen.findByText("Motor");
  request.mockRejectedValueOnce(new Error("Network unavailable")); fireEvent.click(screen.getByRole("button", { name: "Save purchase history" }));
  expect((await screen.findByRole("alert")).textContent).toContain("Network unavailable"); expect(screen.getByText("Motor")).toBeTruthy();
  choose("new.zip"); expect(screen.queryByRole("button", { name: "Save purchase history" })).toBeNull();
});
test("disabled provider and unsupported files cannot upload", () => {
  const view = mount(false); expect((screen.getByLabelText("Amazon order-history file") as HTMLInputElement).disabled).toBe(true);
  view.unmount(); mount(); choose("orders.pdf"); expect(screen.getByRole("alert").textContent).toContain("CSV or ZIP");
  expect((screen.getByRole("button", { name: "Preview order history" }) as HTMLButtonElement).disabled).toBe(true); expect(request).not.toHaveBeenCalled();
});
test("late preview after unmount does not create or save", async () => {
  let resolve!: (value: unknown) => void;
  request.mockImplementationOnce(() => new Promise(r => { resolve = r; }));
  const view = mount(); choose(); fireEvent.click(screen.getByRole("button", { name: "Preview order history" })); view.unmount();
  resolve(preview); await waitFor(() => expect(request).toHaveBeenCalledTimes(1)); expect(saved).not.toHaveBeenCalled();
});

test('personal scope preview and save work without inventory selection', async () => {
  const scoped = {...connection, inventory_id:null, scope_type:'personal',organization_id:null};
  request.mockImplementation(async (path: string) => path.endsWith('/preview') ? preview : path.includes('?') ? {connections:[scoped]} : {committed:true,count:1,sha256:preview.sha256,stock_effect:'none'});
  render(<AmazonHistoryImport scope={{scope_type:'personal'}} configured loading={false} request={request} onSaved={saved} />);
  choose(); fireEvent.click(screen.getByText('Preview order history')); await screen.findByText('Motor');
  expect(request.mock.calls[0][1].body.get('scope_type')).toBe('personal');
  expect(request.mock.calls[0][1].body.get('inventory_id')).toBeNull();
  fireEvent.click(screen.getByText('Save purchase history')); await screen.findByText(/Saved 1 purchase records/);
  expect(request).toHaveBeenCalledWith('/commerce/connections?scope_type=personal'); expect(saved).toHaveBeenCalledWith(scoped);
});
test('organization import rejects a returned personal destination before sending file', async () => {
  request.mockImplementation(async (path: string) => path.endsWith('/preview') ? preview : path.includes('?') ? {connections:[]} : {connection:{...connection,inventory_id:null,scope_type:'personal'}});
  render(<AmazonHistoryImport scope={{scope_type:'organization',organization_id:'org'}} ownerName="Team" configured loading={false} request={request} onSaved={saved} />);
  choose(); fireEvent.click(screen.getByText('Preview order history')); await screen.findByText('Motor');
  expect(screen.getByText(/Organization owners and administrators will/)).toBeTruthy();
  fireEvent.click(screen.getByText('Save purchase history')); await screen.findByRole('alert');
  expect(request.mock.calls.some(c=>c[0].endsWith('/purchase-file'))).toBe(false);
  expect(request).toHaveBeenCalledWith('/commerce/connections',expect.objectContaining({body:{scope_type:'organization',organization_id:'org',provider:'amazon_consumer'}}));
});

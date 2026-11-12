/** @jest-environment jsdom */
import { render, screen, waitFor, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PurchaseLibrary } from "@/components/site/purchase-library";
jest.mock("@/lib/commerce", () => ({ scopeQuery: (scope: {scope_type: string; organization_id?: string}) => new URLSearchParams(scope).toString() }));
const empty = { summary: { products: 0, orders: 0, records: 0 }, products: [], matched_products: 0, next_offset: null, complete: true };
const product = { key: "asin:B000000001", title: "Sample motor", asin: "B000000001", ordered_units: 2, excluded_units: 0, order_count: 1, last_ordered_at: "2026-11-01", orders: [{ order_id: "test-order", ordered_at: "2026-11-01", quantity: 2, source_status: "delivered", connection_status: "connected" }], history_truncated: false };
beforeEach(() => { Element.prototype.scrollIntoView = jest.fn(); });
test("groups purchases, exposes order evidence and checks in the selected scope", async () => {
  const user = userEvent.setup();
  const request = jest.fn().mockResolvedValueOnce({ ...empty, summary: { products:1, orders:1, records:1 }, matched_products:1, products:[product] })
    .mockResolvedValueOnce({ query:"B000000001", result:"review_before_buying", purchase_matches:[product], purchase_match_basis:"exact_asin", inventory_matches:[], suggestions:["Verify whether you still own it."], purchases_complete:true });
  render(<PurchaseLibrary scope={{scope_type:"personal"}} request={request} />);
  expect(await screen.findByText("Sample motor")).toBeTruthy();
  expect(screen.getByText("Ownership unconfirmed")).toBeTruthy();
  await user.click(screen.getByText("View order history"));
  expect(screen.getByText("Order test-order")).toBeTruthy();
  await user.click(screen.getByRole("button", {name:/Check against my inventory/}));
  expect(await screen.findByText("You may already have this")).toBeTruthy();
  expect(request).toHaveBeenLastCalledWith("/commerce/purchase-check", {method:"POST",body:{scope_type:"personal",query:"B000000001"}});
  expect(screen.getByText(/They are not a count of what you currently own/)).toBeTruthy();
});
test("an old owner response cannot replace the new owner's library", async () => {
  let resolve!: (result: unknown) => void;
  const request = jest.fn().mockImplementationOnce(() => new Promise(r => {resolve=r;})).mockResolvedValue(empty);
  const {rerender} = render(<PurchaseLibrary key="personal" scope={{scope_type:"personal"}} request={request} />);
  rerender(<PurchaseLibrary key="org" scope={{scope_type:"organization",organization_id:"team"}} request={request} />);
  await screen.findByText(/No saved purchases yet/);
  await act(async () => resolve({...empty,products:[product]}));
  expect(screen.queryByText("Sample motor")).toBeNull();
  expect(request).toHaveBeenLastCalledWith("/commerce/purchases?scope_type=organization&organization_id=team");
});
test("failed checks show an error instead of claiming there are no duplicates", async () => {
  const user = userEvent.setup();
  const request = jest.fn().mockResolvedValueOnce(empty).mockRejectedValueOnce(new Error("Connection changed. Try again."));
  render(<PurchaseLibrary scope={{scope_type:"personal"}} request={request} />);
  await screen.findByText(/No saved purchases yet/);
  await user.type(screen.getByLabelText("Product name, ASIN or full Amazon product link"),"motor");
  await user.click(screen.getByRole("button",{name:"Check before buying"}));
  await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("Connection changed"));
  expect(screen.queryByText("No match in the checked records")).toBeNull();
});
test("paging replaces products and searches all purchases with applied filters", async () => {
  const user = userEvent.setup();
  const first = {...product, title:"First page motor"};
  const second = {...product, key:"second", title:"Second page motor"};
  const page = {...empty, summary:{products:1500,orders:2000,records:3000}, page_size:25, matched_products:1500, next_offset:25, products:[first]};
  const request = jest.fn().mockResolvedValueOnce(page).mockResolvedValueOnce({...page, offset:25, next_offset:50,products:[second]}).mockResolvedValueOnce({...empty, products:[product],matched_products:1,page_size:25});
  render(<PurchaseLibrary scope={{scope_type:"personal"}} request={request} />);
  await screen.findByText("First page motor");
  await user.click(screen.getAllByRole("button", {name:"Next"})[0]);
  await screen.findByText("Second page motor");
  expect(screen.queryByText("First page motor")).toBeNull();
  expect(screen.getAllByText("Page 2 of 60")).toHaveLength(2);
  expect(request.mock.calls[1][0]).toContain("offset=25");
  await user.type(screen.getByLabelText("Search all purchases"), "B000000001");
  await user.click(screen.getByText("Filters", {selector:"summary"}));
  await user.selectOptions(screen.getByLabelText("Order status"),"returned");
  await user.selectOptions(screen.getByLabelText("Inventory evidence"),"unmatched");
  await user.click(screen.getByRole("button",{name:"Apply filters"}));
  await screen.findByText("Sample motor");
  expect(request.mock.calls[2][0]).toContain("offset=0");
  expect(request.mock.calls[2][0]).toContain("status=returned");
  expect(request.mock.calls[2][0]).toContain("inventory=unmatched");
  expect(request.mock.calls[2][0]).toContain("query=B000000001");
});
test("a failed page request preserves the current page and allows retry", async () => {
  const user = userEvent.setup();
  const request = jest.fn().mockResolvedValueOnce({...empty,products:[product],matched_products:100,next_offset:25}).mockRejectedValueOnce(new Error("Please retry"));
  render(<PurchaseLibrary scope={{scope_type:"personal"}} request={request} />);
  await screen.findByText("Sample motor");
  await user.click(screen.getAllByRole("button",{name:"Next"})[0]);
  expect((await screen.findByRole("alert")).textContent).toContain("Please retry");
  expect(screen.getByText("Sample motor")).toBeTruthy();
  expect(screen.getAllByText("Page 1 of 4")).toHaveLength(2);
  expect((screen.getAllByRole("button",{name:"Previous"})[0] as HTMLButtonElement).disabled).toBe(true);
});

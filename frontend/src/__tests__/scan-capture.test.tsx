/** @jest-environment jsdom */
import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ScanCenterClient } from "@/components/site/scan-center-client";
import * as api from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

jest.mock("@/lib/use-api-session");
jest.mock("@/lib/api", () => ({
  getSpaces: jest.fn(), bulkCreate: jest.fn(), extractFromImageMulti: jest.fn(),
  createSpace: jest.fn(), processBarcode: jest.fn(), updateReviewItem: jest.fn(),
}));
jest.mock("@/components/site/app-dialog-provider", () => ({ useAppDialog: () => ({ promptValue: jest.fn() }) }));
jest.mock("@/components/site/zxing-scanner", () => ({ BarcodeScanner: () => null }));
jest.mock("@/components/site/spreadsheet-import-modal", () => ({ SpreadsheetImportModal: () => null }));
const session = (accountId: string) => ({ accountId, token: accountId + "-token", loading: false, error: null }) as ReturnType<typeof useApiSession>;
const items = ["Soldering iron", "Hex bolt"].map(name => ({ name, category: "Tools", quantity: 1 }));

beforeEach(() => {
  jest.clearAllMocks();
  jest.mocked(useApiSession).mockReturnValue(session("a"));
  jest.mocked(api.getSpaces).mockResolvedValue([{ id: "space", name: "Workbench", created_at: null }]);
  jest.mocked(api.extractFromImageMulti).mockResolvedValue({ items, summary: { total_detected: 2, categories: {} } });
});

async function upload(container: HTMLElement) {
  await screen.findByRole("option", { name: "Workbench" });
  fireEvent.change(screen.getByRole("combobox", { name: "Destination Space" }), { target: { value: "Workbench" } });
  fireEvent.change(container.querySelector('input[type="file"]')!, { target: { files: [new File(["photo"], "drawer.jpg", { type: "image/jpeg" })] } });
}

test("partial save retains only failed drafts and retries the same identity", async () => {
  const user = userEvent.setup();
  const { container } = render(<ScanCenterClient />);
  await upload(container);
  await screen.findByLabelText("Item 2 name");
  jest.mocked(api.bulkCreate).mockResolvedValueOnce({ inserted: [{} as api.InventoryItem], accepted_indices: [0], failures: [{ index: 1, reason: "Retry" }] });
  await user.click(screen.getByRole("button", { name: "Save to Workbench" }));
  await screen.findByText(/1 item was not confirmed saved/);
  expect((screen.getByLabelText("Item 1 name") as HTMLInputElement).value).toBe("Hex bolt");
  expect(screen.queryByLabelText("Item 2 name")).toBeNull();
  const originalId = jest.mocked(api.bulkCreate).mock.calls[0][0].items[1].client_request_id;
  expect(originalId).toBeTruthy();
  jest.mocked(api.bulkCreate).mockResolvedValueOnce({ inserted: [{} as api.InventoryItem], accepted_indices: [0], failures: [] });
  await user.click(screen.getByRole("button", { name: "Save to Workbench" }));
  await waitFor(() => expect(screen.queryByLabelText("Item 1 name")).toBeNull());
  expect(jest.mocked(api.bulkCreate).mock.calls[1][0].items[0].client_request_id).toBe(originalId);
});

test("a late photo response cannot enter a different account", async () => {
  let complete!: (value: Awaited<ReturnType<typeof api.extractFromImageMulti>>) => void;
  jest.mocked(api.extractFromImageMulti).mockImplementation(() => new Promise(resolve => { complete = resolve; }));
  const { container, rerender } = render(<ScanCenterClient />);
  await upload(container);
  jest.mocked(useApiSession).mockReturnValue(session("b"));
  rerender(<ScanCenterClient />);
  await act(async () => complete({ items, summary: { total_detected: 2, categories: {} } }));
  expect(screen.queryByLabelText("Item 1 name")).toBeNull();
  expect(api.bulkCreate).not.toHaveBeenCalled();
  expect((screen.getByRole("combobox") as HTMLSelectElement).value).toBe("");
});

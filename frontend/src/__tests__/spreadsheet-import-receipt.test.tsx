/** @jest-environment jsdom */
import { render, screen, fireEvent } from "@testing-library/react";
import { SpreadsheetImportModal } from "@/components/site/spreadsheet-import-modal";
import { apiRequest } from "@/lib/api";
const push = jest.fn();
jest.mock("@/components/site/inventory-link", () => ({
  useInventoryRouter: () => ({ push }),
}));
jest.mock("@/components/ui/dialog", () => ({
  DialogClose: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}));
jest.mock("@/lib/api", () => ({ apiRequest: jest.fn() }));
const api = jest.mocked(apiRequest);
const source = {
  id: "session",
  filename: "qa.csv",
  revision: 1,
  status: "review",
  fields: ["name"],
  sheets: [
    {
      name: "Sheet1",
      headers: ["Name"],
      sample: [["Washer"]],
      suggested_mapping: { name: 0 },
      warnings: [],
    },
  ],
  rows: [
    {
      index: 0,
      source_row: 2,
      item: { name: "Washer", quantity: 1, location: "QA Shelf" },
      errors: [],
      duplicates: [],
      duplicate_rows: [],
    },
  ],
  decisions: null,
  receipts: {},
  counts: { imported: 0, skipped: 0, failed: 0, pending: 1 },
};
beforeEach(() => jest.clearAllMocks());
async function prepare() {
  const onSuccess = jest.fn();
  api.mockResolvedValueOnce(source);
  const { container } = render(
    <SpreadsheetImportModal
      spaceName="QA Shelf"
      token="test"
      onSuccess={onSuccess}
    />,
  );
  fireEvent.change(container.querySelector("input[type=file]")!, {
    target: { files: [new File(["name\nWasher"], "qa.csv")] },
  });
  await screen.findByText("Confirm import");
  return onSuccess;
}
test("partial import explains failed rows and opens the destination", async () => {
  const success = await prepare();
  api.mockResolvedValueOnce({
    ...source,
    status: "complete",
    decisions: { 0: "create" },
    receipts: {
      0: {
        status: "failed",
        message: "The destination changed. Start a new review.",
      },
    },
    counts: { imported: 0, skipped: 0, failed: 1, pending: 0 },
  });
  fireEvent.click(screen.getByText("Confirm import"));
  await screen.findByText("Import results");
  expect(
    screen.getByText("0 imported · 0 skipped · 1 failed · 0 pending"),
  ).toBeTruthy();
  expect(screen.getByText(/The destination changed/)).toBeTruthy();
  expect(success).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText("View inventory"));
  expect(push).toHaveBeenCalledWith("/inventory?space=QA%20Shelf");
});
test("malformed receipt never claims success", async () => {
  const success = await prepare();
  api.mockResolvedValueOnce({});
  fireEvent.click(screen.getByText("Confirm import"));
  expect(await screen.findByRole("alert")).toBeTruthy();
  expect(success).not.toHaveBeenCalled();
  expect(screen.queryByText("Import results")).toBeNull();
});

/** @jest-environment jsdom */
import { fireEvent, render, screen } from "@testing-library/react";
import { SpreadsheetImportModal } from "@/components/site/spreadsheet-import-modal";
import { apiRequest } from "@/lib/api";
jest.mock("@/components/site/inventory-link", () => ({
  useInventoryRouter: () => ({ push: jest.fn() }),
}));
jest.mock("@/lib/api", () => ({ apiRequest: jest.fn() }));
jest.mock("@/components/ui/dialog", () => ({
  DialogClose: ({ children }: { children: React.ReactNode }) => children,
}));
const api = jest.mocked(apiRequest);
const sheet = {
  name: "Sheet1",
  headers: ["Name", "Qty"],
  sample: [["Battery", "10"]],
  suggested_mapping: { name: 0, quantity: 1 },
  warnings: [],
};
const source = {
  id: "session",
  filename: "items.csv",
  revision: 0,
  status: "draft",
  fields: ["name", "quantity"],
  sheets: [sheet],
  rows: [],
  decisions: null,
  receipts: {},
  counts: { imported: 0, skipped: 0, failed: 0, pending: 0 },
};
const rows = [
  {
    index: 0,
    source_row: 2,
    item: { name: "Battery", quantity: 10, location: "Storage" },
    errors: [],
    duplicates: [],
    duplicate_rows: [],
    excluded: false,
  },
  {
    index: 1,
    source_row: 3,
    item: { name: "Cable", quantity: 4, location: "Storage" },
    errors: [],
    duplicates: [{ name: "Cable", location: "Storage" }],
    duplicate_rows: [],
    excluded: false,
  },
];
beforeEach(() => api.mockReset());
async function prepare() {
  api.mockResolvedValueOnce(source);
  render(
    <SpreadsheetImportModal
      spaceName="Storage"
      token="test"
      onSuccess={() => {}}
    />,
  );
  fireEvent.change(screen.getByLabelText("Import file"), {
    target: {
      files: [
        new File(["Name,Qty\nBattery,10"], "items.csv", { type: "text/csv" }),
      ],
    },
  });
  await screen.findByText("Preview rows");
  api.mockResolvedValueOnce({ ...source, revision: 1, status: "review", rows });
  fireEvent.click(screen.getByText("Preview rows"));
  await screen.findByText("Confirm import");
}
test("upload and mapping never create stock; duplicate defaults to skip", async () => {
  await prepare();
  expect(api).toHaveBeenCalledTimes(2);
  expect(
    (screen.getByLabelText("Action for row 3") as HTMLSelectElement).value,
  ).toBe("skip");
  api.mockResolvedValueOnce({
    ...source,
    revision: 1,
    status: "complete",
    rows,
    decisions: { 0: "create", 1: "skip" },
    counts: { imported: 1, skipped: 1, failed: 0, pending: 0 },
  });
  fireEvent.click(screen.getByText("Confirm import"));
  await screen.findByText("Import results");
  expect(api.mock.calls[2][1]?.body).toEqual({
    revision: 1,
    decisions: { 0: "create", 1: "skip" },
    retry_failed: false,
  });
});
test("unknown response locks choices and resumes same session", async () => {
  await prepare();
  api.mockRejectedValueOnce(new Error("offline"));
  fireEvent.click(screen.getByText("Confirm import"));
  await screen.findByRole("alert");
  expect(screen.queryByLabelText("Action for row 2")).toBeNull();
  const first = api.mock.calls[2];
  api.mockResolvedValueOnce({
    ...source,
    revision: 1,
    status: "complete",
    rows,
    decisions: { 0: "create", 1: "skip" },
    counts: { imported: 1, skipped: 1, failed: 0, pending: 0 },
  });
  fireEvent.click(screen.getByText("Resume import"));
  await screen.findByText("Import results");
  expect(api.mock.calls[3]).toEqual(first);
});
test("invalid file does not reach upload API", async () => {
  render(
    <SpreadsheetImportModal
      spaceName="Storage"
      token="test"
      onSuccess={() => {}}
    />,
  );
  fireEvent.change(screen.getByLabelText("Import file"), {
    target: { files: [new File(["bad"], "legacy.xls")] },
  });
  await screen.findByRole("alert");
  expect(api).not.toHaveBeenCalled();
});

test("changed mapping requires a new preview before import", async () => {
  await prepare();
  fireEvent.change(screen.getByLabelText("Map quantity"), {
    target: { value: "-1" },
  });
  expect(
    (screen.getByText("Confirm import") as HTMLButtonElement).disabled,
  ).toBe(true);
  expect(
    screen.getByText("Mapping changed. Preview rows again before continuing."),
  ).toBeTruthy();
});

/** @jest-environment jsdom */
import React from "react";
import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { CadClient } from "@/components/cad/cad-client";
import { compareCad, type CadComparison } from "@/lib/cad";

jest.mock("@/lib/cad", () => ({ compareCad: jest.fn(), shortageCsv: jest.fn() }));
jest.mock("@/lib/inventory-selection", () => ({ activeInventory: () => ({ name: "Synthetic team inventory" }) }));
const compare = jest.mocked(compareCad);
const result: CadComparison = {
  inventory_id: "inv-a", extraction_id: "export-1",
  document: { name: "Synthetic robot", external_id: "file" }, revision: { kind: "unsaved_session", id: "session:1", dirty: true, configuration: "" },
  summary: { required_units: 8, covered_units: 6, coverage_percent: 75, shortage_lines: 1, review_lines: 0 },
  completeness: "partial", warnings: ["A source reference needs review."], inventory_as_of: "2026-11-10T00:00:00Z",
  items: [{ key: "screw", name: "M3 Screw", part_number: "M3-12", manufacturer: "Example", required: 8,
    assigned: 6, missing: 2, unit: "each", status: "short", match_type: "exact", procurement_policy: "purchase", matches: [], possible_matches: 0 }],
};

beforeEach(() => compare.mockReset());

test("choosing a file does not upload until Compare is pressed", async () => {
  compare.mockResolvedValue(result);
  render(<CadClient />);
  fireEvent.change(screen.getByLabelText("Fusion BOM export"), { target: { files: [new File(["{}"], "bom.json")] } });
  expect(compare).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole("button", { name: "Compare with inventory" }));
  await screen.findByText("75%");
  expect(screen.getByText("Incomplete assembly information")).toBeTruthy();
  expect(screen.getByText("Unsaved design snapshot")).toBeTruthy();
  expect(screen.getByText("M3 Screw")).toBeTruthy();
  fireEvent.change(screen.getByRole("combobox"), { target: { value: "review" } });
  expect(screen.getByText("No components in this view.")).toBeTruthy();
});

test("failure is visible and old results are cleared", async () => {
  compare.mockRejectedValue(new Error("Permission changed. Try again."));
  render(<CadClient />);
  fireEvent.change(screen.getByLabelText("Fusion BOM export"), { target: { files: [new File(["{}"], "bom.json")] } });
  fireEvent.click(screen.getByRole("button", { name: "Compare with inventory" }));
  expect((await screen.findByRole("alert")).textContent).toContain("Permission changed");
});

test("unmount aborts the comparison", async () => {
  let signal: AbortSignal | undefined;
  compare.mockImplementation((_file, requestSignal) => { signal = requestSignal; return new Promise(() => {}); });
  const view = render(<CadClient />);
  fireEvent.change(screen.getByLabelText("Fusion BOM export"), { target: { files: [new File(["{}"], "bom.json")] } });
  fireEvent.click(screen.getByRole("button", { name: "Compare with inventory" }));
  await waitFor(() => expect(signal).toBeDefined());
  act(() => view.unmount());
  expect(signal?.aborted).toBe(true);
});

/** @jest-environment jsdom */
import React from "react";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { CadCorrection } from "@/components/cad/cad-correction";
import { accountRequest } from "@/lib/account-request";
import { activeInventory } from "@/lib/inventory-selection";
import type { CadLine } from "@/lib/cad";
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/inventory-selection", () => ({ activeInventory: jest.fn() }));
const line: CadLine = { key:"part", name:"Screw", part_number:"M3-12", manufacturer:"", required:8, assigned:0, missing:8, unit:"each", status:"needs_review", match_type:"probable", procurement_policy:"purchase", possible_matches:1, matches:[], review_token:"receipt", candidates:[{item_id:"item",name:"Screw",part_number:"M3-12",location:"Bin A"}] };
beforeEach(() => { jest.clearAllMocks(); (activeInventory as jest.Mock).mockReturnValue({accountId:"actor",can_edit:true}); });
test("correction saves against the initiating actor and refreshes only after success", async () => {
  (accountRequest as jest.Mock).mockResolvedValue({saved:true}); const refresh=jest.fn();
  render(<CadCorrection line={line} onRefresh={refresh} />);
  fireEvent.change(screen.getByLabelText("Match to"),{target:{value:"item"}});
  fireEvent.click(screen.getByText("Remember this match"));
  await waitFor(() => expect(refresh).toHaveBeenCalledTimes(1));
  expect(accountRequest).toHaveBeenCalledWith("actor","/cad/corrections",expect.objectContaining({method:"POST",body:JSON.stringify({review_token:"receipt",decision:"match",item_id:"item"})}));
});
test("failed saves remain visible and do not refresh", async () => {
  (accountRequest as jest.Mock).mockRejectedValue(new Error("Access revoked")); const refresh=jest.fn();
  render(<CadCorrection line={line} onRefresh={refresh} />);
  fireEvent.click(screen.getByText("None of these match"));
  expect(await screen.findByText("Access revoked")).not.toBeNull(); expect(refresh).not.toHaveBeenCalled();
});
test("viewers cannot edit shared corrections", () => {
  (activeInventory as jest.Mock).mockReturnValue({accountId:"actor",can_edit:false});
  const {container}=render(<CadCorrection line={line} onRefresh={jest.fn()} />); expect(container.innerHTML).toBe("");
});

/** @jest-environment jsdom */
import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import { OnshapeClient } from "@/components/cad/onshape-client";
import { accountRequest } from "@/lib/account-request";
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/inventory-selection", () => ({ activeInventory: () => ({ accountId:"actor", inventory_id:"inventory", name:"Team stock" }) }));
jest.mock("@/components/cad/cad-entry", () => ({ CadEntry: () => null }));
jest.mock("@/components/cad/cad-results", () => ({ CadResults: () => <p>Comparison results</p> }));
const initial = { document_id:"a".repeat(24),element_id:"b".repeat(24),wvm:"w" as const,wvm_id:"c".repeat(24),configuration:"Size=Small" };
beforeEach(() => jest.clearAllMocks());
test("a connected launch checks once and preserves the assembly configuration", async () => {
  (accountRequest as jest.Mock).mockImplementation((_actor,path) => Promise.resolve(path === "/onshape/connection" ? {enabled:true,connected:true} : {extraction_id:"one"}));
  render(<OnshapeClient initial={initial} />);
  await screen.findByText("Comparison results");
  expect((accountRequest as jest.Mock).mock.calls.filter(c => c[1] === "/cad/onshape/compare")).toHaveLength(1);
  expect(accountRequest).toHaveBeenCalledWith("actor","/cad/onshape/compare",expect.objectContaining({body:JSON.stringify(initial)}));
});
test("unregistered apps offer CSV without attempting provider access", async () => {
  (accountRequest as jest.Mock).mockResolvedValue({enabled:false,connected:false});
  render(<OnshapeClient initial={initial} />);
  await screen.findByText("Use your flattened BOM CSV today.");
  expect(accountRequest).toHaveBeenCalledTimes(1);
});
test("unmount aborts an in-flight comparison", async () => {
  (accountRequest as jest.Mock).mockImplementation((_actor,path) => path === "/onshape/connection" ? Promise.resolve({enabled:true,connected:true}) : new Promise(() => {}));
  const {unmount}=render(<OnshapeClient initial={initial} />);
  await waitFor(() => expect(accountRequest).toHaveBeenCalledTimes(2));
  const signal=(accountRequest as jest.Mock).mock.calls[1][2].signal as AbortSignal;
  unmount(); expect(signal.aborted).toBe(true);
});

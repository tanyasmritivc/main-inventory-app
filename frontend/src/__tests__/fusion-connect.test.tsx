/** @jest-environment jsdom */
import React from "react";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { FusionConnect } from "@/components/cad/fusion-connect";
import { accountRequest } from "@/lib/account-request";
import { activeInventory } from "@/lib/inventory-selection";
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/inventory-selection", () => ({ activeInventory: jest.fn() }));
jest.mock("@/components/site/app-shell", () => ({ AppShell: ({children}: {children:React.ReactNode}) => <>{children}</> }));
beforeEach(() => { jest.clearAllMocks(); (activeInventory as jest.Mock).mockReturnValue({accountId:'actor',inventory_id:'inventory',name:'Team stock',can_edit:true}); (accountRequest as jest.Mock).mockImplementation((_actor,path) => Promise.resolve(path === "/fusion/connections" ? {connections:[]} : {approved:true})); });
test("pairing requires a matching-code confirmation and scopes the approved inventory", async () => {
  render(<FusionConnect code="ABCD234567" />);
  await screen.findByText(/No active connections/);
  const button = screen.getByRole("button", {name:"Connect this inventory"});
  expect((button as HTMLButtonElement).disabled).toBe(true);
  fireEvent.click(screen.getByRole("checkbox"));
  fireEvent.click(button);
  await screen.findByText("Connection approved");
  expect(accountRequest).toHaveBeenCalledWith("actor","/fusion/pairing/approve",expect.objectContaining({method:"POST",body:{code:"ABCD234567",inventory_id:"inventory"}}));
});
test("editing the code clears confirmation and an expired code retains the draft", async () => {
  (accountRequest as jest.Mock).mockImplementation((_actor,path) => path === "/fusion/connections" ? Promise.resolve({connections:[]}) : Promise.reject(new Error("Connection expired")));
  render(<FusionConnect code="ABCD234567" />);
  await screen.findByText(/No active connections/);
  fireEvent.click(screen.getByRole("checkbox"));
  fireEvent.change(screen.getByRole("textbox"),{target:{value:"ABCD234568"}});
  expect((screen.getByRole("checkbox") as HTMLInputElement).checked).toBe(false);
  fireEvent.click(screen.getByRole("checkbox"));fireEvent.click(screen.getByText("Connect this inventory"));
  await screen.findByRole("alert");
  expect((screen.getByRole("textbox") as HTMLInputElement).value).toBe("ABCD234568");
  expect(screen.queryByText("Connection approved")).toBeNull();
});
test("unmount aborts approval and rapid duplicate clicks submit once", async () => {
  (accountRequest as jest.Mock).mockImplementation((_actor,path) => path === "/fusion/connections" ? Promise.resolve({connections:[]}) : new Promise(() => {}));
  const {unmount}=render(<FusionConnect code="ABCD234567" />);
  await screen.findByText(/No active connections/);fireEvent.click(screen.getByRole("checkbox"));
  const button=screen.getByText("Connect this inventory");fireEvent.click(button);fireEvent.click(button);
  await waitFor(() => expect(accountRequest).toHaveBeenCalledTimes(2));
  const signal=(accountRequest as jest.Mock).mock.calls[1][2].signal;
  unmount();expect(signal.aborted).toBe(true);
});
test("disconnect removes only a confirmed revoked connection", async () => {
  (accountRequest as jest.Mock).mockImplementation((_actor,path) => path === "/fusion/connections" ? Promise.resolve({connections:[{id:"one",inventory_id:"inventory",session_expires_at:"2026-11-16T00:00:00Z"}]}) : Promise.resolve({disconnected:true}));
  render(<FusionConnect code="" />);
  fireEvent.click(await screen.findByRole("button",{name:"Disconnect"}));
  await screen.findByText(/No active connections/);
  expect(accountRequest).toHaveBeenCalledWith("actor","/fusion/connections/one",expect.objectContaining({method:"DELETE"}));
});

test('CAD writes require both editor access and a separate unchecked opt-in',async()=>{
 (accountRequest as jest.Mock).mockImplementation((_actor,path)=>Promise.resolve(path==='/fusion/connections'?{connections:[],cad_writes_enabled:true}:{approved:true}));
 render(<FusionConnect code="ABCD234567" />);
 const write=await screen.findByRole('checkbox',{name:/Also allow this Fusion session/});
 expect((write as HTMLInputElement).checked).toBe(false);
 fireEvent.click(write);fireEvent.click(screen.getByRole('checkbox',{name:/I started/}));fireEvent.click(screen.getByText('Connect this inventory'));
 await screen.findByText('Connection approved');
 expect(accountRequest).toHaveBeenLastCalledWith('actor','/fusion/pairing/approve',expect.objectContaining({body:{code:'ABCD234567',inventory_id:'inventory',allow_cad_writes:true}}));
});
test('viewers never receive a CAD-write checkbox',async()=>{
 (activeInventory as jest.Mock).mockReturnValue({accountId:'actor',inventory_id:'inventory',name:'Team stock',can_edit:false});
 (accountRequest as jest.Mock).mockResolvedValue({connections:[],cad_writes_enabled:true});
 render(<FusionConnect code="ABCD234567" />);await screen.findByText(/No active connections/);
 expect(screen.queryByRole('checkbox',{name:/Also allow/})).toBeNull();
});

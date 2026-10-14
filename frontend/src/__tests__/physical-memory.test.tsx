/** @jest-environment jsdom */
import React from "react";
import { act,fireEvent,render,screen,waitFor } from "@testing-library/react";
import { PhysicalMemoryPanel } from "@/components/site/physical-memory-panel";
import { AppDialogProvider } from "@/components/site/app-dialog-provider";
import * as api from "@/lib/physical-memory";
let account="actor-a";
jest.mock("@/lib/use-api-session",()=>({useApiSession:()=>({accountId:account})}));
jest.mock("@/lib/physical-memory",()=>({...jest.requireActual("@/lib/physical-memory"),getPhysicalOptions:jest.fn(),askPhysical:jest.fn(),confirmPhysical:jest.fn(),physicalHistory:jest.fn()}));
const options=jest.mocked(api.getPhysicalOptions),ask=jest.mocked(api.askPhysical),save=jest.mocked(api.confirmPhysical),history=jest.mocked(api.physicalHistory);
const candidate:api.PhysicalCandidate={memory_id:null,native_label:null,connection_id:"store-a",variant_gid:"gid://shopify/ProductVariant/30",product_title:"Hoodie",variant_title:"Black M",sku:"Same-SKU",barcodes:[{value:"0012"}],catalog_deleted:false,connection_status:"connected",tracked:true,placements:[],shopify_inventory:[]};
const answer=(candidates:api.PhysicalCandidate[]=[candidate]):api.PhysicalAnswer=>({kind:candidates.length>1?"clarification":"locations",assistant_message:candidates.length>1?"Choose the variant you mean.":"No physical location confirmed. Shopify stock is a separate snapshot.",result:{candidates,truncated:false},answer_context:{sources:[]}});
function view(team="team-a"){return <AppDialogProvider><PhysicalMemoryPanel teamId={team}/></AppDialogProvider>;}
async function search(){fireEvent.change(screen.getByLabelText("Ask this Team"),{target:{value:"Where is the black medium hoodie?"}});fireEvent.click(screen.getByText("Find"));await screen.findByText("Confirm a physical location");}
async function form(count=""){await search();fireEvent.change(screen.getByLabelText("FindEZ name"),{target:{value:"Our black hoodie"}});fireEvent.change(screen.getByLabelText("Space"),{target:{value:"space-a"}});fireEvent.change(screen.getByLabelText("Bin"),{target:{value:"bin-12"}});if(count)fireEvent.change(screen.getByLabelText("Count observed here (optional)"),{target:{value:count}});}
beforeEach(()=>{jest.resetAllMocks();account="actor-a";options.mockResolvedValue({can_confirm:true,spaces:[{id:"space-a",name:"Stockroom",bins:[{id:"bin-12",name:"Bin 12"}]}]});ask.mockResolvedValue(answer());let i=0;Object.defineProperty(global.crypto,"randomUUID",{configurable:true,value:()=>`save-${++i}`});});

test("failed save retains authored name, destination and the same retry identity",async()=>{
  save.mockRejectedValue(new Error("Could not save location."));render(view());await form();
  fireEvent.click(screen.getByText("Confirm location"));await screen.findByRole("alert");
  expect((screen.getByLabelText("FindEZ name") as HTMLInputElement).value).toBe("Our black hoodie");
  expect((screen.getByLabelText("Space") as HTMLSelectElement).value).toBe("space-a");
  const first=save.mock.calls[0][2];expect(first.observed_count).toBeNull();expect(first.bin_id).toBe("bin-12");
  fireEvent.click(screen.getByText("Confirm location"));await waitFor(()=>expect(save).toHaveBeenCalledTimes(2));
  expect(save.mock.calls[1][2].request_id).toBe(first.request_id);
});

test("explicit zero stays zero and confirmation waits for server receipt",async()=>{
  let resolve!:(value:Awaited<ReturnType<typeof api.confirmPhysical>>)=>void;
  save.mockImplementation(()=>new Promise(done=>{resolve=done;}));render(view());await form("0");
  fireEvent.click(screen.getByText("Confirm location"));fireEvent.click(screen.getByText("Saving..."));
  expect(save).toHaveBeenCalledTimes(1);expect(save.mock.calls[0][2].observed_count).toBe(0);
  expect(screen.queryByText("Location confirmation saved.")).toBeNull();
  await act(async()=>{resolve({memory_id:"memory-a",placement_id:"placement-a",revision:1,observation_id:"observation-a"});});
  await waitFor(()=>expect(ask).toHaveBeenCalledTimes(2));
});

test("viewer lookup cannot open a write form",async()=>{
  options.mockResolvedValue({can_confirm:false,spaces:[]});render(view());
  fireEvent.change(screen.getByLabelText("Ask this Team"),{target:{value:"Where is hoodie?"}});fireEvent.click(screen.getByText("Find"));
  await screen.findByText(/You have view-only access/);expect(screen.queryByText("Confirm location")).toBeNull();expect(save).not.toHaveBeenCalled();
});

test("ambiguous identities require a choice before confirmation",async()=>{
  ask.mockResolvedValueOnce(answer([candidate,{...candidate,variant_gid:"gid://shopify/ProductVariant/31",variant_title:"Black L"}])).mockResolvedValue(answer());render(view());
  fireEvent.change(screen.getByLabelText("Ask this Team"),{target:{value:"Where is hoodie?"}});fireEvent.click(screen.getByText("Find"));
  await screen.findByText("Choose the variant you mean.");expect(screen.queryByText("Confirm location")).toBeNull();
  fireEvent.click(screen.getByText("Hoodie / Black L"));await screen.findByText("Confirm location");
  expect(ask.mock.calls[1][2].variant_gid).toBe("gid://shopify/ProductVariant/31");
});

test("barcode mode preserves leading zeros and binds confirmation evidence",async()=>{
  render(view());fireEvent.click(screen.getByText("Search by barcode"));fireEvent.change(screen.getByLabelText("Exact barcode"),{target:{value:"0012"}});fireEvent.click(screen.getByText("Find"));await screen.findByText("Confirm a physical location");
  expect(ask.mock.calls[0][2].barcode).toBe("0012");
});

test("Team/account switch ignores a late private result",async()=>{
  let resolve!:(value:api.PhysicalAnswer)=>void;ask.mockImplementation(()=>new Promise(done=>{resolve=done;}));
  const ui=render(view());fireEvent.change(screen.getByLabelText("Ask this Team"),{target:{value:"Where is hoodie?"}});fireEvent.click(screen.getByText("Find"));
  account="actor-b";ui.rerender(view("team-b"));
  await act(async()=>{resolve(answer());});
  expect(screen.queryByText("Confirm a physical location")).toBeNull();expect((screen.getByLabelText("Ask this Team") as HTMLInputElement).value).toBe("");
  await waitFor(()=>expect(options).toHaveBeenLastCalledWith("team-b","actor-b"));
});

test("options can finish after lookup without being discarded",async()=>{
  let resolve!:(value:api.PhysicalOptions)=>void;options.mockImplementation(()=>new Promise(done=>{resolve=done;}));render(view());
  fireEvent.change(screen.getByLabelText("Ask this Team"),{target:{value:"Where is hoodie?"}});fireEvent.click(screen.getByText("Find"));
  await screen.findByText(/No physical location confirmed/);
  await act(async()=>{resolve({can_confirm:true,spaces:[]});});await screen.findByText("Confirm a physical location");
});

test("reconfirmation uses the native memory and revision, not a new catalog import",async()=>{
  const recorded={...candidate,memory_id:"memory-a",native_label:"Our hoodie",placements:[{placement_id:"place-a",revision:3,space_id:"space-a",space_name:"Stockroom",bin_id:"bin-12",bin_name:"Bin 12",observed_count:4,actor_id:"alex",actor_label:"Alex",confirmed_at:"2026-10-13T10:00:00Z",source_kind:"catalog_selection"}]};
  ask.mockResolvedValue(answer([recorded]));save.mockRejectedValue(new Error("Refresh after a conflict."));history.mockResolvedValue({observations:[]});render(view());await search();
  fireEvent.change(screen.getByLabelText("Confirmation"),{target:{value:"place-a"}});fireEvent.change(screen.getByLabelText("Count observed here (optional)"),{target:{value:"5"}});fireEvent.click(screen.getByText("Confirm location"));await screen.findByRole("alert");
  expect(save.mock.calls[0][2]).toMatchObject({memory_id:"memory-a",placement_id:"place-a",expected_revision:3,observed_count:5});expect(save.mock.calls[0][2].connection_id).toBeUndefined();
  expect((screen.getByLabelText("Count observed here (optional)") as HTMLInputElement).value).toBe("5");
  fireEvent.click(screen.getByText("History"));await screen.findByText("Confirmation history");expect(history).toHaveBeenCalledWith("team-a","actor-a","place-a");
});

test("revoked save clears private results and the confirmation draft",async()=>{
  save.mockRejectedValue(Object.assign(new Error("Permission denied"),{status:403}));render(view());await form();
  fireEvent.click(screen.getByText("Confirm location"));await screen.findByText("Your Team access changed. Reopen this Team.");
  expect(screen.queryByLabelText("FindEZ name")).toBeNull();expect(screen.queryByText(/No physical location confirmed/)).toBeNull();
  expect((screen.getByLabelText("Ask this Team") as HTMLInputElement).value).toBe("");
});

test("pending confirmation blocks changing the lookup",async()=>{
  save.mockImplementation(()=>new Promise(()=>{}));render(view());await form();fireEvent.click(screen.getByText("Confirm location"));
  expect((screen.getByText("Find") as HTMLButtonElement).disabled).toBe(true);expect((screen.getByLabelText("Ask this Team") as HTMLInputElement).disabled).toBe(true);
});

test("focus rechecks membership and clears a revoked result",async()=>{
  render(view());await form();options.mockRejectedValue(Object.assign(new Error("Permission denied"),{status:403}));
  fireEvent(window,new Event("focus"));await screen.findByText("Your Team access changed. Reopen this Team.");
  expect(screen.queryByLabelText("FindEZ name")).toBeNull();
});

test("guided variant opens a scoped lookup and a reviewable name without saving",async()=>{
  render(<AppDialogProvider><PhysicalMemoryPanel teamId="team-a" initialSelection={{connection_id:"store-a",variant_gid:"gid://shopify/ProductVariant/30"}}/></AppDialogProvider>);
  await screen.findByLabelText("FindEZ name");
  expect(ask).toHaveBeenCalledTimes(1);
  expect(ask).toHaveBeenCalledWith("team-a","actor-a",{question:"Where is this product?",connection_id:"store-a",variant_gid:"gid://shopify/ProductVariant/30"});
  expect((screen.getByLabelText("FindEZ name") as HTMLInputElement).value).toBe("Hoodie / Black M");
  expect(save).not.toHaveBeenCalled();
  fireEvent.change(screen.getByLabelText("FindEZ name"),{target:{value:"Our stockroom hoodie"}});
  fireEvent.change(screen.getByLabelText("Space"),{target:{value:"space-a"}});
  save.mockRejectedValue(new Error("Try again"));fireEvent.click(screen.getByText("Confirm location"));await screen.findByRole("alert");
  expect(save.mock.calls[0][2]).toMatchObject({native_label:"Our stockroom hoodie",connection_id:"store-a",variant_gid:"gid://shopify/ProductVariant/30",space_id:"space-a",observed_count:null});
});

test("suggestions omit Shopify's default variant and preserve existing native names",()=>{
  expect(api.suggestedMemoryName({...candidate,variant_title:"Default Title"})).toBe("Hoodie");
  expect(api.suggestedMemoryName({...candidate,native_label:"Our  original name"})).toBe("Our  original name");
  expect(api.suggestedMemoryName({...candidate,product_title:"  Hoodie\nshirt\t ",variant_title:null})).toBe("Hoodie shirt");
  expect(Array.from(api.suggestedMemoryName({...candidate,product_title:"😀".repeat(201),variant_title:null}))).toHaveLength(200);
});

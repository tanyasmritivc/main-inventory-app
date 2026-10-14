/** @jest-environment jsdom */
import React from "react";
import {act,fireEvent,render,screen,waitFor} from "@testing-library/react";
import {MerchantMigrationGuide} from "@/components/site/merchant-migration-guide";
import * as api from "@/lib/shopify";

jest.mock("@/lib/shopify",()=>({...jest.requireActual("@/lib/shopify"),getMerchantProgress:jest.fn()}));
const progress=jest.mocked(api.getMerchantProgress);
const store:api.ShopifyConnection={connection_id:"store-a",shop_domain:"pilot.myshopify.com",shop_name:"Pilot",status:"connected",sync_status:"idle",last_attempt_at:null,last_success_at:"2026-10-13T10:00:00Z",error_code:null};
const variant:api.MigrationVariant={variant_gid:"gid://shopify/ProductVariant/30",product_title:"Hoodie",variant_title:"Black M",sku:"Shared-SKU"};
const report:api.MerchantProgress={connection_id:"store-a",checked_at:"2026-10-13T10:00:00Z",can_confirm:true,space_count:1,import_complete:true,last_complete_sync:"2026-10-13T10:00:00Z",total_variants:3,confirmed_variants:1,unconfirmed_variants:2,older_confirmations:1,unconfirmed_sample:[variant,{...variant,variant_gid:"gid://shopify/ProductVariant/31",variant_title:"Black L"}],confirmed_example:{...variant,variant_gid:"gid://shopify/ProductVariant/32",variant_title:"White M"}};
const open=jest.fn(),spaces=jest.fn();
function view(team="team-a",token="actor-a",connection=store) {return <MerchantMigrationGuide teamId={team} token={token} store={connection} onOpenMemory={open} onOpenSpaces={spaces}/>;}
beforeEach(()=>{jest.resetAllMocks();progress.mockResolvedValue(report);});

test("actual progress labels old confirmations and passes stable IDs to existing confirmation",async()=>{
  render(view());await screen.findByText(/1 of 3 variants have an accessible confirmed location/);
  expect(screen.getByText(/at least 7 days old/)).toBeTruthy();
  expect(screen.getByText(/Catalog images and stock records do not confirm/)).toBeTruthy();
  fireEvent.click(screen.getAllByText("Confirm location")[1]);
  expect(open).toHaveBeenCalledWith({connection_id:"store-a",variant_gid:"gid://shopify/ProductVariant/31"});
  expect(progress).toHaveBeenCalledWith("team-a","store-a","actor-a");
});

test("lookup uses an actually confirmed example and does not mark finding as completed",async()=>{
  render(view());fireEvent.click(await screen.findByText("Locate Hoodie / White M"));
  expect(open).toHaveBeenCalledWith({connection_id:"store-a",variant_gid:"gid://shopify/ProductVariant/32"});
  expect(screen.getByText("4")).toBeTruthy();
});

test("partial import never displays a completed import even when the available subset is mapped",async()=>{
  progress.mockResolvedValue({...report,import_complete:false,confirmed_variants:3,unconfirmed_variants:0,unconfirmed_sample:[]});
  render(view("team-a","actor-a",{...store,sync_status:"syncing"}));
  await screen.findByText(/current import has not completed/);
  expect(screen.getByText(/available records may be incomplete/)).toBeTruthy();
  expect(screen.getByText("2")).toBeTruthy();expect(screen.getByText("3")).toBeTruthy();
});

test("viewer can read progress but cannot begin mapping",async()=>{
  progress.mockResolvedValue({...report,can_confirm:false});render(view());
  await screen.findByText("An authorized editor can confirm storage.");
  for(const button of screen.getAllByRole("button",{name:"Confirm location"})) expect((button as HTMLButtonElement).disabled).toBe(true);
  expect(open).not.toHaveBeenCalled();
});

test("no linked storage offers existing Space setup without creating data",async()=>{
  progress.mockResolvedValue({...report,space_count:0,confirmed_variants:0,confirmed_example:null});render(view());
  fireEvent.click(await screen.findByText("Set up storage Spaces"));expect(spaces).toHaveBeenCalledTimes(1);
  expect(screen.queryByText("Confirm location")).toBeNull();expect(open).not.toHaveBeenCalled();
});

test.each([false,true])("empty catalog separates completed from waiting import (%s)",async complete=>{
  progress.mockResolvedValue({...report,import_complete:complete,total_variants:0,confirmed_variants:0,unconfirmed_variants:0,older_confirmations:0,unconfirmed_sample:[],confirmed_example:null});render(view());
  await screen.findByText(complete?/No current variants were found in the completed catalog/:/No variants are available yet/);
  expect(screen.queryByText("Confirm location")).toBeNull();expect(screen.queryByText(/Locate Hoodie/)).toBeNull();
});

test("revoked refresh removes private progress and queue",async()=>{
  render(view());await screen.findByText("Hoodie / Black L");
  progress.mockRejectedValue(Object.assign(new Error("Team access changed"),{status:403}));
  fireEvent(window,new Event("focus"));await screen.findByRole("alert");
  expect(screen.queryByText("Hoodie / Black L")).toBeNull();expect(screen.queryByText("Confirm location")).toBeNull();
});

test("Team/account switch clears records and discards the old pending response",async()=>{
  let resolve!:(value:api.MerchantProgress)=>void;
  progress.mockImplementationOnce(()=>new Promise(done=>{resolve=done;}));const ui=render(view());
  await waitFor(()=>expect(progress).toHaveBeenCalledTimes(1));
  progress.mockResolvedValue({...report,total_variants:0,confirmed_variants:0,unconfirmed_variants:0,older_confirmations:0,unconfirmed_sample:[],confirmed_example:null});
  ui.rerender(view("team-b","actor-b",{...store,connection_id:"store-b"}));
  await waitFor(()=>expect(progress).toHaveBeenLastCalledWith("team-b","store-b","actor-b"));
  await act(async()=>{resolve(report);});
  expect(screen.queryByText("Hoodie / Black L")).toBeNull();expect(open).not.toHaveBeenCalled();
});

test("reconnect keeps cached progress labeled and disables confirmation",async()=>{
  progress.mockResolvedValue({...report,can_confirm:false});render(view("team-a","actor-a",{...store,status:"reconnect_required"}));
  await screen.findByText(/Renew Shopify access before adding locations/);
  expect(screen.getByText("1")).toBeTruthy();
  expect((screen.getAllByRole("button",{name:"Confirm location"})[0] as HTMLButtonElement).disabled).toBe(true);
});

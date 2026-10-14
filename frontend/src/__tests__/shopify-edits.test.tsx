/** @jest-environment jsdom */
import React from "react";
import {act,fireEvent,render,screen,waitFor} from "@testing-library/react";
import {ShopifyPermissionsForm,ShopifyVariantEdits,ShopifyEditHistory} from "@/components/site/shopify-edit-controls";
import {ShopifyConnection,ShopifyVariant,ShopifyEdit,saveShopifyPermissions,refreshShopifyPermissions,prepareShopifyEdit,executeShopifyEdit,getShopifyEdit,getShopifyEdits,reviewUnknownShopifyEdit} from "@/lib/shopify";

const approve=jest.fn();
jest.mock("@/components/site/app-dialog-provider",()=>({useAppDialog:()=>({confirmAction:approve})}));
jest.mock("@/lib/shopify",()=>({saveShopifyPermissions:jest.fn(),refreshShopifyPermissions:jest.fn(),prepareShopifyEdit:jest.fn(),executeShopifyEdit:jest.fn(),getShopifyEdit:jest.fn(),getShopifyEdits:jest.fn(),reviewUnknownShopifyEdit:jest.fn()}));
const store:ShopifyConnection={connection_id:"store",shop_domain:"test.myshopify.com",shop_name:"Test",status:"connected",sync_status:"idle",last_attempt_at:null,last_success_at:null,error_code:null,edit_products:false,edit_inventory:false,edit_access:"owner",permission_revision:7,granted_scopes:["read_products","read_inventory"],can_edit_inventory:true,can_edit_products:true};
const variant:ShopifyVariant={variant_gid:"gid://shopify/ProductVariant/1",product_title:"Hoodie",variant_title:"Black M",product_status:"ACTIVE",options:[],sku:"hoodie-m",barcodes:[],image_url:null,tracked:true,synced_at:"2026-10-13T10:00:00Z",shopify_inventory:[{location_gid:"gid://shopify/Location/1",location_name:"Stockroom",location_active:true,quantities:{available:8},synced_at:"2026-10-13T10:00:00Z"}]};
const operation:ShopifyEdit={operation_id:"op",kind:"inventory",state:"prepared",intent:{delta:2,location_gid:"gid://shopify/Location/1"},snapshot:{available:8,location_name:"Stockroom",checked_at:"2026-10-13T10:00:00Z",variant_title:"Black M"}};
const changed=jest.fn(),authorize=jest.fn();
beforeEach(()=>{jest.clearAllMocks();approve.mockResolvedValue(true);changed.mockResolvedValue(undefined);jest.mocked(saveShopifyPermissions).mockResolvedValue({saved:true,revision:8,needs_authorization:true,revocation_pending:false});jest.mocked(refreshShopifyPermissions).mockResolvedValue({needs_authorization:false,revocation_pending:false});jest.mocked(prepareShopifyEdit).mockResolvedValue(operation);jest.mocked(executeShopifyEdit).mockResolvedValue({...operation,state:"succeeded"});jest.mocked(getShopifyEdit).mockResolvedValue({...operation,state:"unknown"});jest.mocked(getShopifyEdits).mockResolvedValue({operations:[]});});
function permissions(next=store,enabled=true){return <ShopifyPermissionsForm teamId="team" token="token" store={next} onChanged={changed} onAuthorize={authorize} editsEnabled={enabled}/>;}
function controls(next=store,key="current"){return <ShopifyVariantEdits key={key} teamId="team" token="token" store={next} variant={variant} onChanged={changed}/>;}
async function reviewStock(){fireEvent.click(screen.getByRole("button",{name:"Adjust Shopify stock"}));fireEvent.change(screen.getByLabelText("Shopify location"),{target:{value:"gid://shopify/Location/1"}});fireEvent.change(screen.getByLabelText("Adjustment"),{target:{value:"+2"}});fireEvent.click(screen.getByRole("button",{name:"Review change"}));await screen.findByRole("button",{name:"Apply in Shopify"});}

test("owner independently selects stock and product edits then explicitly approves Shopify",async()=>{
  render(permissions());fireEvent.click(screen.getByText("Connection permissions"));
  fireEvent.click(screen.getByLabelText("Allow stock adjustments"));fireEvent.change(screen.getByLabelText("Who can edit"),{target:{value:"editors"}});
  expect(saveShopifyPermissions).not.toHaveBeenCalled();fireEvent.click(screen.getByRole("button",{name:"Save permissions"}));
  await screen.findByText("Owner permissions saved.");
  expect(saveShopifyPermissions).toHaveBeenCalledWith("team","store","token",{edit_products:false,edit_inventory:true,edit_access:"editors",expected_revision:7});
  expect(authorize).not.toHaveBeenCalled();fireEvent.click(screen.getByRole("button",{name:"Approve in Shopify"}));expect(authorize).toHaveBeenCalledTimes(1);
});
test("permission downgrade remains visible if external grant removal is unconfirmed",async()=>{
  jest.mocked(saveShopifyPermissions).mockResolvedValue({saved:true,revision:8,needs_authorization:null,revocation_pending:true});
  render(permissions({...store,edit_inventory:true,granted_scopes:["read_products","write_inventory"]}));fireEvent.click(screen.getByText("Connection permissions"));fireEvent.click(screen.getByLabelText("Allow stock adjustments"));fireEvent.click(screen.getByRole("button",{name:"Save permissions"}));
  await screen.findByText(/FindEZ uses your saved restrictions/);expect(saveShopifyPermissions).toHaveBeenCalledWith("team","store","token",expect.objectContaining({edit_inventory:false}));
});
test("cancelled permission approval does not save or authorize",async()=>{
  approve.mockResolvedValue(false);render(permissions());fireEvent.click(screen.getByText("Connection permissions"));fireEvent.click(screen.getByRole("button",{name:"Save permissions"}));await waitFor(()=>expect(approve).toHaveBeenCalled());expect(saveShopifyPermissions).not.toHaveBeenCalled();expect(authorize).not.toHaveBeenCalled();
});
test("disabled install still allows an owner to reduce already enabled edits",()=>{
  render(permissions({...store,edit_inventory:true},false));fireEvent.click(screen.getByText("Connection permissions"));expect((screen.getByLabelText("Allow stock adjustments") as HTMLInputElement).disabled).toBe(false);expect((screen.getByLabelText("Allow product detail edits") as HTMLInputElement).disabled).toBe(true);
});
test("only granted edit capabilities expose edit actions",()=>{
  render(controls({...store,can_edit_inventory:false,can_edit_products:false}));expect(screen.queryByRole("button",{name:"Edit product details"})).toBeNull();expect(screen.queryByRole("button",{name:"Adjust Shopify stock"})).toBeNull();
});
test("stock review uses a signed delta and never writes before confirmation",async()=>{
  render(controls());await reviewStock();expect(prepareShopifyEdit).toHaveBeenCalledWith("team","store","token",{kind:"inventory",variant_gid:variant.variant_gid,location_gid:"gid://shopify/Location/1",delta:2});expect(executeShopifyEdit).not.toHaveBeenCalled();expect(screen.getByText(/8 available at review/)).toBeTruthy();fireEvent.click(screen.getByRole("button",{name:"Apply in Shopify"}));await screen.findByText("Shopify confirmed the change. Catalog sync is queued.");expect(executeShopifyEdit).toHaveBeenCalledWith("team","store","token","op");
});
test("cancelled live write does not call Shopify execute",async()=>{
  approve.mockResolvedValue(false);render(controls());await reviewStock();fireEvent.click(screen.getByRole("button",{name:"Apply in Shopify"}));await waitFor(()=>expect(approve).toHaveBeenCalled());expect(executeShopifyEdit).not.toHaveBeenCalled();
});
test("unknown outcome is explicit and cannot be automatically resent",async()=>{
  jest.mocked(executeShopifyEdit).mockResolvedValue({...operation,state:"unknown"});render(controls());await reviewStock();fireEvent.click(screen.getByRole("button",{name:"Apply in Shopify"}));await screen.findByText(/The outcome is not confirmed/);expect(screen.queryByRole("button",{name:"Apply in Shopify"})).toBeNull();expect(changed).not.toHaveBeenCalled();expect(executeShopifyEdit).toHaveBeenCalledTimes(1);
});
test("failed network result preserves the operation for checking",async()=>{
  jest.mocked(executeShopifyEdit).mockRejectedValue(new Error("Offline"));render(controls());await reviewStock();fireEvent.click(screen.getByRole("button",{name:"Apply in Shopify"}));await screen.findByRole("alert");fireEvent.click(screen.getByRole("button",{name:"Check recorded result"}));await screen.findByText(/The outcome is not confirmed/);expect(getShopifyEdit).toHaveBeenCalledWith("team","store","token","op");
});
test("invalid stock adjustment does not prepare an action",async()=>{
  render(controls());fireEvent.click(screen.getByRole("button",{name:"Adjust Shopify stock"}));fireEvent.change(screen.getByLabelText("Adjustment"),{target:{value:"1.5"}});fireEvent.click(screen.getByRole("button",{name:"Review change"}));await screen.findByRole("alert");expect(prepareShopifyEdit).not.toHaveBeenCalled();
});
test("product details review explicitly names product-wide impact",async()=>{
  const product:ShopifyEdit={...operation,kind:"product",intent:{changes:{title:"New Hoodie"}},snapshot:{title:"Hoodie",checked_at:operation.snapshot.checked_at,variant_title:"Black M"}};
  jest.mocked(prepareShopifyEdit).mockResolvedValue(product);render(controls());fireEvent.click(screen.getByRole("button",{name:"Edit product details"}));expect(screen.getByText(/all its variants/)).toBeTruthy();fireEvent.change(screen.getByLabelText("Title"),{target:{value:"New Hoodie"}});fireEvent.click(screen.getByRole("button",{name:"Review change"}));await screen.findByRole("button",{name:"Apply in Shopify"});expect(prepareShopifyEdit).toHaveBeenCalledWith("team","store","token",{kind:"product",variant_gid:variant.variant_gid,changes:{title:"New Hoodie"}});expect(executeShopifyEdit).not.toHaveBeenCalled();
});
test("late review response is discarded after account or permission scope changes",async()=>{
  let resolve!:(value:ShopifyEdit)=>void;jest.mocked(prepareShopifyEdit).mockReturnValue(new Promise(done=>{resolve=done;}));const view=render(controls());fireEvent.click(screen.getByRole("button",{name:"Adjust Shopify stock"}));fireEvent.change(screen.getByLabelText("Shopify location"),{target:{value:"gid://shopify/Location/1"}});fireEvent.change(screen.getByLabelText("Adjustment"),{target:{value:"2"}});fireEvent.click(screen.getByRole("button",{name:"Review change"}));view.rerender(controls({...store,can_edit_inventory:false,can_edit_products:false},"new-scope"));await act(async()=>resolve(operation));expect(screen.queryByRole("button",{name:"Apply in Shopify"})).toBeNull();
});
test("owner acknowledges actual check without claiming unknown write succeeded",async()=>{
  jest.mocked(getShopifyEdits).mockResolvedValueOnce({operations:[{...operation,state:"unknown"}]}).mockResolvedValue({operations:[{...operation,state:"unknown",reviewed_at:"2026-10-13T11:00:00Z"}]});jest.mocked(reviewUnknownShopifyEdit).mockResolvedValue({reviewed:true,state:"unknown"});render(<ShopifyEditHistory teamId="team" token="token" store={store}/>);fireEvent.click(screen.getByText("Recent Shopify edits"));fireEvent.click(screen.getByRole("button",{name:"Check edit history"}));await screen.findByRole("button",{name:"Acknowledge Shopify check"});fireEvent.click(screen.getByRole("button",{name:"Acknowledge Shopify check"}));await screen.findByText(/still does not claim a verified outcome/);expect(reviewUnknownShopifyEdit).toHaveBeenCalledWith("team","store","token","op");
});

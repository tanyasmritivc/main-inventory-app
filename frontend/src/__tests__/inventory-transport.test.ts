/** @jest-environment jsdom */
import { apiRequest } from "@/lib/api";
import { accountRequest } from "@/lib/account-request";
import { getAccessToken, getAccessSession } from "@/lib/session";
import { activeInventory, canDeleteSpace, permissionFingerprint, inventoryApiPath, inventoryHref, requireInventoryContext, selectInventory, type InventorySelection } from "@/lib/inventory-selection";
import { documentOwner } from "@/lib/documents";
import { adoptRestockEntries, changeRestock, restockKey } from "@/lib/restock-plan";

const getSession=jest.fn();
jest.mock("@/lib/session",()=>({getAccessToken:jest.fn(),getAccessSession:jest.fn()}));
jest.mock("@/lib/supabase/browser",()=>({createSupabaseBrowserClient:()=>({auth:{getSession}})}));
const fetchMock=jest.fn();
const a:InventorySelection={inventory_id:"a",name:"Workshop",owner_user_id:"owner",team_id:null,is_default:true,accountId:"actor",workspace:{workspace_id:"personal",name:"Personal",kind:"personal",team_id:null,role:"owner"},can_edit:true};
const b:InventorySelection={...a,inventory_id:"b",name:"Home"};
const response=(body:unknown)=>({ok:true,status:200,text:async()=>JSON.stringify(body)}) as Response;
beforeEach(()=>{
  jest.clearAllMocks(); selectInventory(null);requireInventoryContext(false);localStorage.clear();
  global.fetch=fetchMock;
  jest.mocked(getAccessToken).mockResolvedValue("current-token");
  jest.mocked(getAccessSession).mockResolvedValue({accountId:"actor",token:"current-token"});
  getSession.mockResolvedValue({data:{session:{user:{id:"actor"},access_token:"current-token"}}});
});
afterEach(()=>{ selectInventory(null);requireInventoryContext(false); });

test("navigation preserves inventory, filters and anchors while account/public links remain global",()=>{
  selectInventory(a);
  expect(inventoryHref("/inventory?location=Drawer#item")).toBe("/inventory?location=Drawer&inventory=a#item");
  for(const path of ["/home","/scan","/assist","/spaces","/documents","/review","/activity","/restock","/checkout","/project-kits","/collections","/labels"])
    expect(inventoryHref(path)).toBe(`${path}?inventory=a`);
  for(const path of ["/settings","/workspaces","/teams?team=x","/sharing/shared-id","https://example.test","//example.test"])
    expect(inventoryHref(path)).toBe(path);
  requireInventoryContext(true);selectInventory(null);
  expect(()=>inventoryApiPath("/search_items")).toThrow("Choose an inventory");
});

test("all inventory traffic uses its explicit server boundary and the current account",async()=>{
  selectInventory(a);fetchMock.mockResolvedValue(response({items:[]}));
  await apiRequest("/search_items",{method:"POST",body:{query:"screw"}});
  expect(fetchMock.mock.calls[0][0]).toMatch(/\/inventories\/a\/search_items$/);
  expect(fetchMock.mock.calls[0][1].headers.Authorization).toBe("Bearer current-token");
  jest.mocked(getAccessSession).mockResolvedValue({accountId:"other",token:"other-token"});
  await expect(apiRequest("/spaces")).rejects.toMatchObject({status:401});
  expect(fetchMock).toHaveBeenCalledTimes(1);
});

test("a response from the previous inventory cannot populate the next one",async()=>{
  selectInventory(a);
  let resolve!:(value:Response)=>void;
  fetchMock.mockReturnValue(new Promise<Response>(done=>{resolve=done;}));
  const pending=apiRequest("/search_items",{method:"POST",body:{query:""}});
  await Promise.resolve(); await Promise.resolve(); await Promise.resolve();
  expect(fetchMock).toHaveBeenCalledTimes(1);
  selectInventory(b);resolve(response({items:[{name:"Private workshop item"}]}));
  await expect(pending).rejects.toThrow("inventory changed");
  expect(activeInventory()).toBe(b);
});

test("switching inventories while a write waits for its credential prevents the write",async()=>{
  selectInventory(a);
  let resolve!:(value:unknown)=>void;
  getSession.mockReturnValue(new Promise(done=>{resolve=done;}));
  const pending=accountRequest("actor","/add_item",{method:"POST",body:{name:"Old draft"}});
  selectInventory(b);resolve({data:{session:{user:{id:"actor"},access_token:"current-token"}}});
  await expect(pending).rejects.toThrow("inventory changed");
  expect(fetchMock).not.toHaveBeenCalled();
});

test("authorized Team document metadata permits its real owner without accepting another inventory's metadata",()=>{
  selectInventory(a);
  const doc={filename:"manual.txt",storage_path:"owner/docs/manual.txt",user_id:"owner",inventory_id:"a"};
  expect(documentOwner(doc,"actor")).toBe("owner");
  expect(documentOwner({...doc,inventory_id:"b"},"actor")).toBe("actor");
  expect(documentOwner(doc,"other")).toBe("other");
});

test("legacy purchase plans are adopted only for verified inventory item IDs and removed entries stay removed",()=>{
  localStorage.setItem("findez-restock-v1:actor",JSON.stringify({partA:{minimum:2},partB:{buy_quantity:3}}));
  selectInventory(a);adoptRestockEntries(localStorage,"actor",["partA"]);
  expect(JSON.parse(localStorage.getItem(restockKey("actor"))!)).toEqual({partA:{minimum:2}});
  changeRestock(localStorage,"actor","partA",()=>({}));
  adoptRestockEntries(localStorage,"actor",["partA"]);
  expect(JSON.parse(localStorage.getItem(restockKey("actor"))!)).toEqual({});
  selectInventory(b);adoptRestockEntries(localStorage,"actor",["partB"]);
  expect(JSON.parse(localStorage.getItem(restockKey("actor"))!)).toEqual({partB:{buy_quantity:3}});
  expect(JSON.parse(localStorage.getItem("findez-restock-v1:actor")!)).toHaveProperty("partA");
});

test.each(["owner","admin","editor","viewer"] as const)("%s Space deletion uses effective inventory content role",async(role)=>{
  const selected={...a,role,can_edit:role!=="viewer"}; selectInventory(selected);
  fetchMock.mockResolvedValue(response({deleted:true}));
  expect(canDeleteSpace()).toBe(["owner","admin"].includes(role));
  if(["owner","admin"].includes(role)) await apiRequest("/spaces/space",{method:"DELETE"});
  else { await expect(apiRequest("/spaces/space",{method:"DELETE"})).rejects.toMatchObject({status:403}); expect(fetchMock).not.toHaveBeenCalled(); }
});
test("a role-only change retires existing inventory requests without switching inventories",async()=>{
  const original={...a,role:"editor" as const}; selectInventory(original);
  let finish!:(r:Response)=>void;
  fetchMock.mockReturnValue(new Promise<Response>(resolve=>{finish=resolve;}));
  const pending=apiRequest("/search_items",{method:"POST",body:{query:""}});
  await Promise.resolve(); await Promise.resolve(); await Promise.resolve();
  const changed={...original,role:"viewer" as const,can_edit:false};
  expect(permissionFingerprint(changed)).not.toBe(permissionFingerprint(original));
  selectInventory(changed);finish(response({items:[{name:"Retired result"}]}));
  await expect(pending).rejects.toThrow("inventory changed");
});

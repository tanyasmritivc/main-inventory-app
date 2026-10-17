/** @jest-environment jsdom */
import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { WorkspaceDirectory } from "@/components/site/workspace-directory";
import { InventoryBoundary } from "@/components/site/inventory-boundary";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { activeInventory, requireInventoryContext, selectInventory } from "@/lib/inventory-selection";

const router={push:jest.fn(),replace:jest.fn()};
let pathname="/home", query="inventory=a";
jest.mock("next/navigation",()=>({useRouter:()=>router,usePathname:()=>pathname,useSearchParams:()=>new URLSearchParams(query)}));
jest.mock("@/lib/account-request",()=>({accountRequest:jest.fn()}));
jest.mock("@/lib/use-api-session",()=>({useApiSession:jest.fn()}));
jest.mock("@/components/site/use-app-theme",()=>({AppThemeProvider:({children}:{children:React.ReactNode})=><>{children}</>}));
jest.mock("@/components/site/app-shell",()=>({AppShell:({children}:{children:React.ReactNode})=><main>{children}</main>}));
const personal={workspace_id:"personal",name:"Personal",kind:"personal",team_id:null,role:"owner"};
const inventory={inventory_id:"a",name:"Workshop parts",owner_user_id:"actor",team_id:null,is_default:true,item_count:1105};
beforeEach(()=>{
  jest.clearAllMocks();selectInventory(null);requireInventoryContext(false);pathname="/home";query="inventory=a";
  jest.mocked(useApiSession).mockReturnValue({accountId:"actor",loading:false,error:null} as ReturnType<typeof useApiSession>);
  jest.mocked(accountRequest).mockImplementation(async(_account,path,options)=>{
    if(path==="/inventory-workspaces") return {workspaces:[personal,{...personal,workspace_id:"team",name:"Shared workshop",kind:"team",team_id:"team"}]} as never;
    if(path==="/sharing/joined") return [] as never;
    if(path.startsWith("/inventory-workspaces/personal/inventories") && options?.method==="POST") return {inventory:{...inventory,inventory_id:"created"}} as never;
    if(path.endsWith("/audit")) return {activity:[]} as never;
    if(path.endsWith("/overview")) return {workspace:personal,members:[],candidates:[],locations:[]} as never;
    if(path.startsWith("/inventory-workspaces/")) return {workspace:personal,inventories:[inventory],total:1,next_offset:null} as never;
    if(path==="/inventories/a") return {inventory:{...inventory,workspace:personal,can_edit:true}} as never;
    throw new Error(`Unexpected fixture request ${path}`);
  });
});
afterEach(()=>{selectInventory(null);requireInventoryContext(false);});

test("the first screen chooses a workspace and the second opens an explicit inventory",async()=>{
  const {unmount}=render(<WorkspaceDirectory/>);
  const first=await screen.findByRole("link",{name:/Shared workshop/});
  expect(first.getAttribute("href")).toBe("/workspaces/team");
  expect(screen.getByRole("link",{name:/Personal Private/}).getAttribute("href")).toBe("/workspaces/personal");
  expect(router.push).not.toHaveBeenCalled();
  unmount();render(<WorkspaceDirectory workspaceId="personal"/>);
  const selected=await screen.findByRole("link",{name:/Workshop parts 1,105 items/});
  expect(selected.getAttribute("href")).toBe("/home?inventory=a");
  expect(activeInventory()).toBeNull();
  expect(screen.getAllByRole("heading",{name:"Inventories"})).toHaveLength(1);
});

test("creating an inventory opens its dashboard only after a saved server response",async()=>{
  render(<WorkspaceDirectory workspaceId="personal"/>);
  await screen.findByRole("link",{name:/Workshop parts/});
  await userEvent.click(screen.getByRole("button",{name:"New inventory"}));
  await userEvent.type(screen.getByRole("textbox",{name:"Name"}),"Repair project");
  await userEvent.click(screen.getByRole("button",{name:"Create"}));
  await waitFor(()=>expect(router.push).toHaveBeenCalledWith("/home?inventory=created"));
  expect(accountRequest).toHaveBeenCalledWith("actor","/inventory-workspaces/personal/inventories",{method:"POST",body:{name:"Repair project"}});
});

test("viewer workspaces can be opened without showing inventory creation or renaming",async()=>{
  jest.mocked(accountRequest).mockResolvedValue({workspace:{...personal,workspace_id:"team",kind:"team",team_id:"team",role:"viewer"},activity:[],members:[],locations:[],candidates:[],inventories:[inventory],total:1,next_offset:null});
  render(<WorkspaceDirectory workspaceId="team"/>);
  await screen.findByRole("link",{name:/Workshop parts/});
  expect(screen.queryByRole("button",{name:"New inventory"})).toBeNull();
  expect(screen.queryByRole("button",{name:/Rename Workshop/})).toBeNull();
});

test("missing context returns to the chooser before an inventory page can load",async()=>{
  query="";render(<InventoryBoundary><p>Private page</p></InventoryBoundary>);
  await waitFor(()=>expect(router.replace).toHaveBeenCalledWith("/organizations"));
  expect(screen.queryByText("Private page")).toBeNull();
  expect(accountRequest).not.toHaveBeenCalled();
});

test("switching inventories removes the old page until the next inventory is authorized",async()=>{
  const {rerender}=render(<InventoryBoundary><p>Inventory content</p></InventoryBoundary>);
  await screen.findByText("Inventory content");
  expect(activeInventory()?.inventory_id).toBe("a");
  let finish!:(value:unknown)=>void;
  jest.mocked(accountRequest).mockReturnValue(new Promise(resolve=>{finish=resolve;}));
  query="inventory=b";rerender(<InventoryBoundary><p>Inventory content</p></InventoryBoundary>);
  await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith("actor","/inventories/b"));
  expect(screen.queryByText("Inventory content")).toBeNull();
  expect(activeInventory()).toBeNull();
  await act(async()=>finish({inventory:{...inventory,inventory_id:"b",workspace:personal,can_edit:true}}));
  await screen.findByText("Inventory content");
  expect(activeInventory()?.inventory_id).toBe("b");
});

test("changing accounts clears private workspace names while the next directory is loading",async()=>{
  const {rerender}=render(<WorkspaceDirectory workspaceId="personal"/>);
  await screen.findByRole("link",{name:/Workshop parts/});
  jest.mocked(accountRequest).mockReturnValue(new Promise(()=>{}));
  jest.mocked(useApiSession).mockReturnValue({accountId:"other",loading:false,error:null} as ReturnType<typeof useApiSession>);
  rerender(<WorkspaceDirectory workspaceId="personal"/>);
  expect(screen.queryByRole("link",{name:/Workshop parts/})).toBeNull();
});

test("choosing an inventory does not mix in people, locations or audit administration",async()=>{
 render(<WorkspaceDirectory workspaceId="team"/>);
 await screen.findByRole("link",{name:/Workshop parts/});
 expect(jest.mocked(accountRequest).mock.calls.some((call)=>/\/(?:overview|audit)$/.test(call[1]))).toBe(false);
 expect(screen.queryByRole("combobox",{name:"Member"})).toBeNull();
 expect(screen.queryByRole("button",{name:"Add location"})).toBeNull();
});

test("workspace owner can rename from the selected workspace and Personal has no rename",async()=>{
 let name="Workshop";
 jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options)=>{
  if(options?.method==="PATCH") {name="Robotics";return {workspace:{name}} as never;}
  return {workspace:{...personal,workspace_id:"team",kind:"team",team_id:"team",owner_user_id:"actor",name},inventories:[],total:0,next_offset:null} as never;
 });
 const view=render(<WorkspaceDirectory workspaceId="team"/>);
 await userEvent.click(await screen.findByRole("button",{name:"Rename workspace"}));
 await userEvent.clear(screen.getByRole("textbox",{name:"Name"}));await userEvent.type(screen.getByRole("textbox",{name:"Name"}),"Robotics");
 await userEvent.click(screen.getByRole("button",{name:"Save"}));
 await waitFor(()=>expect(screen.queryByRole("dialog")).toBeNull());
 expect(accountRequest).toHaveBeenCalledWith("actor","/inventory-workspaces/team",{method:"PATCH",body:{name:"Robotics"}});
 view.unmount();jest.mocked(accountRequest).mockResolvedValue({workspace:personal,inventories:[],total:0,next_offset:null} as never);
 render(<WorkspaceDirectory workspaceId="personal"/>);
 await screen.findByText("No inventories yet.");expect(screen.queryByRole("button",{name:"Rename workspace"})).toBeNull();
});
test("inventory creator gets Rename without workspace administration",async()=>{
 let name="Workshop parts";
 jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options)=>{
  if(options?.method==="PATCH") {name="Fasteners";return {inventory:{...inventory,name}} as never;}
  return {workspace:{...personal,workspace_id:"team",kind:"team",team_id:"team",role:"member"},inventories:[{...inventory,name,can_rename:true}],total:1,next_offset:null} as never;
 });
 render(<WorkspaceDirectory workspaceId="team"/>);
 await userEvent.click(await screen.findByRole("button",{name:"Rename Workshop parts"}));
 expect(screen.queryByRole("button",{name:"New inventory"})).toBeNull();
 await userEvent.clear(screen.getByRole("textbox",{name:"Name"}));await userEvent.type(screen.getByRole("textbox",{name:"Name"}),"Fasteners");
 await userEvent.click(screen.getByRole("button",{name:"Save"}));
 expect(await screen.findByRole("link",{name:/Fasteners/})).toBeTruthy();
 expect(accountRequest).toHaveBeenCalledWith("actor","/inventories/a",{method:"PATCH",body:{name:"Fasteners"}});
});
test("account change discards a rename dialog and ignores its late saved name",async()=>{
 let finish!:(value:unknown)=>void;
 jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options)=>{
  if(options?.method==="PATCH") return new Promise(resolve=>{finish=resolve;}) as never;
  return {workspace:{...personal,workspace_id:"team",kind:"team",team_id:"team",name:"Private workspace",owner_user_id:"actor"},inventories:[],total:0,next_offset:null} as never;
 });
 const view=render(<WorkspaceDirectory workspaceId="team"/>);
 await userEvent.click(await screen.findByRole("button",{name:"Rename workspace"}));
 await userEvent.click(screen.getByRole("button",{name:"Save"}));
 jest.mocked(useApiSession).mockReturnValue({accountId:"other",loading:false,error:null} as ReturnType<typeof useApiSession>);
 jest.mocked(accountRequest).mockReturnValue(new Promise(()=>{}));
 view.rerender(<WorkspaceDirectory workspaceId="team"/>);
 await act(async()=>finish({workspace:{name:"Private renamed"}}));
 expect(screen.queryByRole("dialog")).toBeNull();expect(screen.queryByText("Private renamed")).toBeNull();
});

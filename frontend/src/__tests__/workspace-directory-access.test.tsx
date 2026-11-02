/** @jest-environment jsdom */
import {render,screen,waitFor,fireEvent} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {WorkspaceDirectory} from "@/components/site/workspace-directory";
import {InventoryAccessRequest} from "@/components/site/inventory-access-request";
import {InventoryDirectorySettings} from "@/components/site/inventory-directory-settings";
import {AccessRequests,WorkspaceOverview} from "@/components/site/workspace-overview";
import {accountRequest} from "@/lib/account-request";
import {useApiSession} from "@/lib/use-api-session";
const router={push:jest.fn()};
jest.mock("next/navigation",()=>({useRouter:()=>router}));
jest.mock("@/components/site/app-shell",()=>({AppShell:({children}:{children:React.ReactNode})=><main>{children}</main>}));
jest.mock("@/lib/account-request",()=>({accountRequest:jest.fn()}));
jest.mock("@/lib/use-api-session",()=>({useApiSession:jest.fn()}));
jest.mock("@/components/site/use-app-theme",()=>({AppThemeProvider:({children}:{children:React.ReactNode})=><>{children}</>}));
const workspace={workspace_id:"ftc",name:"Robotics",kind:"team" as const,team_id:"ftc",role:"member" as const};
const restricted={inventory_id:"electrical",workspace_id:"ftc",name:"Electrical",description:"Approved summary",can_open:false,can_manage:false,can_rename:false};
const pending={request_id:"request",status:"pending"};
beforeEach(()=>{jest.clearAllMocks();jest.mocked(useApiSession).mockReturnValue({accountId:"student",loading:false,error:null} as ReturnType<typeof useApiSession>);});
test("visible restricted inventories lead to access review and disclose no item counts or rename controls",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({workspace,inventories:[restricted,{...restricted,inventory_id:"tools",name:"Tools",can_open:true,item_count:12}],total:2,next_offset:null});
 render(<WorkspaceDirectory workspaceId="ftc"/>);
 expect((await screen.findByRole("link",{name:/Electrical/})).getAttribute("href")).toBe("/inventory-access-request/electrical");
 expect(screen.getByRole("link",{name:/Tools/}).getAttribute("href")).toBe("/home?inventory=tools");
 expect(screen.getAllByText("Approved summary",{selector:"span"})).toHaveLength(2);
 expect(screen.queryByRole("button",{name:/Rename Electrical/})).toBeNull();
 expect(jest.mocked(accountRequest).mock.calls.every(c=>c[1].includes("/directory?"))).toBe(true);
});
test("request is an explicit pending action and approval is refreshed without fetching inventory content",async()=>{
 let approved=false;
 jest.mocked(accountRequest).mockImplementation(async(_a,_p,options)=>(options?.method?{request:pending}:{inventory:{...restricted,can_open:approved},workspace,request:approved?null:pending}) as never);
 render(<InventoryAccessRequest inventoryId="electrical"/>);
 await screen.findByText("Your request for viewer access is pending.");
 expect(screen.queryByRole("link",{name:"Open inventory"})).toBeNull();
 expect(jest.mocked(accountRequest).mock.calls.some(c=>c[2]?.method)).toBe(false);
 approved=true;await userEvent.click(screen.getByRole("button",{name:"Check access"}));
 expect((await screen.findByRole("link",{name:"Open inventory"})).getAttribute("href")).toBe("/home?inventory=electrical");
 expect(jest.mocked(accountRequest).mock.calls.every(c=>c[1]==="/inventory-directory/electrical")).toBe(true);
});
test("request failures remain actionable and successful requests grant no immediate entry",async()=>{
 let fail=true;
 jest.mocked(accountRequest).mockImplementation(async(_a,_p,options)=>{if(options?.method){if(fail)throw new Error("Request failed.");return {request:pending} as never;}return {inventory:restricted,workspace,request:null} as never;});
 render(<InventoryAccessRequest inventoryId="electrical"/>);
 await userEvent.click(await screen.findByRole("button",{name:"Request viewer access"}));
 await screen.findByRole("alert");fail=false;
 await userEvent.click(screen.getByRole("button",{name:"Request viewer access"}));
 await screen.findByText("Your request for viewer access is pending.");
 expect(screen.queryByRole("link",{name:"Open inventory"})).toBeNull();
 expect(accountRequest).toHaveBeenCalledWith("student","/inventory-directory/electrical/request",{method:"POST"});
});
test("revoked directory access removes previously rendered metadata on focus",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({inventory:restricted,workspace,request:pending});
 render(<InventoryAccessRequest inventoryId="electrical"/>);await screen.findByText("Electrical");
 jest.mocked(accountRequest).mockRejectedValue(new Error("Unavailable"));fireEvent(window,new Event("focus"));
 await screen.findByRole("alert");expect(screen.queryByText("Electrical")).toBeNull();
 expect(screen.queryByRole("button",{name:"Cancel request"})).toBeNull();
});
test("changing account discards prior directory metadata and pending state",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({inventory:restricted,workspace,request:pending});
 const view=render(<InventoryAccessRequest inventoryId="electrical"/>);await screen.findByText("Electrical");
 jest.mocked(useApiSession).mockReturnValue({accountId:"other",loading:false,error:null} as ReturnType<typeof useApiSession>);
 jest.mocked(accountRequest).mockImplementation(()=>new Promise(()=>{}));view.rerender(<InventoryAccessRequest inventoryId="electrical"/>);
 expect(screen.queryByText("Electrical")).toBeNull();expect(screen.queryByText(/request for viewer access is pending/)).toBeNull();
});
test("administrators approve viewer access explicitly and failed decisions retain the request",async()=>{
 jest.mocked(accountRequest).mockImplementation(async(_a,_p,options)=>{if(options?.method)throw new Error("Permission changed.");return {requests:[{request_id:"request",inventory_name:"Electrical",requester_name:"Alex"}]} as never;});
 render(<AccessRequests workspaceId="ftc"/>);await screen.findByText("Alex");
 expect(jest.mocked(accountRequest).mock.calls.some(c=>c[2]?.method)).toBe(false);
 await userEvent.click(screen.getByRole("button",{name:"Approve viewer access"}));
 await screen.findByRole("alert");expect(screen.getByText("Alex")).toBeTruthy();
 expect(accountRequest).toHaveBeenCalledWith("student","/inventory-access-requests/request/decision",{method:"POST",body:{action:"approve"}});
});
test("visibility changes require an explicit save and preserve draft on failure",async()=>{
 jest.mocked(accountRequest).mockImplementation(async(_a,_p,options)=>{if(options?.method)throw new Error("Save failed.");return {inventory:{...restricted,can_manage:true,directory_visibility:"workspace"}} as never;});
 render(<InventoryDirectorySettings inventoryId="electrical"/>);
 await userEvent.selectOptions(await screen.findByRole("combobox",{name:"Directory visibility"}),"hidden");
 expect(jest.mocked(accountRequest).mock.calls.some(c=>c[2]?.method)).toBe(false);
 await userEvent.click(screen.getByRole("button",{name:"Save directory settings"}));await screen.findByRole("alert");
 expect((screen.getByRole("combobox") as HTMLSelectElement).value).toBe("hidden");
 expect(screen.queryByText("Directory settings saved.")).toBeNull();
 expect(accountRequest).toHaveBeenCalledWith("student","/inventory-directory/electrical",{method:"PATCH",body:{directory_visibility:"hidden",description:"Approved summary"}});
});
test("workspace overview shows only the current member's unfinished tasks and safe directory summaries",async()=>{
 jest.mocked(accountRequest).mockImplementation(async(_a,path)=> (path.endsWith("/board")?{tasks:[{task_id:"mine",title:"Inspect motor",assigned_to:"student",status:"todo"},{task_id:"other",title:"Other task",assigned_to:"other",status:"todo"},{task_id:"done",title:"Finished",assigned_to:"student",status:"done"}]}:path.endsWith("/audit")?{activity:[]}:{requests:[]}) as never);
 render(<WorkspaceOverview workspace={workspace} inventories={[restricted]}/>);
 await screen.findByText("Inspect motor");expect(screen.queryByText("Other task")).toBeNull();expect(screen.queryByText("Finished")).toBeNull();
 expect(screen.getByRole("link",{name:/Electrical/}).getAttribute("href")).toBe("/inventory-access-request/electrical");
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith("student","/inventory-workspaces/ftc/audit"));
});

test("session errors offer sign-in without an endless directory loader", () => {
 jest.mocked(useApiSession).mockReturnValue({accountId:null,loading:false,error:"Your session has expired. Please sign in again."} as ReturnType<typeof useApiSession>);
 render(<WorkspaceDirectory workspaceId="personal"/>);
 expect(screen.getByRole("link",{name:"Sign in"}).getAttribute("href")).toBe("/signin?redirect=%2Fworkspaces%2Fpersonal");
 expect(screen.queryByRole("status")).toBeNull();
 expect(screen.queryByRole("button",{name:"Retry"})).toBeNull();
});
test("background permission refresh keeps the directory visible, but denial clears it", async () => {
 jest.mocked(accountRequest).mockResolvedValue({workspace,inventories:[{...restricted,can_open:true,name:"Visible inventory"}],total:1,next_offset:null});
 render(<WorkspaceDirectory workspaceId="ftc"/>);
 await screen.findByRole("link",{name:/Visible inventory/});
 let reject!: (reason: Error) => void;
 jest.mocked(accountRequest).mockImplementation(()=>new Promise((_resolve,r)=>{reject=r;}));
 fireEvent(window,new Event("focus"));
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledTimes(2));
 expect(screen.getByRole("link",{name:/Visible inventory/})).toBeTruthy();
 expect(screen.queryByRole("status")).toBeNull();
 reject(new Error("Access removed"));
 await screen.findByRole("alert");
 expect(screen.queryByRole("link",{name:/Visible inventory/})).toBeNull();
});

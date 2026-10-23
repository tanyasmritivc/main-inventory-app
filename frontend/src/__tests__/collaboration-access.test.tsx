/** @jest-environment jsdom */
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
mockBrowserTopLayer();
import { CollaborationPanel, locationPath } from "@/components/site/collaboration-panel";
import { OrganizationDirectory } from "@/components/site/organization-directory";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
const router = {push:jest.fn()};
jest.mock("@/components/site/app-shell",()=>({AppShell:({children}:{children:React.ReactNode})=><main>{children}</main>}));
jest.mock("next/navigation",()=>({useRouter:()=>router}));
jest.mock("@/lib/account-request",()=>({accountRequest:jest.fn()}));
jest.mock("@/lib/use-api-session",()=>({useApiSession:jest.fn()}));
jest.mock("@/components/site/use-app-theme",()=>({AppThemeProvider:({children}:{children:React.ReactNode})=><>{children}</>}));
const member={user_id:"student-1",display_name:"Alex",role:"viewer",workspace_role:"member",source:"workspace"};
const data={inventory:{name:"Tools",team_id:"team",can_manage:true,access_mode:"workspace",default_role:"viewer"},members:[member],locations:[]};
beforeEach(()=>{
 jest.clearAllMocks();
 jest.mocked(useApiSession).mockReturnValue({accountId:"owner",loading:false,error:null} as ReturnType<typeof useApiSession>);
 jest.mocked(accountRequest).mockImplementation(async(_actor,path)=> (path.startsWith("/access-invitations?") ? {invitations:[]} : path.endsWith("/audit") ? {activity:[]} : data) as never);
});
test("inventory permissions are explicit saved actions with viewer defaults",async()=>{
 render(<CollaborationPanel inventoryId="tools"/>);
 await screen.findByRole("heading",{name:"Inventory access"});
 expect(screen.getByText("Viewer · inherited")).toBeTruthy();
 await userEvent.selectOptions(screen.getByRole("combobox",{name:"Access"}),"restricted");
 expect(jest.mocked(accountRequest).mock.calls.filter((c)=>c[2]?.method)).toHaveLength(0);
 await userEvent.click(screen.getByRole("button",{name:"Save access"}));
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith("owner","/inventories/tools/access",{method:"PATCH",body:{access_mode:"restricted",default_role:"viewer"}}));
 await userEvent.selectOptions(screen.getByRole("combobox",{name:"Member"}),"student-1");
 await userEvent.selectOptions(screen.getByRole("combobox",{name:"Role"}),"editor");
 await userEvent.click(screen.getByRole("button",{name:"Save role"}));
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith("owner","/inventories/tools/access/student-1",{method:"PUT",body:{role:"editor"}}));
});
test("a viewer sees permitted people and history but no policy or role writes",async()=>{
 jest.mocked(accountRequest).mockImplementation(async(_actor,path)=> (path.endsWith("/audit") ? {activity:[]} : {...data,inventory:{...data.inventory,can_manage:false}}) as never);
 render(<CollaborationPanel inventoryId="tools"/>);
 await screen.findByText("Alex",{selector:"span"});
 expect(screen.queryByRole("button",{name:"Save access"})).toBeNull();
 expect(screen.queryByRole("button",{name:"Save role"})).toBeNull();
 expect(screen.queryByRole("button",{name:"Add to inventory"})).toBeNull();
});
test("failed role changes retain the selected member and do not report success",async()=>{
 jest.mocked(accountRequest).mockImplementation(async(_actor,path,options)=>{
  if(path.startsWith("/access-invitations?")) return {invitations:[]} as never;
  if(options?.method) throw new Error("Permission changed. Refresh and try again.");
  return (path.endsWith("/audit")?{activity:[]}:data) as never;
 });
 render(<CollaborationPanel inventoryId="tools"/>);
 await screen.findByText("Alex",{selector:"span"});
 await userEvent.selectOptions(screen.getByRole("combobox",{name:"Member"}),"student-1");
 await userEvent.click(screen.getByRole("button",{name:"Save role"}));
 expect(await screen.findByRole("alert")).toBeTruthy();
 expect((screen.getByRole("combobox",{name:"Member"}) as HTMLSelectElement).value).toBe("student-1");
});
test("organization overview exposes only server-assigned workspaces and creates in its organization",async()=>{
 jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options)=> options?.method ? {workspace:{team_id:"created"}} as never : {organization:{organization_id:"acme",name:"Acme Company",role:"owner"},workspaces:[{team_id:"october",name:"2026 OCTOBER CLIENT"}],members:[]} as never);
 render(<OrganizationDirectory organizationId="acme"/>);
 expect((await screen.findByRole("link",{name:/2026 OCTOBER CLIENT/})).getAttribute("href")).toBe("/workspaces/october");
 await userEvent.click(screen.getByRole("button",{name:"New workspace"}));
 await userEvent.type(screen.getByRole("textbox",{name:"Workspace name"}),"November client");
 await userEvent.click(screen.getByRole("button",{name:"Create workspace"}));
 await waitFor(()=>expect(router.push).toHaveBeenCalledWith("/workspaces/created"));
 expect(accountRequest).toHaveBeenCalledWith("owner","/organizations/acme/workspaces",{method:"POST",body:{name:"November client"}});
});
test("nested physical paths retain one stable identity",()=>{
 const locations=[{location_id:"workshop",name:"FTC workshop",parent_id:null},{location_id:"cabinet",name:"Cabinet",parent_id:"workshop"},{location_id:"drawer",name:"Drawer 3",parent_id:"cabinet"}];
 expect(locationPath(locations[2],locations)).toBe("FTC workshop / Cabinet / Drawer 3");
});

test("organization selection and workspace selection do not expose management forms",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({organizations:[{organization_id:"acme",name:"Acme Company",role:"owner"}]} as never);
 const view=render(<OrganizationDirectory/>);
 await screen.findByRole("link",{name:/Acme Company/});
 expect(screen.queryByRole("textbox",{name:"Organization name"})).toBeNull();
 await userEvent.type(screen.getByRole("searchbox"),"missing");
 expect(screen.queryByRole("link",{name:/Acme Company/})).toBeNull();
 view.unmount();
 jest.mocked(accountRequest).mockResolvedValue({organization:{organization_id:"acme",name:"Acme Company",role:"owner"},workspaces:[{team_id:"october",name:"Client October"}],members:[member]});
 render(<OrganizationDirectory organizationId="acme"/>);
 await screen.findByRole("link",{name:/Client October/});
 expect(screen.queryByRole("textbox",{name:"Workspace name"})).toBeNull();
 expect(screen.queryByText("Alex")).toBeNull();
});
test("organization people have a dedicated destination with no inventory or workspace creation controls",async()=>{
 jest.mocked(accountRequest).mockImplementation(async(_actor,path)=> path.startsWith("/access-invitations?") ? {invitations:[]} as never : {organization:{organization_id:"acme",name:"Acme Company",role:"owner"},workspaces:[{team_id:"october",name:"Client October"}],members:[member]} as never);
 render(<OrganizationDirectory organizationId="acme" view="people"/>);
 await screen.findByText("Alex");
 expect(screen.queryByRole("link",{name:/Client October/})).toBeNull();
 expect(screen.queryByRole("button",{name:"New workspace"})).toBeNull();
 expect(screen.queryByRole("textbox",{name:"Account email"})).toBeNull();
 await userEvent.click(screen.getByRole("button",{name:"Invite member"}));
 expect(screen.getByRole("dialog",{name:"Invite organization member"})).toBeTruthy();
});
test("individual workspace sections avoid loading unrelated history",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({workspace:{name:"Robotics",role:"owner",organization_id:"org"},members:[member],candidates:[member],locations:[]});
 render(<CollaborationPanel workspaceId="robotics" section="people"/>);
 await screen.findByText("Alex",{selector:"span"});
 expect(screen.queryByRole("heading",{name:"Physical locations"})).toBeNull();
 expect(screen.queryByRole("heading",{name:"History"})).toBeNull();
 expect(jest.mocked(accountRequest).mock.calls.some((call)=>call[1].endsWith("/audit"))).toBe(false);
});

test("personal inventory access stays private without workspace administration instructions",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({inventory:{name:"Personal",team_id:null,can_manage:true,access_mode:"legacy"},members:[{user_id:"owner",display_name:"You",role:"owner"}],locations:[]});
 const view=render(<CollaborationPanel inventoryId="personal" section="policy"/>);
 await screen.findByText("This inventory is private to you.");
 expect(screen.queryByRole("button",{name:"Save access"})).toBeNull();
 view.rerender(<CollaborationPanel inventoryId="personal" section="locations"/>);
 await screen.findByText("Manage the locations in this inventory in Spaces.");
 expect(screen.queryByText(/Workspace owners/)).toBeNull();
});

test("organization owners rename from cards and failed saves retain the draft",async()=>{
 let name="Acme";
 jest.mocked(accountRequest).mockImplementation(async(_actor,path,options)=>{
  if(options?.method==="PATCH") {
   if(name==="Acme") {name="retry";throw new Error("Try again.");}
   name="Acme Company";return {organization:{name}} as never;
  }
  return {organizations:[{organization_id:"acme",name:name==="retry"?"Acme":name,role:"owner",owner_user_id:"owner"}]} as never;
 });
 render(<OrganizationDirectory/>);
 const orgTrigger=await screen.findByRole("button",{name:"Organization actions for Acme"});
 await userEvent.click(orgTrigger);
 await userEvent.click(await screen.findByRole("menuitem",{name:"Rename"}));
 const input=screen.getByRole("textbox",{name:"Name"});
 expect((input as HTMLInputElement).value).toBe("Acme");
 await userEvent.clear(input);await userEvent.type(input,"Acme Company");
 await userEvent.click(screen.getByRole("button",{name:"Save"}));
 await screen.findByRole("alert");expect((input as HTMLInputElement).value).toBe("Acme Company");
 await userEvent.click(screen.getByRole("button",{name:"Save"}));
 await waitFor(()=>expect(screen.queryByRole("dialog")).toBeNull());
 expect(await screen.findByRole("link",{name:/Acme Company/})).toBeTruthy();
 expect(accountRequest).toHaveBeenCalledWith("owner","/organizations/acme",{method:"PATCH",body:{name:"Acme Company"}});
});
test("organization admins do not get owner rename controls",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({organization:{organization_id:"acme",name:"Acme",role:"admin",owner_user_id:"someone"},workspaces:[{team_id:"tools",name:"Tools",owner_user_id:"someone"}],members:[]} as never);
 render(<OrganizationDirectory organizationId="acme"/>);
 await screen.findByRole("link",{name:/Tools/});
 expect(screen.queryByRole("button",{name:/Rename/})).toBeNull();
});
test("workspace creator can rename an assigned workspace from its organization",async()=>{
 let name="October";
 jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options)=>{
  if(options?.method==="PATCH") {name="November";return {workspace:{name}} as never;}
  return {organization:{organization_id:"acme",name:"Acme",role:"member",owner_user_id:"other"},workspaces:[{team_id:"client",name,owner_user_id:"owner"}],members:[]} as never;
 });
 render(<OrganizationDirectory organizationId="acme"/>);
 await userEvent.click(await screen.findByRole("button",{name:"Manage workspace October"}));
 await userEvent.click(await screen.findByRole("menuitem",{name:"Rename workspace"}));
 await userEvent.clear(screen.getByRole("textbox",{name:"Name"}));await userEvent.type(screen.getByRole("textbox",{name:"Name"}),"November");
 await userEvent.click(screen.getByRole("button",{name:"Save"}));
 expect(await screen.findByRole("link",{name:/November/})).toBeTruthy();
 expect(accountRequest).toHaveBeenCalledWith("owner","/inventory-workspaces/client",{method:"PATCH",body:{name:"November"}});
});

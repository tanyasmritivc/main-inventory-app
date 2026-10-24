/** @jest-environment jsdom */
import { act, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AccessInvitationClient } from "@/components/site/access-invitation-client";
import { OrganizationDirectory } from "@/components/site/organization-directory";
import { PendingInvitations } from "@/components/site/access-invitation-tools";
import { ActivityFeedClient } from "@/components/site/activity-feed-client";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { ApiError } from "@/lib/api";
const router = {push:jest.fn()};
jest.mock("next/navigation",()=>({useRouter:()=>router}));
jest.mock("@/lib/account-request",()=>({accountRequest:jest.fn()}));
jest.mock("@/lib/use-api-session",()=>({useApiSession:jest.fn()}));
jest.mock("@/components/site/app-shell",()=>({AppShell:({children}:{children:React.ReactNode})=><main>{children}</main>}));
jest.mock("@/components/site/use-app-theme",()=>({AppThemeProvider:({children}:{children:React.ReactNode})=><>{children}</>}));
const invitation={invitation_id:"inv-1",scope:"organization" as const,resource_id:"org",name:"Acme Company",recipient_email:"alex@example.test",role:"member",status:"pending" as const,expires_at:"2099-01-01T00:00:00Z",created_at:"2026-10-15T00:00:00Z",destination:"/organizations/org"};
beforeEach(()=>{
 jest.clearAllMocks();
 jest.mocked(useApiSession).mockReturnValue({accountId:"recipient",loading:false,error:null} as never);
 jest.mocked(accountRequest).mockResolvedValue({invitation});
});
test("opening or previewing an invitation never accepts it; acceptance is an explicit captured-account request",async()=>{
 render(<AccessInvitationClient code="ABCDEF234567"/>);
 await screen.findByRole("heading",{name:"Acme Company"});
 expect(jest.mocked(accountRequest).mock.calls.map((c)=>c[1])).toEqual(["/access-invitations/preview"]);
 expect(screen.queryByRole("link",{name:"Open organization"})).toBeNull();
 jest.mocked(accountRequest).mockResolvedValue({invitation:{...invitation,status:"accepted"}});
 await userEvent.click(screen.getByRole("button",{name:"Accept invitation"}));
 await screen.findByText("Invitation accepted.");
 expect(accountRequest).toHaveBeenCalledWith("recipient","/access-invitations/inv-1/decision",{method:"POST",body:{action:"accept"}});
 expect(screen.getByRole("link",{name:"Open organization"}).getAttribute("href")).toBe("/organizations/org");
});
test("declining creates no access link and a failed decision keeps the invitation reviewable",async()=>{
 render(<AccessInvitationClient invitationId="inv-1"/>);
 await screen.findByRole("heading",{name:"Acme Company"});
 jest.mocked(accountRequest).mockRejectedValueOnce(new Error("Unavailable"));
 await userEvent.click(screen.getByRole("button",{name:"Accept invitation"}));
 await screen.findByRole("alert");
 expect(screen.getByRole("button",{name:"Decline"})).toBeTruthy();
 jest.mocked(accountRequest).mockResolvedValue({invitation:{...invitation,status:"declined"}});
 await userEvent.click(screen.getByRole("button",{name:"Decline"}));
 await screen.findByText("Invitation declined.");
 expect(screen.queryByRole("link",{name:"Open organization"})).toBeNull();
});
test("wrong recipients see no resource details or acceptance button",async()=>{
 jest.mocked(accountRequest).mockRejectedValue(new ApiError("Denied",403,null));
 render(<AccessInvitationClient code="ABCDEF234567"/>);
 await screen.findByText(/whose confirmed email received/);
 expect(screen.queryByText("Acme Company")).toBeNull();
 expect(screen.queryByRole("button",{name:"Accept invitation"})).toBeNull();
});
test("expiry and cancellation have no accept action",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({invitation:{...invitation,expires_at:"2020-01-01T00:00:00Z"}});
 const view=render(<AccessInvitationClient invitationId="inv-1"/>);
 await screen.findByText(/has expired/);
 expect(screen.queryByRole("button",{name:"Accept invitation"})).toBeNull();
 view.unmount();
 jest.mocked(accountRequest).mockResolvedValue({invitation:{...invitation,status:"cancelled"}});
 render(<AccessInvitationClient invitationId="inv-1"/>);
 await screen.findByText("Invitation cancelled.");
 expect(screen.queryByRole("button",{name:"Accept invitation"})).toBeNull();
});
test("signed-out code entry preserves the invitation through sign-in and never calls acceptance",async()=>{
 jest.mocked(useApiSession).mockReturnValue({accountId:null,loading:false,error:null} as never);
 render(<AccessInvitationClient/>);
 await userEvent.type(screen.getByRole("textbox",{name:"Invitation code"}),"abcdef234567");
 await userEvent.click(screen.getByRole("button",{name:"Review invitation"}));
 expect(router.push).toHaveBeenCalledWith("/signin?redirect=%2Fjoin%2Faccess%3Fcode%3DABCDEF234567");
 expect(accountRequest).not.toHaveBeenCalled();
});
test("account switch hides a prior preview and discards its delayed acceptance result",async()=>{
 let resolve!:(value:unknown)=>void;
 const view=render(<AccessInvitationClient code="ABCDEF234567"/>);
 await screen.findByRole("heading",{name:"Acme Company"});
 jest.mocked(accountRequest).mockImplementation(()=>new Promise((r)=>{resolve=r;}));
 await userEvent.click(screen.getByRole("button",{name:"Accept invitation"}));
 jest.mocked(useApiSession).mockReturnValue({accountId:"other",loading:false,error:null} as never);
 jest.mocked(accountRequest).mockImplementation(()=>new Promise(()=>{}));
 view.rerender(<AccessInvitationClient code="ABCDEF234567"/>);
 await act(async()=>resolve({invitation:{...invitation,status:"accepted"}}));
 expect(screen.queryByText("Acme Company")).toBeNull();
 expect(screen.queryByRole("link",{name:"Open organization"})).toBeNull();
});
test("organization invitation exposes a pending delivery and code without adding the person to accepted members",async()=>{
 const overview={organization:{organization_id:"org",name:"Acme Company",role:"owner"},workspaces:[],members:[]};
 let sent=false;
 jest.mocked(accountRequest).mockImplementation(async(_actor,path,options)=>{
  if(options?.method){sent=true;return {invitation,code:"ABCDEF234567",invite_url:"https://www.findez.ai/join/access?code=ABCDEF234567",email_sent:false} as never;}
  return (path.startsWith("/access-invitations?") ? {invitations:sent?[invitation]:[]} : overview) as never;
 });
 render(<OrganizationDirectory organizationId="org" view="people"/>);
 await userEvent.click(await screen.findByRole("button",{name:"Invite member"}));
 await userEvent.type(screen.getByRole("textbox",{name:"Email"}),"alex@example.test");
 await userEvent.click(screen.getByRole("button",{name:"Send invitation"}));
 const dialog=await screen.findByRole("dialog",{name:"Invitation ready"});
 expect(within(dialog).getByText(/email could not be sent/)).toBeTruthy();
 expect(within(dialog).getByText("ABCDEF234567")).toBeTruthy();
 await userEvent.click(within(dialog).getByRole("button",{name:"Done"}));
 await screen.findByRole("heading",{name:"Pending invitations"});
 expect(screen.queryByRole("button",{name:"Remove"})).toBeNull();
});
test("pending invitation cancellation is explicit and account-bound",async()=>{
 let cancelled=false;
 jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options)=>{if(options?.method){cancelled=true;return {invitation:{...invitation,status:"cancelled"}} as never;}return {invitations:cancelled?[]:[invitation]} as never;});
 render(<PendingInvitations scope="organization" resourceId="org"/>);
 await userEvent.click(await screen.findByRole("button",{name:"Cancel invitation for alex@example.test"}));
 await waitFor(()=>expect(screen.queryByText("alex@example.test")).toBeNull());
 expect(accountRequest).toHaveBeenCalledWith("recipient","/access-invitations/inv-1/decision",{method:"POST",body:{action:"cancel"}});
});
test("notification review is a link and marking read never accepts membership",async()=>{
 jest.mocked(accountRequest).mockResolvedValue({notifications:[{activity_id:"inv-1",summary:"Invitation to Acme Company",created_at:invitation.created_at,is_read:false,invitation}],unread_count:1});
 render(<ActivityFeedClient mode="notifications"/>);
 expect((await screen.findByRole("link",{name:"Review invitation"})).getAttribute("href")).toBe("/join/access?invitation=inv-1");
 expect(screen.queryByRole("button",{name:"Accept invitation"})).toBeNull();
});

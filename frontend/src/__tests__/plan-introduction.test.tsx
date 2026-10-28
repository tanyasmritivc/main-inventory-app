/** @jest-environment jsdom */
import { act, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
import { PlanIntroduction } from "@/components/site/plan-introduction";
import { persistPlanIntroduction, shouldIntroducePlans, locallyDismissed } from "@/lib/plan-introduction";
import { accountToken } from "@/lib/account-request";
mockBrowserTopLayer();
let actor="intro";
const auth={getUser:jest.fn()};
jest.mock("@/lib/supabase/browser",()=>({createSupabaseBrowserClient:()=>({auth})}));
jest.mock("@/lib/account-request",()=>({accountToken:jest.fn(async()=>"captured-token")}));
jest.mock("@/lib/pilot",()=>({isPilotPublic:()=>true}));
const user=()=>({id:actor,email_confirmed_at:"2026-10-26",user_metadata:{}});
beforeEach(()=>{
  actor+="x";jest.clearAllMocks();localStorage.clear();auth.getUser.mockImplementation(async()=>({data:{user:user()},error:null}));
  process.env.NEXT_PUBLIC_SUPABASE_URL="https://auth.example.test";process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY="public-key";
  global.fetch=jest.fn(async()=>({ok:true,json:async()=>({...user(),user_metadata:{findez_plan_intro_version:1}})}) as Response);
});
test("one-tap Free closes the chooser without buying or changing an entitlement and persists across remount", async()=>{
  const view=render(<PlanIntroduction accountId={actor}/>);await screen.findByRole("dialog");
  expect(screen.getByText(/No plan limits or automatic charges/)).toBeTruthy();
  await userEvent.click(screen.getByRole("button",{name:"Continue with Free"}));
  expect(screen.queryByRole("dialog")).toBeNull();expect(locallyDismissed(actor)).toBe(true);
  expect(fetch).toHaveBeenCalledWith("https://auth.example.test/auth/v1/user",expect.objectContaining({method:"PUT",headers:expect.objectContaining({Authorization:"Bearer captured-token"}),body:'{"data":{"findez_plan_intro_version":1}}'}));
  view.unmount();render(<PlanIntroduction accountId={actor}/>);await act(async()=>{});expect(screen.queryByRole("dialog")).toBeNull();
});
test.each(["Skip for now","Close"])("%s is a real dismissal", async(name)=>{
  render(<PlanIntroduction accountId={actor}/>);await screen.findByRole("dialog");await userEvent.click(screen.getByRole("button",{name}));expect(screen.queryByRole("dialog")).toBeNull();
});
test("server marker prevents a repeated introduction on another device",async()=>{
  auth.getUser.mockResolvedValue({data:{user:{...user(),user_metadata:{findez_plan_intro_version:1}}},error:null});
  expect(await shouldIntroducePlans(actor)).toBe(false);expect(fetch).not.toHaveBeenCalled();
});
test("network failure after dismissal never traps user or claims a saved plan",async()=>{
  jest.mocked(fetch).mockRejectedValue(new Error("Offline"));render(<PlanIntroduction accountId={actor}/>);await screen.findByRole("dialog");
  await userEvent.click(screen.getByRole("button",{name:"Skip for now"}));expect(screen.queryByRole("dialog")).toBeNull();expect(screen.queryByText(/plan saved/i)).toBeNull();
  expect(await shouldIntroducePlans(actor)).toBe(false);
});
test("unverified accounts defer to existing verification; foreign accounts never show",async()=>{
  auth.getUser.mockResolvedValueOnce({data:{user:{...user(),email_confirmed_at:null}}});expect(await shouldIntroducePlans(actor)).toBe(false);
  auth.getUser.mockResolvedValueOnce({data:{user:{...user(),id:"foreign"}}});expect(await shouldIntroducePlans(actor)).toBe(false);
});
test("late identity check cannot reopen after unmount",async()=>{
  let resolve!:(value:unknown)=>void;auth.getUser.mockImplementationOnce(()=>new Promise(r=>{resolve=r;}));const view=render(<PlanIntroduction accountId={actor}/>);view.unmount();
  await act(async()=>resolve({data:{user:user()}}));expect(screen.queryByRole("dialog")).toBeNull();
});
test("failed or foreign metadata receipts are not accepted; credentials bind to initiating account",async()=>{
  jest.mocked(fetch).mockResolvedValueOnce({ok:false} as Response);await expect(persistPlanIntroduction(actor)).rejects.toThrow();
  jest.mocked(fetch).mockResolvedValueOnce({ok:true,json:async()=>({id:"foreign",user_metadata:{findez_plan_intro_version:1}})} as Response);
  await expect(persistPlanIntroduction(actor)).rejects.toThrow();expect(accountToken).toHaveBeenCalledWith(actor);
});

test("direct prompt handoffs are not interrupted by the plan dialog",async()=>{
  history.replaceState(null,"","/?prompt=remember");
  try { render(<PlanIntroduction accountId={actor}/>);await act(async()=>{});expect(screen.queryByRole("dialog")).toBeNull();expect(auth.getUser).not.toHaveBeenCalled(); }
  finally { history.replaceState(null,"","/"); }
});
test("Escape dismisses the welcome without selecting a paid plan",async()=>{
  render(<PlanIntroduction accountId={actor}/>);await screen.findByRole("dialog");await userEvent.keyboard("{Escape}");expect(screen.queryByRole("dialog")).toBeNull();
});
